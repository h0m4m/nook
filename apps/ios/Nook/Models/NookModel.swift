import Foundation

// MARK: - Database Rows

struct NookRow: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let coverUrl: String?
    let privacy: String
    let likesCount: Int?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case coverUrl = "cover_url"
        case privacy
        case likesCount = "likes_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NookItemRow: Codable, Sendable {
    let id: UUID
    let nookId: UUID
    let mediaItemId: UUID
    let note: String?
    let sortOrder: Int
    let createdAt: Date
    let mediaItem: MediaItemRow?

    enum CodingKeys: String, CodingKey {
        case id
        case nookId = "nook_id"
        case mediaItemId = "media_item_id"
        case note
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case mediaItem = "media_item"
    }
}

/// Embedded author profile (from user_profiles) used by summary + comment queries.
struct NookAuthor: Codable, Sendable {
    let fullName: String?
    let username: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case username
        case avatarUrl = "avatar_url"
    }
}

/// Aggregate count returned by an embedded `nook_items(count)` selection.
struct NookEmbeddedCount: Codable, Sendable {
    let count: Int
}

/// A nook row enriched with owner profile + item count, for list/grid surfaces
/// (Home "Popular", Discover, Library, Profile).
struct NookSummaryRow: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let coverUrl: String?
    let privacy: String
    let likesCount: Int?
    let createdAt: Date
    let userProfile: NookAuthor?
    let items: [NookEmbeddedCount]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case coverUrl = "cover_url"
        case privacy
        case likesCount = "likes_count"
        case createdAt = "created_at"
        case userProfile = "user_profile"
        case items
    }
}

struct NookCommentRow: Codable, Sendable {
    let id: UUID
    let nookId: UUID
    let userId: UUID
    let parentCommentId: UUID?
    let body: String
    let likesCount: Int
    let createdAt: Date
    let updatedAt: Date
    let userProfile: NookAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case nookId = "nook_id"
        case userId = "user_id"
        case parentCommentId = "parent_comment_id"
        case body
        case likesCount = "likes_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userProfile = "user_profile"
    }
}

// MARK: - Privacy

enum NookPrivacy: String, CaseIterable, Equatable, Sendable {
    case publicVisible
    case friendsOnly
    case privateOnly

    var label: String {
        switch self {
        case .publicVisible: "Public"
        case .friendsOnly: "Friends Only"
        case .privateOnly: "Only Me"
        }
    }

    var subtitle: String {
        switch self {
        case .publicVisible: "Visible to everyone"
        case .friendsOnly: "Only friends can see"
        case .privateOnly: "Only you can see"
        }
    }

    var icon: String {
        switch self {
        case .publicVisible: "lock-simple-open"
        case .friendsOnly: "users-bold"
        case .privateOnly: "eye-slash-bold"
        }
    }

    var dbValue: String {
        switch self {
        case .publicVisible: "public"
        case .friendsOnly: "friends_only"
        case .privateOnly: "private"
        }
    }

    static func from(dbValue: String) -> NookPrivacy {
        switch dbValue.lowercased() {
        case "friends_only": .friendsOnly
        case "private": .privateOnly
        default: .publicVisible
        }
    }
}

// MARK: - View-Facing Models

struct NookCollection: Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let coverURL: URL?
    let privacy: String
    let likesCount: Int
    let createdAt: Date

    init(from row: NookRow) {
        self.id = row.id
        self.userId = row.userId
        self.name = row.name
        self.description = row.description
        self.coverURL = row.coverUrl.flatMap { URL(string: $0) }
        self.privacy = row.privacy
        self.likesCount = row.likesCount ?? 0
        self.createdAt = row.createdAt
    }
}

struct NookMediaEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let nookId: UUID
    let mediaItemId: UUID
    let title: String
    let imageURL: URL?
    let mediaType: String
    let note: String?
    let sortOrder: Int

    init(from row: NookItemRow) {
        self.id = row.id
        self.nookId = row.nookId
        self.mediaItemId = row.mediaItemId
        self.title = row.mediaItem?.title ?? ""
        self.imageURL = row.mediaItem?.imageUrl.flatMap { URL(string: $0) }
        self.mediaType = row.mediaItem?.mediaType ?? ""
        self.note = row.note
        self.sortOrder = row.sortOrder
    }
}

struct NookDetail: Sendable {
    let nook: NookCollection
    let items: [NookMediaEntry]
    let ownerName: String?
    let ownerAvatarURL: URL?
}

/// Lightweight summary for list/grid surfaces.
struct NookSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let coverURL: URL?
    let privacy: String
    let likesCount: Int
    let itemCount: Int
    let ownerName: String?
    let ownerAvatarURL: URL?
    let createdAt: Date

    init(from row: NookSummaryRow) {
        self.id = row.id
        self.userId = row.userId
        self.name = row.name
        self.description = row.description
        self.coverURL = row.coverUrl.flatMap { URL(string: $0) }
        self.privacy = row.privacy
        self.likesCount = row.likesCount ?? 0
        self.itemCount = row.items?.first?.count ?? 0
        self.ownerName = row.userProfile?.fullName ?? row.userProfile?.username
        self.ownerAvatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.createdAt = row.createdAt
    }
}

struct NookCommentModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let nookId: UUID
    let userId: UUID
    let parentCommentId: UUID?
    let authorName: String
    let authorAvatarURL: URL?
    let body: String
    let likesCount: Int
    let createdAt: Date

    init(from row: NookCommentRow) {
        self.id = row.id
        self.nookId = row.nookId
        self.userId = row.userId
        self.parentCommentId = row.parentCommentId
        self.authorName = row.userProfile?.fullName ?? row.userProfile?.username ?? "Anonymous"
        self.authorAvatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.body = row.body
        self.likesCount = row.likesCount
        self.createdAt = row.createdAt
    }
}
