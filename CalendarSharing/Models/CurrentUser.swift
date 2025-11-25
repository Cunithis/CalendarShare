//
//  CurrentUser.swift
//  CalendarSharing
//
//  Created by Domantas Jocas on 17/11/2025.
//

import Foundation
import Combine
import FirebaseAuth

/// Singleton that represents the currently signed-in user and their
/// locally cached data (events, groups, group-specific caches).
///
/// All properties are persisted into UserDefaults so that the app can
/// restore state on launch without having to re-fetch everything from
/// Firestore. This helps reduce network traffic and speeds up cold starts.
class CurrentUser: ObservableObject {
    static let shared = CurrentUser()

    /// Basic profile information of the signed-in user.
    @Published var user: AppUser? {
        didSet { saveToUserDefaults() }
    }

    /// All personal calendar events for this user (from users/{uid}/calendar).
    @Published var events: [Event] = [] {
        didSet { saveToUserDefaults() }
    }

    /// All groups the user belongs to.
    @Published var groups: [UserGroup] = [] {
        didSet { saveToUserDefaults() }
    }

    /// Cached events per groupId (groups/{gid}/calendar).
    /// This is populated by listeners and used to render UI quickly.
    @Published var groupEventsCache: [String: [Event]] = [:] {
        didSet { saveToUserDefaults() }
    }

    /// Cached proposals per groupId (groups/{gid}/proposals).
    @Published var groupProposalsCache: [String: [GroupProposal]] = [:] {
        didSet { saveToUserDefaults() }
    }

    private let userDefaultsKey = "currentUser"

    /// Codable payload that we store in UserDefaults. This keeps the
    /// UserDefaults layer decoupled from the public API.
    private struct PersistedCurrentUser: Codable {
        let user: AppUser?
        let events: [Event]
        let groups: [UserGroup]
        let groupEventsCache: [String: [Event]]
        let groupProposalsCache: [String: [GroupProposal]]
    }

    private init() {
        loadFromUserDefaults()
    }

    /// Persist the current state to UserDefaults.
    /// This is intentionally lightweight: it bails out and clears storage
    /// if everything is empty, to avoid writing unnecessary data.
    private func saveToUserDefaults() {
        // If everything is empty, clear any previous persisted state.
        if user == nil,
           events.isEmpty,
           groups.isEmpty,
           groupEventsCache.isEmpty,
           groupProposalsCache.isEmpty {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return
        }

        let payload = PersistedCurrentUser(
            user: user,
            events: events,
            groups: groups,
            groupEventsCache: groupEventsCache,
            groupProposalsCache: groupProposalsCache
        )

        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Restore last known state from UserDefaults (if available).
    private func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        if let saved = try? JSONDecoder().decode(PersistedCurrentUser.self, from: data) {
            self.user = saved.user
            self.events = saved.events
            self.groups = saved.groups
            self.groupEventsCache = saved.groupEventsCache
            self.groupProposalsCache = saved.groupProposalsCache
        }
    }

    // MARK: - Update helpers

    /// Replace the current events array only if it actually changed.
    /// This avoids unnecessary didSet triggers and UserDefaults writes.
    func updateEvents(_ newEvents: [Event]) {
        guard newEvents != events else { return }
        self.events = newEvents
    }

    /// Replace the current groups array only if it actually changed.
    func updateGroups(_ newGroups: [UserGroup]) {
        guard newGroups != groups else { return }
        self.groups = newGroups
    }

    /// Update the cached events for a specific group.
    func updateGroupEventsCache(for groupId: String, events: [Event]) {
        guard groupEventsCache[groupId] != events else { return }
        groupEventsCache[groupId] = events
    }

    /// Update the cached proposals for a specific group.
    func updateGroupProposalsCache(for groupId: String, proposals: [GroupProposal]) {
        guard groupProposalsCache[groupId] != proposals else { return }
        groupProposalsCache[groupId] = proposals
    }

    /// Clear all in-memory and persisted data for the current user.
    func clear() {
        user = nil
        events = []
        groups = []
        groupEventsCache = [:]
        groupProposalsCache = [:]
    }
}
