import Foundation
import Supabase

final class ClubService: Sendable {
    func createClub(
        name: String,
        description: String?,
        category: String,
        privacy: String,
        bannerData: Data?,
        iconData: Data?
    ) async throws -> ClubRow {
        // TODO: Implement in Prompt 10
        fatalError("Not implemented")
    }

    func getClub(clubId: UUID) async throws -> ClubRow {
        // TODO: Implement in Prompt 10
        fatalError("Not implemented")
    }

    func getMyClubs() async throws -> [ClubRow] {
        // TODO: Implement in Prompt 10
        return []
    }

    func getPublicClubs() async throws -> [ClubRow] {
        // TODO: Implement in Prompt 10
        return []
    }

    func joinClub(clubId: UUID) async throws {
        // TODO: Implement in Prompt 10
    }

    func leaveClub(clubId: UUID) async throws {
        // TODO: Implement in Prompt 10
    }

    func createPost(clubId: UUID, body: String) async throws {
        // TODO: Implement in Prompt 10
    }

    func getPosts(clubId: UUID, page: Int = 1) async throws -> [ClubPostModel] {
        // TODO: Implement in Prompt 10
        return []
    }

    func likePost(postId: UUID) async throws {
        // TODO: Implement in Prompt 10
    }

    func unlikePost(postId: UUID) async throws {
        // TODO: Implement in Prompt 10
    }

    func getComments(postId: UUID) async throws -> [ClubPostCommentRow] {
        // TODO: Implement in Prompt 10
        return []
    }

    func addComment(postId: UUID, body: String, parentCommentId: UUID? = nil) async throws {
        // TODO: Implement in Prompt 10
    }
}
