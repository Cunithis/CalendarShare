import SwiftUI
import FirebaseFirestore
import Combine

/// Thin controller responsible for synchronising group-level calendar data
/// (events + proposals) between Firestore and local state.
///
/// It:
///  - seeds its state from CurrentUser's caches (for fast UI)
///  - attaches snapshot listeners to Firestore
///  - writes fresh snapshots back into CurrentUser caches
///
/// Views should depend on this controller instead of talking to Firestore
/// directly, which keeps networking concerns out of the UI layer.
final class CalendarDataController: ObservableObject {
    @Published var groupEvents: [Event] = []
    @Published var groupProposals: [GroupProposal] = []

    private var groupListener: ListenerRegistration?
    private var proposalsListener: ListenerRegistration?

    private let groupId: String
    private let currentUser: CurrentUser

    init(currentUser: CurrentUser, groupId: String) {
        self.currentUser = currentUser
        self.groupId = groupId

        // Seed from cache so the UI can render instantly without waiting
        // for the first Firestore snapshot.
        if let cachedEvents = currentUser.groupEventsCache[groupId] {
            self.groupEvents = cachedEvents
        }
        if let cachedProposals = currentUser.groupProposalsCache[groupId] {
            self.groupProposals = cachedProposals
        }
    }

    /// Start Firestore listeners for this group's calendar and proposals
    /// if they are not already active.
    func startListenersIfNeeded() {
        if groupListener == nil {
            let groupRef = Firestore.firestore()
                .collection("groups")
                .document(groupId)
                .collection("calendar")

            groupListener = groupRef.addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let snapshot = snapshot else { return }

                let events: [Event] = snapshot.documents.compactMap { doc in
                    var ev = try? doc.data(as: Event.self)
                    if ev?.id == nil {
                        ev?.id = doc.documentID
                    }
                    return ev
                }

                DispatchQueue.main.async {
                    // Only publish if data actually changed, to avoid
                    // unnecessary UI updates and cache writes.
                    if self.groupEvents != events {
                        self.groupEvents = events
                        self.currentUser.updateGroupEventsCache(for: self.groupId, events: events)
                    }
                }
            }
        }

        if proposalsListener == nil {
            let proposalsRef = Firestore.firestore()
                .collection("groups")
                .document(groupId)
                .collection("proposals")

            proposalsListener = proposalsRef.addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let snapshot = snapshot else { return }

                let proposals: [GroupProposal] = snapshot.documents.compactMap { doc in
                    var proposal = try? doc.data(as: GroupProposal.self)
                    if proposal?.id == nil {
                        proposal?.id = doc.documentID
                    }
                    return proposal
                }

                DispatchQueue.main.async {
                    if self.groupProposals != proposals {
                        self.groupProposals = proposals
                        self.currentUser.updateGroupProposalsCache(for: self.groupId, proposals: proposals)
                    }
                }
            }
        }
    }

    /// Stop all active listeners for this group.
    func stopListeners() {
        groupListener?.remove()
        groupListener = nil

        proposalsListener?.remove()
        proposalsListener = nil
    }

    deinit {
        stopListeners()
    }
}
