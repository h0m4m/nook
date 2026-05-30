import Foundation
import Supabase

final class ReviewService: Sendable {
    func getReviewsForMedia(mediaItemId: UUID, page: Int = 1) async throws -> [Review] {
        // TODO: Implement in Prompt 8
        return []
    }

    func createReview(
        mediaItemId: UUID,
        title: String?,
        body: String,
        rating: Double,
        isSpoiler: Bool
    ) async throws -> Review {
        // TODO: Implement in Prompt 8
        fatalError("Not implemented")
    }

    func deleteReview(reviewId: UUID) async throws {
        // TODO: Implement in Prompt 8
    }

    func likeReview(reviewId: UUID) async throws {
        // TODO: Implement in Prompt 8
    }

    func unlikeReview(reviewId: UUID) async throws {
        // TODO: Implement in Prompt 8
    }

    func isReviewLiked(reviewId: UUID) async throws -> Bool {
        // TODO: Implement in Prompt 8
        return false
    }

    func getComments(reviewId: UUID) async throws -> [ReviewCommentModel] {
        // TODO: Implement in Prompt 8
        return []
    }

    func addComment(reviewId: UUID, body: String, parentCommentId: UUID? = nil) async throws {
        // TODO: Implement in Prompt 8
    }

    func getTrendingReviews(limit: Int = 5) async throws -> [Review] {
        // TODO: Implement in Prompt 8
        return []
    }
}
