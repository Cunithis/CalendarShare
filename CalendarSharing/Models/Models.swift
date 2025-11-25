import FirebaseFirestore

struct Event: Identifiable, Codable, Equatable {
    @DocumentID var id: String? // Firestore document ID
    var title: String
    var occuringOnDays: [Int]     // [1,2,3,...]
    var timeStart: Int            // 1000
    var timeEnd: Int              // 1900
    var name: String? = nil
}

struct AppUser: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var email: String
    var name: String
    var profilePicture: String
    var groups: [String]
}

struct UserGroup: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var members: [String]
}

// Represents a proposal inside groups/{groupId}/proposals
struct GroupProposal: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var occuringOnDays: [Int]
    var timeStart: Int
    var timeEnd: Int
    // UIDs of members who have accepted this proposal
    var accepted: [String:String] = [:]
    var declined: [String:String] = [:]
    var name: String? = nil
}
