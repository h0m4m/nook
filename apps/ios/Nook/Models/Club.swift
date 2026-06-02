import Foundation

// MARK: - Database Rows

struct ClubRow: Codable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let description: String?
    let category: String
    let privacy: String
    let bannerUrl: String?
    let iconUrl: String?
    let themeColor: String?
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case description
        case category
        case privacy
        case bannerUrl = "banner_url"
        case iconUrl = "icon_url"
        case themeColor = "theme_color"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ClubMemberRow: Codable, Sendable {
    let clubId: UUID
    let userId: UUID
    let role: String
    let joinedAt: Date
    let userProfile: ReviewAuthor?

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case userProfile = "user_profile"
    }
}

/// Lightweight membership row for the current user (role + mute preference).
struct ClubMembershipRow: Codable, Sendable {
    let clubId: UUID
    let userId: UUID
    let role: String
    let notificationsMuted: Bool

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case userId = "user_id"
        case role
        case notificationsMuted = "notifications_muted"
    }
}

// MARK: - View-Facing Models

struct Club: Identifiable, Hashable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let description: String?
    let category: String
    let privacy: String
    let bannerURL: URL?
    let iconURL: URL?
    let memberCount: Int
    let createdAt: Date

    init(from row: ClubRow) {
        self.id = row.id
        self.ownerId = row.ownerId
        self.name = row.name
        self.description = row.description
        self.category = row.category
        self.privacy = row.privacy
        self.bannerURL = row.bannerUrl.flatMap { URL(string: $0) }
        self.iconURL = row.iconUrl.flatMap { URL(string: $0) }
        self.memberCount = row.memberCount
        self.createdAt = row.createdAt
    }
}

struct ClubMemberModel: Identifiable, Hashable, Sendable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    let role: String
    let name: String
    let avatarURL: URL?
    let joinedAt: Date

    var isId: UUID { userId }

    init(from row: ClubMemberRow) {
        self.id = row.userId
        self.clubId = row.clubId
        self.userId = row.userId
        self.role = row.role
        self.name = row.userProfile?.fullName ?? row.userProfile?.username ?? "Member"
        self.avatarURL = row.userProfile?.avatarUrl.flatMap { URL(string: $0) }
        self.joinedAt = row.joinedAt
    }
}
