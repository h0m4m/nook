import Foundation

// MARK: - Database Row

struct ActivityFeedRow: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let actionType: String
    let mediaItemId: UUID?
    let referenceId: UUID?
    let referenceType: String?
    let createdAt: Date
    let userProfile: ReviewAuthor?
    let mediaItem: MediaItemRow?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actionType = "action_type"
        case mediaItemId = "media_item_id"
        case referenceId = "reference_id"
        case referenceType = "reference_type"
        case createdAt = "created_at"
        case userProfile = "user_profile"
        case mediaItem = "media_item"
    }
}

// MARK: - View-Facing Model

struct ActivityFeedEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let userName: String
    let userAvatarURL: URL?
    let actionType: String
    let mediaTitle: String?
    let mediaImageURL: URL?
    let mediaType: String?
    let referenceId: UUID?
    let referenceType: String?
    let createdAt: Date

    init(from row: ActivityFeedRow) {
        self.id = row.id
        self.userId = row.userId
        self.userName = row.userProfile?.fullName ?? row.userProfile?.username ?? "Someone"
        self.userAvatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.actionType = row.actionType
        self.mediaTitle = row.mediaItem?.title
        self.mediaImageURL = row.mediaItem?.imageUrl.flatMap { URL(string: $0) }
        self.mediaType = row.mediaItem?.mediaType
        self.referenceId = row.referenceId
        self.referenceType = row.referenceType
        self.createdAt = row.createdAt
    }

    var actionLabel: String {
        switch actionType {
        case "tracked": "tracked"
        case "reviewed": "reviewed"
        case "created_nook": "created a nook"
        case "joined_club": "joined a club"
        case "completed": "completed"
        default: actionType
        }
    }
}
