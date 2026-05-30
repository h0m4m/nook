import Foundation
import Supabase

final class ProfileService: Sendable {
    func getProfile(userId: UUID) async throws -> UserProfileData {
        // TODO: Implement in Prompt 7
        fatalError("Not implemented")
    }

    func updateProfile(
        userId: UUID,
        fullName: String?,
        username: String?,
        bio: String?,
        avatarURL: String?
    ) async throws {
        // TODO: Implement in Prompt 7
    }

    func checkUsernameAvailable(username: String) async throws -> Bool {
        // TODO: Implement in Prompt 7
        return true
    }

    func getStats(userId: UUID) async throws -> UserStats {
        // TODO: Implement in Prompt 7
        fatalError("Not implemented")
    }

    func follow(userId: UUID) async throws {
        // TODO: Implement in Prompt 11
    }

    func unfollow(userId: UUID) async throws {
        // TODO: Implement in Prompt 11
    }

    func isFollowing(userId: UUID) async throws -> Bool {
        // TODO: Implement in Prompt 11
        return false
    }

    func getFollowerCount(userId: UUID) async throws -> Int {
        // TODO: Implement in Prompt 11
        return 0
    }

    func getFollowingCount(userId: UUID) async throws -> Int {
        // TODO: Implement in Prompt 11
        return 0
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
}

struct UserStats: Sendable {
    let trackedCount: Int
    let reviewCount: Int
    let nookCount: Int
    let clubCount: Int
}
