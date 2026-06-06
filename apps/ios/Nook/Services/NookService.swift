import Foundation
import Supabase

final class NookService: Sendable {
    private let api = APIClient()

    /// Embedded owner profile + the contained media posters for list/grid surfaces.
    private static let summarySelect =
        "*, user_profile:user_profiles!nooks_user_id_user_profiles_fkey(full_name, username, avatar_url), preview:nook_items(sort_order, media_item:media_items(image_url))"

    func createNook(
        name: String,
        description: String?,
        privacy: String
    ) async throws -> UUID {
        struct Payload: Encodable, Sendable {
            let name: String
            let description: String?
            let privacy: String
        }

        let result: ContentIdResponse = try await api.content("create_nook", Payload(
            name: name,
            description: description,
            privacy: privacy
        ))
        return result.id
    }

    /// Replace all items in a nook with the given list (moderating any per-item
    /// notes server-side). Used both when first populating a nook and when editing.
    func setItems(
        nookId: UUID,
        items: [(mediaItemId: UUID, note: String?, sortOrder: Int)]
    ) async throws {
        struct Item: Encodable, Sendable {
            let media_item_id: String
            let note: String?
            let sort_order: Int
        }
        struct Payload: Encodable, Sendable {
            let nook_id: String
            let items: [Item]
        }

        let _: EmptyResponse = try await api.content("set_nook_items", Payload(
            nook_id: nookId.uuidString,
            items: items.map {
                Item(media_item_id: $0.mediaItemId.uuidString, note: $0.note, sort_order: $0.sortOrder)
            }
        ))
    }

    /// Back-compat aliases — both now replace the full item set via the gateway.
    func addItems(nookId: UUID, items: [(mediaItemId: UUID, note: String?, sortOrder: Int)]) async throws {
        try await setItems(nookId: nookId, items: items)
    }

    func replaceItems(nookId: UUID, items: [(mediaItemId: UUID, note: String?, sortOrder: Int)]) async throws {
        try await setItems(nookId: nookId, items: items)
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
        struct Payload: Encodable, Sendable {
            let nook_id: String
            let body: String
            let parent_comment_id: String?
        }

        let _: ContentIdResponse = try await api.content("create_nook_comment", Payload(
            nook_id: nookId.uuidString,
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
