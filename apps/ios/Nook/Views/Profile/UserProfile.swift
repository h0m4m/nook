import SwiftUI

// MARK: - User Profile Model

struct UserProfile: Identifiable, Hashable {
    let id: String
    let displayName: String
    let username: String
    let bio: String
    let avatarURL: URL?
    let followersCount: Int
    let followingCount: Int
    let trackedMedia: Int
    let reviewsWritten: Int
    let curatedNooks: Int
    let clubs: Int
    let tasteIdentity: [TasteTag]
    let recentActivity: [ProfileActivity]
    let isCurrentUser: Bool

    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Taste Tag

struct TasteTag: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: TasteCategory
}

enum TasteCategory: String, CaseIterable {
    case sciFi
    case rpgs
    case fantasy
    case horror
    case cinema
    case anime
    case books
    case games

    var iconName: String {
        switch self {
        case .sciFi: "crosshairs-bold"
        case .rpgs: "gamepad"
        case .fantasy: "sparkle-bold"
        case .horror: "eye-slash-bold"
        case .cinema: "reel"
        case .anime: "star-fall"
        case .books: "book"
        case .games: "gamepad"
        }
    }

    var color: Color {
        switch self {
        case .sciFi: Color.nook.profileTagSciFi
        case .rpgs: Color.nook.profileTagRPGs
        case .fantasy: Color.nook.profileTagFantasy
        case .horror: Color.nook.profileTagHorror
        case .cinema: Color.nook.profileTagCinema
        case .anime: Color.nook.badgeAnimeText
        case .books: Color.nook.badgeBookText
        case .games: Color.nook.badgeGameText
        }
    }

    var backgroundColor: Color {
        switch self {
        case .sciFi: Color.nook.profileTagSciFiBg
        case .rpgs: Color.nook.profileTagRPGsBg
        case .fantasy: Color.nook.profileTagFantasyBg
        case .horror: Color.nook.profileTagHorrorBg
        case .cinema: Color.nook.profileTagCinemaBg
        case .anime: Color.nook.badgeAnimeBg
        case .books: Color.nook.badgeBookBg
        case .games: Color.nook.badgeGameBg
        }
    }

    var borderColor: Color {
        switch self {
        case .sciFi: Color.nook.profileTagSciFiBorder
        case .rpgs: Color.nook.profileTagRPGsBorder
        case .fantasy: Color.nook.profileTagFantasyBorder
        case .horror: Color.nook.profileTagHorrorBorder
        case .cinema: Color.nook.profileTagCinemaBorder
        case .anime: Color.nook.badgeAnimeText.opacity(0.3)
        case .books: Color.nook.badgeBookText.opacity(0.3)
        case .games: Color.nook.badgeGameText.opacity(0.3)
        }
    }
}

// MARK: - Profile Activity

struct ProfileActivity: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let title: String
    let imageName: String
    let imageURL: URL?
    let placeholderColor: Color?
    let rating: Double?
    let tags: [String]

    init(
        label: String,
        title: String,
        imageName: String,
        imageURL: URL? = nil,
        placeholderColor: Color? = nil,
        rating: Double? = nil,
        tags: [String] = []
    ) {
        self.label = label
        self.title = title
        self.imageName = imageName
        self.imageURL = imageURL
        self.placeholderColor = placeholderColor
        self.rating = rating
        self.tags = tags
    }
}

// MARK: - Profile Tab

enum ProfileTab: String, CaseIterable {
    case tracked = "Tracked"
    case reviews = "Reviews"
    case nooks = "Nooks"
    case posts = "Posts"
}

// MARK: - Profile Lookup

extension UserProfile {
    static func profileFor(name: String) -> UserProfile {
        if name == "Aria Chen" { return .ariaChen }
        return UserProfile(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            displayName: name,
            username: "@\(name.lowercased().replacingOccurrences(of: " ", with: ""))",
            bio: "",
            avatarURL: nil,
            followersCount: 0,
            followingCount: 0,
            trackedMedia: 0,
            reviewsWritten: 0,
            curatedNooks: 0,
            clubs: 0,
            tasteIdentity: [],
            recentActivity: [],
            isCurrentUser: false
        )
    }

    /// A lightweight profile that carries the user's REAL id, for navigation.
    /// `OtherProfileView` loads the rest (follow state, reviews, nooks) from the id,
    /// and moderation/follow actions require this real id — never use
    /// `profileFor(name:)` for navigation to a real account, since its id is a
    /// name-derived slug, not a UUID.
    static func reference(id: UUID, displayName: String, avatarURL: URL? = nil) -> UserProfile {
        UserProfile(
            id: id.uuidString,
            displayName: displayName,
            username: "@\(displayName.lowercased().replacingOccurrences(of: " ", with: ""))",
            bio: "",
            avatarURL: avatarURL,
            followersCount: 0,
            followingCount: 0,
            trackedMedia: 0,
            reviewsWritten: 0,
            curatedNooks: 0,
            clubs: 0,
            tasteIdentity: [],
            recentActivity: [],
            isCurrentUser: false
        )
    }
}

// MARK: - Empty State

extension UserProfile {
    static let empty = UserProfile(
        id: "",
        displayName: "",
        username: "",
        bio: "",
        avatarURL: nil,
        followersCount: 0,
        followingCount: 0,
        trackedMedia: 0,
        reviewsWritten: 0,
        curatedNooks: 0,
        clubs: 0,
        tasteIdentity: [],
        recentActivity: [],
        isCurrentUser: true
    )
}

// MARK: - Sample Data

extension UserProfile {
    static let sampleOwn = UserProfile(
        id: "current-user",
        displayName: "Humam Mourad",
        username: "@humam",
        bio: "Collecting stories across all media. Huge sci-fi and fantasy fan. Searching for the perfect cozy game.",
        avatarURL: nil,
        followersCount: 1200,
        followingCount: 342,
        trackedMedia: 842,
        reviewsWritten: 156,
        curatedNooks: 12,
        clubs: 8,
        tasteIdentity: [
            TasteTag(name: "Sci-Fi", category: .sciFi),
            TasteTag(name: "RPGs", category: .rpgs),
            TasteTag(name: "Fantasy", category: .fantasy),
            TasteTag(name: "Horror", category: .horror),
            TasteTag(name: "Cinema", category: .cinema),
        ],
        recentActivity: [
            ProfileActivity(
                label: "FINISHED PLAYING",
                title: "Iron & Ember",
                imageName: "",
                placeholderColor: Color(hex: 0xC4956E),
                rating: 4.0
            ),
            ProfileActivity(
                label: "WATCHED EP 12 OF",
                title: "The Cloud Weaver",
                imageName: "",
                placeholderColor: Color(hex: 0xD4C4A8),
                tags: ["Anime", "Fantasy"]
            ),
        ],
        isCurrentUser: true
    )

    static let sampleOther = UserProfile(
        id: "other-user",
        displayName: "Yuki Tanaka",
        username: "@yukitan",
        bio: "Anime connoisseur and manga collector. If it has a great story, I'm in.",
        avatarURL: nil,
        followersCount: 3400,
        followingCount: 189,
        trackedMedia: 1250,
        reviewsWritten: 340,
        curatedNooks: 24,
        clubs: 15,
        tasteIdentity: [
            TasteTag(name: "Anime", category: .anime),
            TasteTag(name: "Fantasy", category: .fantasy),
            TasteTag(name: "RPGs", category: .rpgs),
        ],
        recentActivity: [
            ProfileActivity(
                label: "WATCHING",
                title: "Frieren: Beyond Journey's End",
                imageName: "",
                placeholderColor: Color(hex: 0xA8C4D4),
                tags: ["Anime", "Fantasy"]
            ),
            ProfileActivity(
                label: "FINISHED READING",
                title: "Chainsaw Man Vol. 16",
                imageName: "",
                placeholderColor: Color(hex: 0xD4A8A8),
                tags: ["Manga", "Action"]
            ),
        ],
        isCurrentUser: false
    )

    static let ariaChen = UserProfile(
        id: "aria-chen",
        displayName: "Aria Chen",
        username: "@ariachen",
        bio: "Animation nerd. Cyberpunk enthusiast. I review everything I watch — no filter.",
        avatarURL: nil,
        followersCount: 5800,
        followingCount: 412,
        trackedMedia: 1680,
        reviewsWritten: 520,
        curatedNooks: 18,
        clubs: 12,
        tasteIdentity: [
            TasteTag(name: "Anime", category: .anime),
            TasteTag(name: "Sci-Fi", category: .sciFi),
            TasteTag(name: "Cinema", category: .cinema),
        ],
        recentActivity: [
            ProfileActivity(
                label: "REVIEWED",
                title: "Neon Drift",
                imageName: "",
                placeholderColor: Color(hex: 0xB8A8D4),
                rating: 4.5
            ),
            ProfileActivity(
                label: "WATCHING",
                title: "Cyberpunk: Edgerunners",
                imageName: "",
                placeholderColor: Color(hex: 0xD4A8B8),
                tags: ["Anime", "Sci-Fi"]
            ),
        ],
        isCurrentUser: false
    )
}
