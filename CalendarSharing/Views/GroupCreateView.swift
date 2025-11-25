import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GroupCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AuthenticationViewModel
    
    @State private var title = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView{
            VStack{
                Form{
                    Section {
                        TextField("Title", text: $title)
                        Button {
                            Task { await createGroup() }
                        } label: {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Create group")
                            }
                        }
                        .disabled(title.isEmpty || isLoading)
                    }
                }
            }
            .navigationTitle("Create group")
        }
    }
    
    func createGroup() async {
        guard let user = viewModel.user else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let db = Firestore.firestore()
        
        // Use UserGroup from Models.swift
        var group = UserGroup(
            id: nil,
            name: title,
            members: [user.uid]
        )
        
        do {
            // Add the group to Firestore
            let ref = try db.collection("groups").addDocument(from: group)
            
            group.id = ref.documentID
            
            // Update the user's 'groups' array atomically
            try await db.collection("users").document(user.uid)
                .updateData([
                    "groups": FieldValue.arrayUnion([ref.documentID])
                ])
            
            
            // Backfill group's calendar with creator's existing events
            do {
                try await backfillGroupCalendar(fromUserUid: user.uid, toGroupId: ref.documentID)
                print("Backfilled group calendar for group: \(ref.documentID)")
            } catch {
                print("Failed to backfill group calendar: \(error)")
            }
            
            // Reset local state and dismiss sheet
            title = ""
            await viewModel.startListeningGroups(for: user.uid)
            CurrentUser.shared.groups.append(group)
            dismiss()
            
            print("Group created successfully!")
        } catch {
            print("Error creating group: \(error)")
        }
    }
    
    // Copy all events from users/{uid}/calendar into groups/{groupId}/calendar
    private func backfillGroupCalendar(fromUserUid uid: String, toGroupId groupId: String) async throws {
        let db = Firestore.firestore()
        let userCal = db.collection("users").document(uid).collection("calendar")
        let groupCal = db.collection("groups").document(groupId).collection("calendar")

        let snapshot = try await userCal.getDocuments()
        for doc in snapshot.documents {
            do {
                var newData = doc.data()
                newData["name"] = CurrentUser.shared.user?.name
                // Preserve the same document ID in group calendar for easy correlation
                try await groupCal.document(doc.documentID).setData(newData)
            } catch {
                print("[GroupCreateView] Failed to copy event \(doc.documentID) to group \(groupId): \(error)")
            }
        }
    }
}
