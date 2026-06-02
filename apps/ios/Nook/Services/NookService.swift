import Foundation
import Supabase

final class NookService: Sendable {
    /// Embedded owner profile + the contained media posters for list/grid surfaces.
    private static let summarySelect =
        "*, user_profile:user_profiles!nooks_user_id_user_profiles_fkey(full_name, username, avatar_url), preview:nook_items(sort_order, media_item:media_items(image_url))"

    func createNook(
        name: String,
        description: String?,
        privacy: String
    ) async throws -> UUID {
        let userId = try await supabase.auth.session.user.id

        struct NookInsert: Encodable {
            let user_id: String
            let name: String
            let description: String?
            let privacy: String
        }

        struct NookResult: Decodable {
            let id: UUID
        }

        let result: NookResult = try await supabase
            .from("nooks")
            .insert(NookInsert(
                user_id: userId.uuidString,
                name: name,
                description: description,
                privacy: privacy
            ))
            .select("id")
            .single()
            .execute()
            .value

        // Insert activity feed entry
        struct ActivityInsert: Encodable {
            let user_id: String
            let action_type: String
            let reference_id: String
            let reference_type: String
        }

        _ = try? await supabase
            .from("activity_feed")
            .insert(ActivityInsert(
                user_id: userId.uuidString,
                action_type: "created_nook",
                reference_id: result.id.uuidString,
                reference_type: "nook"
            ))
            .execute()

        return result.id
    }

    func addItems(
        nookId: UUID,
        items: [(mediaItemId: UUID, note: String?, sortOrder: Int)]
    ) async throws {
        struct ItemInsert: Encodable {
            let nook_id: String
            let media_item_id: String
            let note: String?
            let sort_order: Int
        }

        let rows = items.map {
            ItemInsert(
                nook_id: nookId.uuidString,
                media_item_id: $0.mediaItemId.uuidString,
                note: $0.note,
                sort_order: $0.sortOrder
            )
        }

        try await supabase
            .from("nook_items")
            .insert(rows)
            .execute()
    }

    /// Replace all items in a nook with the given list (used when editing).
    func replaceItems(
        nookId: UUID,
        items: [(mediaItemId: UUID, note: String?, sortOrder: Int)]
    ) async throws {
        try await supabase
            .from("nook_items")
            .delete()
            .eq("nook_id", value: nookId.uuidString)
            .execute()

        if !items.isEmpty {
            try await addItems(nookId: nookId, items: items)
        }
    }

    func getNook(nookId: UUID) async throws -> NookDetail {
        let row: NookRow = try await supabase
            .from("nooks")
            .select("*")
            .eq("id", value: nookId.uuidString)
            .single()
            .execute()
            .value

        let itemRows: [NookItemRow] = try await supabase
            .from("nook_items")
            .select("*, media_item:media_items(*)")
            .eq("nook_id", value: nookId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value

        // Get owner profile
        struct OwnerRow: Decodable {
            let full_name: String?
            let avatar_url: String?
        }

        let owner: OwnerRow? = try? await supabase
            .from("user_profiles")
            .select("full_name, avatar_url")
            .eq("id", value: row.userId.uuidString)
            .single()
            .execute()
            .value

        return NookDetail(
            nook: NookCollection(from: row),
            items: itemRows.map { NookMediaEntry(from: $0) },
            ownerName: owner?.full_name,
            ownerAvatarURL: owner?.avatar_url.flatMap { URL(string: $0) }
        )
    }

    /// Nooks owned by a user, enriched with owner profile + item counts.
    /// RLS scopes visibility (own → all; others → public/friends-only).
    func getUserNooks(userId: UUID) async throws -> [NookSummary] {
        let rows: [NookSummaryRow] = try await supabase
            .from("nooks")
            .select(Self.summarySelect)
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.map { NookSummary(from: $0) }
    }

    /// Public nooks for Home "Popular" and Discover.
    func getPopularNooks(limit: Int = 10) async throws -> [NookSummary] {
        let rows: [NookSummaryRow] = try await supabase
            .from("nooks")
            .select(Self.summarySelect)
            .eq("privacy", value: "public")
            .order("likes_count", ascending: false)
            .order("created_at", ascending: false)
            .range(from: 0, to: limit - 1)
            .execute()
            .value

        return rows.map { NookSummary(from: $0) }
    }

    func deleteNook(nookId: UUID) async throws {
        try await supabase
            .from("nooks")
            .delete()
            .eq("id", value: nookId.uuidString)
            .execute()
    }

    // MARK: - Likes

    func likeNook(nookId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct LikeInsert: Encodable {
            let user_id: String
            let nook_id: String
        }

        try await supabase
            .from("nook_likes")
            .insert(LikeInsert(
                user_id: userId.uuidString,
                nook_id: nookId.uuidString
            ))
            .execute()
    }

    func unlikeNook(nookId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("nook_likes")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("nook_id", value: nookId.uuidString)
            .execute()
    }

    func isNookLiked(nookId: UUID) async throws -> Bool {
        let userId = try await supabase.auth.session.user.id

        struct LikeRow: Decodable {
            let user_id: UUID
        }

        let rows: [LikeRow] = try await supabase
            .from("nook_likes")
            .select("user_id")
            .eq("user_id", value: userId.uuidString)
            .eq("nook_id", value: nookId.uuidString)
            .execute()
            .value

        return !rows.isEmpty
    }

    // MARK: - Comments

    func getComments(nookId: UUID) async throws -> [NookCommentModel] {
        let rows: [NookCommentRow] = try await supabase
            .from("nook_comments")
            .select("*, user_profile:user_profiles!nook_comments_user_id_user_profiles_fkey(full_name, username, avatar_url)")
            .eq("nook_id", value: nookId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map { NookCommentModel(from: $0) }
    }

    func addComment(nookId: UUID, body: String, parentCommentId: UUID? = nil) async throws {
        let userId = try await supabase.auth.session.user.id

        struct CommentInsert: Encodable {
            let nook_id: String
            let user_id: String
            let parent_comment_id: String?
            let body: String
        }

        try await supabase
            .from("nook_comments")
            .insert(CommentInsert(
                nook_id: nookId.uuidString,
                user_id: userId.uuidString,
                parent_comment_id: parentCommentId?.uuidString,
                body: body
            ))
            .execute()
    }

    // MARK: - Comment Likes

    func likeComment(commentId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct LikeInsert: Encodable {
            let user_id: String
            let comment_id: String
        }

        try await supabase
            .from("nook_comment_likes")
            .insert(LikeInsert(
                user_id: userId.uuidString,
                comment_id: commentId.uuidString
            ))
            .execute()
    }

    func unlikeComment(commentId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("nook_comment_likes")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("comment_id", value: commentId.uuidString)
            .execute()
    }

    func getLikedCommentIds(nookId: UUID) async throws -> Set<UUID> {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable { let comment_id: UUID }

        let rows: [Row] = try await supabase
            .from("nook_comment_likes")
            .select("comment_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return Set(rows.map(\.comment_id))
    }
}
