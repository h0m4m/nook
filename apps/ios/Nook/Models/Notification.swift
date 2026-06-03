import Foundation

// MARK: - Database Row

struct NotificationDBRow: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let actorId: UUID
    let type: String
    let referenceId: UUID?
    let referenceType: String?
    let isRead: Bool
    let createdAt: Date
    let actor: ReviewAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorId = "actor_id"
        case type
        case referenceId = "reference_id"
        case referenceType = "reference_type"
        case isRead = "is_read"
        case createdAt = "created_at"
        case actor
    }
}

// MARK: - View-Facing Model

struct NotificationModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let actorId: UUID
    let actorName: String
    let actorAvatarURL: URL?
    let type: String
    let referenceId: UUID?
    let referenceType: String?
    let isRead: Bool
    let createdAt: Date

    init(from row: NotificationDBRow) {
        self.id = row.id
        self.actorId = row.actorId
        self.actorName = row.actor?.fullName ?? row.actor?.username ?? "Someone"
        self.actorAvatarURL = row.actor?.avatarUrl.flatMap { URL(string: $0) }
        self.type = row.type
        self.referenceId = row.referenceId
        self.referenceType = row.referenceType
        self.isRead = row.isRead
        self.createdAt = row.createdAt
    }

    var message: String {
        switch type {
        case "follow": "\(actorName) followed you"
        case "like_review": "\(actorName) liked your review"
        case "comment_review": "\(actorName) commented on your review"
        case "like_post": "\(actorName) liked your post"
        case "comment_post": "\(actorName) commented on your post"
        case "club_invite": "\(actorName) invited you to a club"
        case "club_join": "\(actorName) joined your club"
        case "nook_mention": "\(actorName) mentioned you in a nook"
        default: "\(actorName) interacted with you"
        }
    }
}
