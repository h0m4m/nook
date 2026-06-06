import Foundation
import Supabase

final class ReviewService: Sendable {
    private let api = APIClient()

    func getReviewsForMedia(mediaItemId: UUID, page: Int = 1) async throws -> [Review] {
        let limit = 10
        let offset = (page - 1) * limit

        let rows: [ReviewRow] = try await supabase
            .from("reviews")
            .select("*, user_profile:user_profiles!reviews_user_id_user_profiles_fkey(id, full_name, username, avatar_url), media_item:media_items!reviews_media_item_id_fkey(id, source, source_id, media_type, title, image_url, year)")
            .eq("media_item_id", value: mediaItemId.uuidString)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return rows.map { Review(from: $0) }
    }

    func getUserReview(mediaItemId: UUID) async throws -> Review? {
        let userId = try await supabase.auth.session.user.id

        let rows: [ReviewRow] = try await supabase
            .from("reviews")
            .select()
            .eq("media_item_id", value: mediaItemId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first.map { Review(from: $0) }
    }

    func getReviewsByUser(userId: UUID, limit: Int = 10) async throws -> [Review] {
        let rows: [ReviewRow] = try await supabase
            .from("reviews")
            .select("*, user_profile:user_profiles!reviews_user_id_user_profiles_fkey(id, full_name, username, avatar_url), media_item:media_items!reviews_media_item_id_fkey(id, source, source_id, media_type, title, image_url, year)")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .range(from: 0, to: limit - 1)
            .execute()
            .value

        return rows.map { Review(from: $0) }
    }

    /// Creates/updates the current user's review via the moderation gateway.
    /// Clearing stale comments/likes, resetting the like count and the activity-feed
    /// entry all happen server-side now (see the `create_review` handler).
    func createReview(
        mediaItemId: UUID,
        title: String?,
        body: String,
        rating: Double,
        isSpoiler: Bool
    ) async throws {
        struct Payload: Encodable, Sendable {
            let media_item_id: String
            let title: String?
            let body: String
            let rating: Double
            let is_spoiler: Bool
        }

        let _: ContentIdResponse = try await api.content("create_review", Payload(
            media_item_id: mediaItemId.uuidString,
            title: title,
            body: body,
            rating: rating,
            is_spoiler: isSpoiler
        ))
    }

    func deleteReview(reviewId: UUID) async throws {
        try await supabase
            .from("reviews")
            .delete()
            .eq("id", value: reviewId.uuidString)
            .execute()
    }

    func likeReview(reviewId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct LikeInsert: Encodable {
            let user_id: String
            let review_id: String
        }

        try await supabase
            .from("review_likes")
            .insert(LikeInsert(
                user_id: userId.uuidString,
                review_id: reviewId.uuidString
            ))
            .execute()
    }

    func unlikeReview(reviewId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("review_likes")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("review_id", value: reviewId.uuidString)
            .execute()
    }

    func isReviewLiked(reviewId: UUID) async throws -> Bool {
        let userId = try await supabase.auth.session.user.id

        struct LikeRow: Decodable {
            let user_id: UUID
        }

        let rows: [LikeRow] = try await supabase
            .from("review_likes")
            .select("user_id")
            .eq("user_id", value: userId.uuidString)
            .eq("review_id", value: reviewId.uuidString)
            .execute()
            .value

        return !rows.isEmpty
    }

    func getComments(reviewId: UUID) async throws -> [ReviewCommentModel] {
        let rows: [ReviewCommentRow] = try await supabase
            .from("review_comments")
            .select("*, user_profile:user_profiles!review_comments_user_id_user_profiles_fkey(id, full_name, username, avatar_url)")
            .eq("review_id", value: reviewId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map { ReviewCommentModel(from: $0) }
    }

    func addComment(reviewId: UUID, body: String, parentCommentId: UUID? = nil) async throws {
        struct Payload: Encodable, Sendable {
            let review_id: String
            let body: String
            let parent_comment_id: String?
        }

        let _: ContentIdResponse = try await api.content("create_review_comment", Payload(
            review_id: reviewId.uuidString,
            body: body,
            parent_comment_id: parentCommentId?.uuidString
        ))
    }

    // MARK: - Comment Likes

    func likeComment(commentId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct LikeInsert: Encodable {
            let user_id: String
            let comment_id: String
        }

        try await supabase
            .from("review_comment_likes")
            .insert(LikeInsert(
                user_id: userId.uuidString,
                comment_id: commentId.uuidString
            ))
            .execute()
    }

    func unlikeComment(commentId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("review_comment_likes")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("comment_id", value: commentId.uuidString)
            .execute()
    }

    func getLikedCommentIds(reviewId: UUID) async throws -> Set<UUID> {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable { let comment_id: UUID }

        let rows: [Row] = try await supabase
            .from("review_comment_likes")
            .select("comment_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        // Filter to only comments belonging to this review
        return Set(rows.map(\.comment_id))
    }

    func getTrendingReviews(limit: Int = 5) async throws -> [Review] {
        let rows: [ReviewRow] = try await supabase
            .from("reviews")
            .select("*, user_profile:user_profiles!reviews_user_id_user_profiles_fkey(id, full_name, username, avatar_url), media_item:media_items!reviews_media_item_id_fkey(id, source, source_id, media_type, title, image_url, year)")
            .order("likes_count", ascending: false)
            .order("created_at", ascending: false)
            .range(from: 0, to: limit - 1)
            .execute()
            .value

        return rows.map { Review(from: $0) }
    }
}
