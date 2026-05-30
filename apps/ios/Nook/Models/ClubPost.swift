import Foundation

// MARK: - Database Row

struct ClubPostRow: Codable, Sendable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    let body: String
    let isPinned: Bool
    let likesCount: Int
    let createdAt: Date
    let updatedAt: Date
    let userProfile: ReviewAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case userId = "user_id"
        case body
        case isPinned = "is_pinned"
        case likesCount = "likes_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userProfile = "user_profile"
    }
}

struct ClubPostCommentRow: Codable, Sendable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let parentCommentId: UUID?
    let body: String
    let createdAt: Date
    let updatedAt: Date
    let userProfile: ReviewAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case parentCommentId = "parent_comment_id"
        case body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userProfile = "user_profile"
    }
}

// MARK: - View-Facing Model

struct ClubPostModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    let authorName: String
    let authorAvatarURL: URL?
    let body: String
    let isPinned: Bool
    let likesCount: Int
    let createdAt: Date

    init(from row: ClubPostRow) {
        self.id = row.id
        self.clubId = row.clubId
        self.userId = row.userId
        self.authorName = row.userProfile?.fullName ?? row.userProfile?.username ?? "Member"
        self.authorAvatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.body = row.body
        self.isPinned = row.isPinned
        self.likesCount = row.likesCount
        self.createdAt = row.createdAt
    }
}
