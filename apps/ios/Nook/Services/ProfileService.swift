import Foundation
import Supabase

final class ProfileService: Sendable {
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

    func updateProfile(
        userId: UUID,
        fullName: String? = nil,
        username: String? = nil,
        bio: String? = nil,
        avatarURL: String? = nil
    ) async throws {
        var updates: [String: AnyEncodable] = [:]
        if let fullName { updates["full_name"] = AnyEncodable(fullName) }
        if let username { updates["username"] = AnyEncodable(username) }
        if let bio { updates["bio"] = AnyEncodable(bio) }
        if let avatarURL { updates["avatar_url"] = AnyEncodable(avatarURL) }

        guard !updates.isEmpty else { return }

        try await supabase
            .from("user_profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
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

    func follow(userId: UUID) async throws {
        let currentUserId = try await supabase.auth.session.user.id

        struct FollowInsert: Encodable {
            let follower_id: String
            let following_id: String
        }

        try await supabase
            .from("user_follows")
            .insert(FollowInsert(
                follower_id: currentUserId.uuidString,
                following_id: userId.uuidString
            ))
            .execute()
        // The "follow" notification is created server-side by a trigger on user_follows.
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
