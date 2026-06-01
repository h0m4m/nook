import Foundation

// MARK: - Database Row

struct ReviewRow: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let mediaItemId: UUID
    let title: String?
    let body: String
    let rating: Double
    let isSpoiler: Bool
    let likesCount: Int
    let createdAt: Date
    let updatedAt: Date
    let userProfile: ReviewAuthor?
    let mediaItem: MediaItemRow?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mediaItemId = "media_item_id"
        case title
        case body
        case rating
        case isSpoiler = "is_spoiler"
        case likesCount = "likes_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userProfile = "user_profile"
        case mediaItem = "media_item"
    }
}

struct ReviewAuthor: Codable, Sendable {
    let id: UUID
    let fullName: String?
    let username: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case username
        case avatarUrl = "avatar_url"
    }
}

struct ReviewCommentRow: Codable, Sendable {
    let id: UUID
    let reviewId: UUID
    let userId: UUID
    let parentCommentId: UUID?
    let body: String
    let likesCount: Int
    let createdAt: Date
    let updatedAt: Date
    let userProfile: ReviewAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case reviewId = "review_id"
        case userId = "user_id"
        case parentCommentId = "parent_comment_id"
        case body
        case likesCount = "likes_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userProfile = "user_profile"
    }
}

// MARK: - View-Facing Models

struct Review: Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let mediaItemId: UUID
    let authorName: String
    let authorUsername: String?
    let authorAvatarURL: URL?
    let mediaTitle: String?
    let mediaImageURL: URL?
    let title: String?
    let body: String
    let rating: Double
    let isSpoiler: Bool
    let likesCount: Int
    let createdAt: Date

    init(from row: ReviewRow) {
        self.id = row.id
        self.userId = row.userId
        self.mediaItemId = row.mediaItemId
        self.authorName = row.userProfile?.fullName ?? row.userProfile?.username ?? "Anonymous"
        self.authorUsername = row.userProfile?.username
        self.authorAvatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.mediaTitle = row.mediaItem?.title
        self.mediaImageURL = row.mediaItem?.imageUrl.flatMap { URL(string: $0) }
        self.title = row.title
        self.body = row.body
        self.rating = row.rating
        self.isSpoiler = row.isSpoiler
        self.likesCount = row.likesCount
        self.createdAt = row.createdAt
    }
}

struct ReviewCommentModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let reviewId: UUID
    let userId: UUID
    let parentCommentId: UUID?
    let authorName: String
    let authorAvatarURL: URL?
    let body: String
    let likesCount: Int
    let createdAt: Date

    init(from row: ReviewCommentRow) {
        self.id = row.id
        self.reviewId = row.reviewId
        self.userId = row.userId
        self.parentCommentId = row.parentCommentId
        self.authorName = row.userProfile?.fullName ?? row.userProfile?.username ?? "Anonymous"
        self.authorAvatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.body = row.body
        self.likesCount = row.likesCount
        self.createdAt = row.createdAt
    }
}
