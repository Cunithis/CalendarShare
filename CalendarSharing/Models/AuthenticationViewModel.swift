//
// AuthenticationViewModel.swift
// Favourites
//
// Created by Peter Friese on 08.07.2022
// Copyright © 2022 Google LLC.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

enum AuthenticationState {
  case unauthenticated
  case authenticating
  case authenticated
}

enum AuthenticationFlow {
  case login
  case signUp
}

@MainActor
class AuthenticationViewModel: ObservableObject {
  let db = Firestore.firestore()
  @Published var email = ""
  @Published var password = ""
  @Published var confirmPassword = ""
  @Published var username = ""

  @Published var flow: AuthenticationFlow = .login

  @Published var isValid  = false
  @Published var authenticationState: AuthenticationState = .unauthenticated
  @Published var errorMessage = ""
  @Published var user: FirebaseAuth.User?
  @Published var displayName = ""
  @Published var events: [Event] = []
  private var listener: ListenerRegistration?
    @Published var groups: [UserGroup] = []
    private var groupsListener: ListenerRegistration?
    private var groupsListeners: [ListenerRegistration] = []

  init() {
    registerAuthStateHandler()

    $flow
      .combineLatest($email, $password, $confirmPassword)
      .map { flow, email, password, confirmPassword in
        flow == .login
          ? !(email.isEmpty || password.isEmpty)
          : !(email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
      }
      .assign(to: &$isValid)
      
      Task { @MainActor in
          if let currentUser = Auth.auth().currentUser {
              self.user = currentUser
              self.authenticationState = .authenticated
              self.displayName = currentUser.email ?? ""
              await startListeningAfterAuth()
          }
      }
  }

  private var authStateHandler: AuthStateDidChangeListenerHandle?

  func registerAuthStateHandler() {
    if authStateHandler == nil {
      authStateHandler = Auth.auth().addStateDidChangeListener { auth, user in
        self.user = user
        self.authenticationState = user == nil ? .unauthenticated : .authenticated
        self.displayName = user?.email ?? ""
      }
    }
  }
    func loadCurrentUserIfNeeded() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        
        // Fetch Firestore user document
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(firebaseUser.uid)
                .getDocument()
            
            if let appUser = try? snapshot.data(as: AppUser.self) {
                CurrentUser.shared.user = appUser
            }
        } catch {
            print("Failed to load current user: \(error.localizedDescription)")
        }
    }


  func switchFlow() {
    flow = flow == .login ? .signUp : .login
    errorMessage = ""
  }

  private func wait() async {
    do {
      print("Wait")
      try await Task.sleep(nanoseconds: 1_000_000_000)
      print("Done")
    }
    catch {
      print(error.localizedDescription)
    }
  }

  func reset() {
    flow = .login
    email = ""
    password = ""
    confirmPassword = ""
  }
}

// MARK: - Email and Password Authentication

extension AuthenticationViewModel {
  func signInWithEmailPassword() async -> Bool {
    authenticationState = .authenticating
    do {
      let authResult = try await Auth.auth().signIn(withEmail: self.email, password: self.password)
        
        let firebaseUser = authResult.user
        
        let snapshot = try await db.collection("users").document(firebaseUser.uid).getDocument()
        
        if let user = try? snapshot.data(as: AppUser.self) {
            CurrentUser.shared.user = user
        }
        await startListeningAfterAuth()
      return true
    }
    catch  {
      print(error)
      errorMessage = error.localizedDescription
      authenticationState = .unauthenticated
      return false
    }
  }

  func signUpWithEmailPassword() async -> Bool {
    authenticationState = .authenticating
    do  {
      let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
      let firebaseUser = authResult.user
        
        let newUser = AppUser(
            id: firebaseUser.uid,
            email:email,
            name: username.isEmpty ? email : username,
            profilePicture: "",
            groups: []
        )
        
        try db.collection("users").document(firebaseUser.uid).setData(from: newUser)
        
        CurrentUser.shared.user = newUser
        await startListeningAfterAuth()
      return true
    }
    catch {
      print(error)
      errorMessage = error.localizedDescription
      authenticationState = .unauthenticated
      return false
    }
  }

  func signOut() {
    do {
      try Auth.auth().signOut()
        CurrentUser.shared.clear()
    }
    catch {
      print(error)
      errorMessage = error.localizedDescription
    }
  }

  func deleteAccount() async -> Bool {
    do {
      try await user?.delete()
      return true
    }
    catch {
      errorMessage = error.localizedDescription
      return false
    }
  }
    
    // MARK: - Subscribe to events
    func subscribeToEvents(userId: String) {
        // Remove old listener if exists
        listener?.remove()
        
        let db = Firestore.firestore()
        listener = db.collection("users")
            .document(userId)
            .collection("calendar")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to fetch events: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents found")
                    return
                }
                
                let events = documents.compactMap { doc -> Event? in
                    do {
                        let e = try doc.data(as: Event.self)
                        print("Loaded event:", e.title)
                        return e
                    } catch {
                        print("Failed to decode document \(doc.documentID):", error)
                        return nil
                    }
                }
                
                // Only assign if data actually changed
                if self.events != events {
                    self.events = events
                    CurrentUser.shared.updateEvents(events)
                }
                
                print("CurrentUser.shared.events now has \(CurrentUser.shared.events.count) events")
            }
    }

    

        // Stop listening (optional, call on deinit)
        func unsubscribeFromEvents() {
            listener?.remove()
            listener = nil
        }
    
    @MainActor
    func startListeningGroups(for uid: String) async {
        // Prevent duplicate subscriptions
        if !groupsListeners.isEmpty {
            print("Groups listeners already active; skipping re-subscribe.")
            return
        }
        
        // Ensure any stale listeners are cleared
        stopListeningGroups()
        
        let db = Firestore.firestore()
        
        do {
            // Fetch current user document
            let userDoc = try await db.collection("users").document(uid).getDocument()
            guard userDoc.exists else { return }
            
            // Decode user data
            let userData = try userDoc.data(as: AppUser.self)
            let userGroups = userData.groups // [String]
            
            // If user has no groups
            guard !userGroups.isEmpty else {
                self.groups = []
                return
            }
            
            // Firestore limits "in" queries to 10 IDs per query, so split into batches
            let batches = stride(from: 0, to: userGroups.count, by: 10).map {
                Array(userGroups[$0..<min($0 + 10, userGroups.count)])
            }
            print("User has groups:", userGroups)

            
            for batch in batches {
                let listener = db.collection("groups")
                    .whereField(FieldPath.documentID(), in: batch)
                    .addSnapshotListener { snapshot, error in
                        print("Listener triggered for batch:", batch)
                        print("Documents count:", snapshot?.documents.count ?? -1)
                        if let error = error {
                            print("Error fetching groups: \(error)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else { return }
                        
                        var updatedGroups: [UserGroup] = []
                        for doc in documents {
                            if let group = try? doc.data(as: UserGroup.self) {
                                updatedGroups.append(group)
                            }
                        }
                        
                        // Update groups on the main thread
                        DispatchQueue.main.async {
                            // Simply overwrite the groups array with the fetched snapshot, sorted alphabetically
                            let sortedGroups = updatedGroups.sorted { $0.name < $1.name }
                            // Avoid triggering didSet / persistence work if nothing changed.
                            if self.groups != sortedGroups {
                                self.groups = sortedGroups
                                CurrentUser.shared.updateGroups(self.groups)
                            }
                        }

                    }
                
                // Keep reference to listener
                groupsListeners.append(listener)
            }
            
        } catch {
            print("Failed to fetch user or groups: \(error)")
        }
    }

    // Stop all listeners
    func stopListeningGroups() {
        groupsListeners.forEach { $0.remove() }
        groupsListeners = []
    }
    
    @MainActor
    func startListeningAfterAuth() async {
        guard let uid = self.user?.uid else { return }
        subscribeToEvents(userId: uid)
        await startListeningGroups(for: uid)
    }

    }
