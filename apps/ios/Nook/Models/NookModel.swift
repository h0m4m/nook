import Foundation

// MARK: - Database Rows

struct NookRow: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let coverUrl: String?
    let privacy: String
    let layout: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case coverUrl = "cover_url"
        case privacy
        case layout
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

// MARK: - View-Facing Models

struct NookCollection: Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let coverURL: URL?
    let privacy: String
    let layout: String
    let createdAt: Date

    init(from row: NookRow) {
        self.id = row.id
        self.userId = row.userId
        self.name = row.name
        self.description = row.description
        self.coverURL = row.coverUrl.flatMap { URL(string: $0) }
        self.privacy = row.privacy
        self.layout = row.layout
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
