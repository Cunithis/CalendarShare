import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GroupJoinView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel:AuthenticationViewModel
    @State private var groupID: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter Group ID", text: $groupID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Join Group") {
                Task {
                    await joinGroup()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(groupID.isEmpty)
        }
        .padding()
    }
    
    private func joinGroup() async {
        guard let user = Auth.auth().currentUser else {
            print("User not authenticated")
            return
        }
        
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupID)
        let userRef = db.collection("users").document(user.uid)
        
        do {
            let groupSnap = try await groupRef.getDocument()
            guard groupSnap.exists else {
                print("Group does not exist")
                return
            }
            
            // Add user to the group's members array
            try await groupRef.updateData([
                "members": FieldValue.arrayUnion([user.uid])
            ])
            
            // Add group ID to the user's groups array
            try await userRef.updateData([
                "groups": FieldValue.arrayUnion([groupID])
            ])

            // Backfill group's calendar with user's existing events
            do {
                try await backfillGroupCalendar(fromUserUid: user.uid, toGroupId: groupID)
                print("Backfilled group calendar for group: \(groupID)")
            } catch {
                print("Failed to backfill group calendar: \(error)")
            }
            
            // Refresh local group list
            await viewModel.startListeningGroups(for: user.uid)
            
            // Dismiss sheet
            dismiss()
            print("Joined group successfully!")
            
        } catch {
            print("Error joining group: \(error)")
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
                // Preserve the same document ID in group calendar
                try await groupCal.document(doc.documentID).setData(doc.data())
            } catch {
                print("[GroupJoinView] Failed to copy event \(doc.documentID) to group \(groupId): \(error)")
            }
        }
    }
}
