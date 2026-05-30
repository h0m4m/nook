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
    ) async throws -> UUID {
        let userId = try await supabase.auth.session.user.id
        let storageService = StorageService()

        var bannerUrl: String?
        if let bannerData {
            let url = try await storageService.uploadImage(
                bucket: "club-assets",
                userId: userId,
                fileName: "banner-\(UUID().uuidString).jpg",
                data: bannerData
            )
            bannerUrl = url.absoluteString
        }

        var iconUrl: String?
        if let iconData {
            let url = try await storageService.uploadImage(
                bucket: "club-assets",
                userId: userId,
                fileName: "icon-\(UUID().uuidString).jpg",
                data: iconData
            )
            iconUrl = url.absoluteString
        }

        struct ClubInsert: Encodable {
            let owner_id: String
            let name: String
            let description: String?
            let category: String
            let privacy: String
            let banner_url: String?
            let icon_url: String?
        }

        struct ClubResult: Decodable {
            let id: UUID
        }

        let result: ClubResult = try await supabase
            .from("clubs")
            .insert(ClubInsert(
                owner_id: userId.uuidString,
                name: name,
                description: description,
                category: category,
                privacy: privacy,
                banner_url: bannerUrl,
                icon_url: iconUrl
            ))
            .select("id")
            .single()
            .execute()
            .value

        // Add creator as owner member
        struct MemberInsert: Encodable {
            let club_id: String
            let user_id: String
            let role: String
        }

        try await supabase
            .from("club_members")
            .insert(MemberInsert(
                club_id: result.id.uuidString,
                user_id: userId.uuidString,
                role: "owner"
            ))
            .execute()

        return result.id
    }

    func getClub(clubId: UUID) async throws -> ClubRow {
        try await supabase
            .from("clubs")
            .select("*")
            .eq("id", value: clubId.uuidString)
            .single()
            .execute()
            .value
    }

    func getMyClubs() async throws -> [ClubRow] {
        let userId = try await supabase.auth.session.user.id

        // Get club IDs where user is a member
        struct MemberRow: Decodable {
            let club_id: UUID
        }

        let memberRows: [MemberRow] = try await supabase
            .from("club_members")
            .select("club_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        guard !memberRows.isEmpty else { return [] }

        let clubIds = memberRows.map { $0.club_id.uuidString }

        let clubs: [ClubRow] = try await supabase
            .from("clubs")
            .select("*")
            .in("id", values: clubIds)
            .order("created_at", ascending: false)
            .execute()
            .value

        return clubs
    }

    func getPublicClubs() async throws -> [ClubRow] {
        try await supabase
            .from("clubs")
            .select("*")
            .eq("privacy", value: "public")
            .order("member_count", ascending: false)
            .range(from: 0, to: 49)
            .execute()
            .value
    }

    func joinClub(clubId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct MemberInsert: Encodable {
            let club_id: String
            let user_id: String
            let role: String
        }

        try await supabase
            .from("club_members")
            .insert(MemberInsert(
                club_id: clubId.uuidString,
                user_id: userId.uuidString,
                role: "member"
            ))
            .execute()
    }

    func leaveClub(clubId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("club_members")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func isMember(clubId: UUID) async throws -> Bool {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable {
            let user_id: UUID
        }

        let rows: [Row] = try await supabase
            .from("club_members")
            .select("user_id")
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return !rows.isEmpty
    }

    func getMembers(clubId: UUID) async throws -> [ClubMemberRow] {
        try await supabase
            .from("club_members")
            .select("*, user_profile:user_profiles!user_id(id, full_name, username, avatar_url)")
            .eq("club_id", value: clubId.uuidString)
            .order("joined_at", ascending: true)
            .execute()
            .value
    }

    func createPost(clubId: UUID, body: String) async throws {
        let userId = try await supabase.auth.session.user.id

        struct PostInsert: Encodable {
            let club_id: String
            let user_id: String
            let body: String
        }

        try await supabase
            .from("club_posts")
            .insert(PostInsert(
                club_id: clubId.uuidString,
                user_id: userId.uuidString,
                body: body
            ))
            .execute()
    }

    func getPosts(clubId: UUID, page: Int = 1) async throws -> [ClubPostModel] {
        let limit = 20
        let offset = (page - 1) * limit

        let rows: [ClubPostRow] = try await supabase
            .from("club_posts")
            .select("*, user_profile:user_profiles!user_id(id, full_name, username, avatar_url)")
            .eq("club_id", value: clubId.uuidString)
            .order("is_pinned", ascending: false)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return rows.map { ClubPostModel(from: $0) }
    }

    func likePost(postId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct LikeInsert: Encodable {
            let user_id: String
            let post_id: String
        }

        try await supabase
            .from("club_post_likes")
            .insert(LikeInsert(
                user_id: userId.uuidString,
                post_id: postId.uuidString
            ))
            .execute()
    }

    func unlikePost(postId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("club_post_likes")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("post_id", value: postId.uuidString)
            .execute()
    }

    func getComments(postId: UUID) async throws -> [ClubPostCommentRow] {
        try await supabase
            .from("club_post_comments")
            .select("*, user_profile:user_profiles!user_id(id, full_name, username, avatar_url)")
            .eq("post_id", value: postId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func addComment(postId: UUID, body: String, parentCommentId: UUID? = nil) async throws {
        let userId = try await supabase.auth.session.user.id

        struct CommentInsert: Encodable {
            let post_id: String
            let user_id: String
            let parent_comment_id: String?
            let body: String
        }

        try await supabase
            .from("club_post_comments")
            .insert(CommentInsert(
                post_id: postId.uuidString,
                user_id: userId.uuidString,
                parent_comment_id: parentCommentId?.uuidString,
                body: body
            ))
            .execute()
    }
}
