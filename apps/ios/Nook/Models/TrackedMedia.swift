import Foundation

// MARK: - Database Row (from Supabase)

struct TrackedMediaRow: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let mediaItemId: UUID
    let status: String
    let progress: Int
    let score: Double?
    let startedAt: Date?
    let completedAt: Date?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let mediaItem: MediaItemRow?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mediaItemId = "media_item_id"
        case status
        case progress
        case score
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case mediaItem = "media_item"
    }
}

struct MediaItemRow: Codable, Sendable {
    let id: UUID
    let source: String
    let sourceId: String
    let mediaType: String
    let title: String
    let imageUrl: String?
    let year: String?
    let genres: [String]?
    let score: Double?
    let scoreCount: Int?
    let synopsis: String?

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceId = "source_id"
        case mediaType = "media_type"
        case title
        case imageUrl = "image_url"
        case year
        case genres
        case score
        case scoreCount = "score_count"
        case synopsis
    }
}

// MARK: - View-Facing Model

struct TrackedMediaItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let mediaItemId: UUID
    let source: String
    let sourceId: String
    let mediaType: String
    let title: String
    let imageURL: URL?
    let year: String?
    let genres: [String]
    var status: String
    var progress: Int
    var score: Double?
    let startedAt: Date?
    let completedAt: Date?
    let notes: String?
    let updatedAt: Date

    init(from row: TrackedMediaRow) {
        self.id = row.id
        self.mediaItemId = row.mediaItemId
        self.source = row.mediaItem?.source ?? ""
        self.sourceId = row.mediaItem?.sourceId ?? ""
        self.mediaType = row.mediaItem?.mediaType ?? ""
        self.title = row.mediaItem?.title ?? ""
        self.imageURL = row.mediaItem?.imageUrl.flatMap { URL(string: $0) }
        self.year = row.mediaItem?.year
        self.genres = row.mediaItem?.genres ?? []
        self.status = row.status
        self.progress = row.progress
        self.score = row.score
        self.startedAt = row.startedAt
        self.completedAt = row.completedAt
        self.notes = row.notes
        self.updatedAt = row.updatedAt
    }
}
