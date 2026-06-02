import Foundation

// MARK: - Database Rows

struct ClubPostRow: Codable, Sendable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    let body: String
    let isPinned: Bool
    let likesCount: Int
    let commentsCount: Int
    let createdAt: Date
    let updatedAt: Date
    let userProfile: ReviewAuthor?
    let images: [ClubPostImageRow]?
    // PostgREST may serialize the one-to-one poll embed as a single object (unique FK)
    // or an array depending on version; decode tolerantly.
    let poll: SingleOrArray<ClubPollRow>?

    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case userId = "user_id"
        case body
        case isPinned = "is_pinned"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userProfile = "user_profile"
        case images
        case poll
    }
}

struct ClubPostImageRow: Codable, Sendable {
    let id: UUID
    let url: String
    let position: Int
}

/// Decodes a PostgREST embed that may arrive either as a single object or as an array.
struct SingleOrArray<Element: Codable & Sendable>: Codable, Sendable {
    let first: Element?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([Element].self) {
            first = array.first
        } else {
            first = try? container.decode(Element.self)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(first)
    }
}

struct ClubPollRow: Codable, Sendable {
    let id: UUID
    let totalVotes: Int
    let closesAt: Date?
    let options: [ClubPollOptionRow]?

    enum CodingKeys: String, CodingKey {
        case id
        case totalVotes = "total_votes"
        case closesAt = "closes_at"
        case options
    }
}

struct ClubPollOptionRow: Codable, Sendable {
    let id: UUID
    let text: String
    let position: Int
    let votesCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case position
        case votesCount = "votes_count"
    }
}

struct ClubPostCommentRow: Codable, Sendable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let parentCommentId: UUID?
    let body: String
    let likesCount: Int
    let createdAt: Date
    let updatedAt: Date
    let userProfile: ReviewAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
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

struct ClubPollOptionModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let votesCount: Int
}

struct ClubPollModel: Hashable, Sendable {
    let id: UUID
    let totalVotes: Int
    let closesAt: Date?
    let options: [ClubPollOptionModel]

    init(from row: ClubPollRow) {
        self.id = row.id
        self.totalVotes = row.totalVotes
        self.closesAt = row.closesAt
        self.options = (row.options ?? [])
            .sorted { $0.position < $1.position }
            .map { ClubPollOptionModel(id: $0.id, text: $0.text, votesCount: $0.votesCount) }
    }

    /// Human readable remaining time, e.g. "2 days left" or "Ended".
    var durationLabel: String {
        guard let closesAt else { return "Open" }
        let now = Date()
        if closesAt <= now { return "Ended" }
        let seconds = closesAt.timeIntervalSince(now)
        let days = Int(seconds / 86_400)
        if days >= 1 { return days == 1 ? "1 day left" : "\(days) days left" }
        let hours = Int(seconds / 3_600)
        if hours >= 1 { return hours == 1 ? "1 hour left" : "\(hours) hours left" }
        let minutes = max(Int(seconds / 60), 1)
        return minutes == 1 ? "1 minute left" : "\(minutes) minutes left"
    }

    var isClosed: Bool {
        guard let closesAt else { return false }
        return closesAt <= Date()
    }
}

struct ClubPostModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    let authorName: String
    let authorAvatarURL: URL?
    let body: String
    let isPinned: Bool
    let likesCount: Int
    let commentsCount: Int
    let createdAt: Date
    let imageURLs: [URL]
    let poll: ClubPollModel?

    init(from row: ClubPostRow) {
        self.id = row.id
        self.clubId = row.clubId
        self.userId = row.userId
        self.authorName = row.userProfile?.fullName ?? row.userProfile?.username ?? "Member"
        self.authorAvatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.body = row.body
        self.isPinned = row.isPinned
        self.likesCount = row.likesCount
        self.commentsCount = row.commentsCount
        self.createdAt = row.createdAt
        self.imageURLs = (row.images ?? [])
            .sorted { $0.position < $1.position }
            .compactMap { URL(string: $0.url) }
        self.poll = row.poll?.first.map { ClubPollModel(from: $0) }
    }
}

struct ClubCommentModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let parentCommentId: UUID?
    let authorName: String
    let authorAvatarURL: URL?
    let body: String
    let likesCount: Int
    let createdAt: Date

    init(from row: ClubPostCommentRow) {
        self.id = row.id
        self.postId = row.postId
        self.userId = row.userId
        self.parentCommentId = row.parentCommentId
        self.authorName = row.userProfile?.fullName ?? row.userProfile?.username ?? "Member"
        self.authorAvatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.body = row.body
        self.likesCount = row.likesCount
        self.createdAt = row.createdAt
    }
}

// MARK: - Compact Relative Time

extension Date {
    /// Compact relative time used across the clubs UI, e.g. "now", "5m", "2h", "3d", "1w", or "Jan 4".
    var clubRelativeShort: String {
        let seconds = max(Date().timeIntervalSince(self), 0)
        if seconds < 60 { return "now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = Int(seconds / 3_600)
        if hours < 24 { return "\(hours)h" }
        let days = Int(seconds / 86_400)
        if days < 7 { return "\(days)d" }
        let weeks = Int(days / 7)
        if weeks < 5 { return "\(weeks)w" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}
