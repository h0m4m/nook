import Foundation
import Supabase

final class ProfileService: Sendable {
    private let api = APIClient()

    func getProfile(userId: UUID) async throws -> UserProfileData {
        struct ProfileRow: Decodable {
            let id: UUID
            let full_name: String?
            let username: String?
            let bio: String?
            let avatar_url: String?
            let interests: [String]?
            let username_changed_at: Date?
        }

        let row: ProfileRow = try await supabase
            .from("user_profiles")
            .select("id, full_name, username, bio, avatar_url, interests, username_changed_at")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return UserProfileData(
            id: row.id,
            fullName: row.full_name,
            username: row.username,
            bio: row.bio,
            avatarURL: row.avatar_url.flatMap { URL(string: $0) },
            interests: row.interests ?? [],
            usernameChangedAt: row.username_changed_at
        )
    }

    /// Updates profile fields through the moderation gateway. The free-text
    /// columns (full_name / username / bio) are writable only by the gateway;
    /// the avatar image is moderated too. Only non-nil fields are sent (and thus
    /// changed). A taken username surfaces as an `AppError.clientError`.
    func updateProfile(
        userId: UUID,
        fullName: String? = nil,
        username: String? = nil,
        bio: String? = nil,
        avatarURL: String? = nil
    ) async throws {
        guard fullName != nil || username != nil || bio != nil || avatarURL != nil else { return }

        struct Payload: Encodable, Sendable {
            let full_name: String?
            let username: String?
            let bio: String?
            let avatar_url: String?
        }

        let _: ContentIdResponse = try await api.content("update_profile_text", Payload(
            full_name: fullName,
            username: username,
            bio: bio,
            avatar_url: avatarURL
        ))
    }

    func checkUsernameAvailable(username: String) async throws -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else { return false }

        struct CountRow: Decodable {
            let id: UUID
        }

        let rows: [CountRow] = try await supabase
            .from("user_profiles")
            .select("id")
            .eq("username", value: username)
            .neq("id", value: userId.uuidString)
            .execute()
            .value

        return rows.isEmpty
    }

    func getStats(userId: UUID) async throws -> UserStats {
        let result: JSONObject = try await supabase
            .rpc("get_user_stats", params: ["target_user_id": userId.uuidString])
            .execute()
            .value

        return UserStats(
            trackedCount: (result["tracked_count"]?.intValue) ?? 0,
            reviewCount: (result["review_count"]?.intValue) ?? 0,
            nookCount: (result["nook_count"]?.intValue) ?? 0,
            clubCount: (result["club_count"]?.intValue) ?? 0,
            reviewLikesReceived: (result["review_likes_received"]?.intValue) ?? 0
        )
    }

    func getHoursSpent(userId: UUID) async throws -> Double {
        let result: JSONObject = try await supabase
            .rpc("get_hours_spent", params: ["target_user_id": userId.uuidString])
            .execute()
            .value

        let totalMinutes = result["total_minutes"]?.intValue ?? 0
        return Double(totalMinutes) / 60.0
    }

    /// Recent tracked-media activity for any user ("Recently Active").
    /// Backed by the `get_user_recent_activity` SECURITY DEFINER function because
    /// `tracked_media` RLS is owner-only — a direct table read returns nothing for
    /// another user.
    func getRecentActivity(userId: UUID, limit: Int = 5) async throws -> [RecentActivityRow] {
        struct Params: Encodable {
            let target_user_id: String
            let item_limit: Int
        }

        return try await supabase
            .rpc("get_user_recent_activity", params: Params(
                target_user_id: userId.uuidString,
                item_limit: limit
            ))
            .execute()
            .value
    }

    func follow(userId: UUID) async throws {
        let currentUserId = try await supabase.auth.session.user.id

        struct FollowInsert: Encodable {
            let follower_id: String
            let following_id: String
        }

        // Idempotent: re-following an already-followed user is a no-op rather than a
        // primary-key violation (user_follows PK is follower_id + following_id), which
        // is what previously left user_follows empty when the insert threw. The
        // "follow" notification is created server-side by a trigger on user_follows.
        try await supabase
            .from("user_follows")
            .upsert(
                FollowInsert(
                    follower_id: currentUserId.uuidString,
                    following_id: userId.uuidString
                ),
                onConflict: "follower_id,following_id",
                ignoreDuplicates: true
            )
            .execute()
    }

    func unfollow(userId: UUID) async throws {
        let currentUserId = try await supabase.auth.session.user.id

        try await supabase
            .from("user_follows")
            .delete()
            .eq("follower_id", value: currentUserId.uuidString)
            .eq("following_id", value: userId.uuidString)
            .execute()
    }

    func isFollowing(userId: UUID) async throws -> Bool {
        let currentUserId = try await supabase.auth.session.user.id

        struct Row: Decodable {
            let follower_id: UUID
        }

        let rows: [Row] = try await supabase
            .from("user_follows")
            .select("follower_id")
            .eq("follower_id", value: currentUserId.uuidString)
            .eq("following_id", value: userId.uuidString)
            .execute()
            .value

        return !rows.isEmpty
    }

    func getFollowerCount(userId: UUID) async throws -> Int {
        struct Row: Decodable {
            let following_id: UUID
        }

        let rows: [Row] = try await supabase
            .from("user_follows")
            .select("following_id")
            .eq("following_id", value: userId.uuidString)
            .execute()
            .value

        return rows.count
    }

    func getFollowingCount(userId: UUID) async throws -> Int {
        struct Row: Decodable {
            let follower_id: UUID
        }

        let rows: [Row] = try await supabase
            .from("user_follows")
            .select("follower_id")
            .eq("follower_id", value: userId.uuidString)
            .execute()
            .value

        return rows.count
    }
}

// MARK: - Supporting Types

struct UserProfileData: Sendable {
    let id: UUID
    let fullName: String?
    let username: String?
    let bio: String?
    let avatarURL: URL?
    let interests: [String]
    let usernameChangedAt: Date?

    init(
        id: UUID,
        fullName: String?,
        username: String?,
        bio: String?,
        avatarURL: URL?,
        interests: [String],
        usernameChangedAt: Date? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.username = username
        self.bio = bio
        self.avatarURL = avatarURL
        self.interests = interests
        self.usernameChangedAt = usernameChangedAt
    }
}

struct UserStats: Sendable {
    let trackedCount: Int
    let reviewCount: Int
    let nookCount: Int
    let clubCount: Int
    let reviewLikesReceived: Int
}

/// One row from `get_user_recent_activity` — a recently tracked title plus the
/// current tracking status/score, used to render the profile "Recently Active" list.
struct RecentActivityRow: Decodable, Sendable {
    let title: String?
    let imageUrl: String?
    let status: String
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case title
        case imageUrl = "image_url"
        case status
        case score
    }
}

// MARK: - JSON helpers for RPC

typealias JSONObject = [String: JSONPrimitive]

enum JSONPrimitive: Decodable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        self = .null
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        if case .double(let v) = self { return Int(v) }
        return nil
    }
}
