import Foundation
import Supabase

// MARK: - Drafts

struct ClubPollDraft: Sendable {
    let options: [String]
    let closesAt: Date?
}

final class ClubService: Sendable {

    // Embeds reused across post queries.
    private static let postSelect = """
    *, \
    user_profile:user_profiles!club_posts_user_id_user_profiles_fkey(id, full_name, username, avatar_url), \
    images:club_post_images(id, url, position), \
    poll:club_post_polls(id, total_votes, closes_at, options:club_poll_options(id, text, position, votes_count))
    """

    // MARK: - Clubs

    func createClub(
        name: String,
        description: String?,
        category: String,
        privacy: String,
        themeColor: String?,
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
            let theme_color: String?
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
                theme_color: themeColor,
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

    /// Used for live duplicate detection when creating a club.
    func searchClubsByName(_ query: String, limit: Int = 5) async throws -> [ClubRow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return try await supabase
            .from("clubs")
            .select("*")
            .eq("privacy", value: "public")
            .ilike("name", pattern: "%\(trimmed)%")
            .order("member_count", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Membership

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
            .select("*, user_profile:user_profiles!club_members_user_id_user_profiles_fkey(id, full_name, username, avatar_url)")
            .eq("club_id", value: clubId.uuidString)
            .order("joined_at", ascending: true)
            .execute()
            .value
    }

    /// Returns the current user's membership row for a club, if any (used for role + mute state).
    func getMyMembership(clubId: UUID) async throws -> ClubMembershipRow? {
        let userId = try await supabase.auth.session.user.id

        let rows: [ClubMembershipRow] = try await supabase
            .from("club_members")
            .select("club_id, user_id, role, notifications_muted")
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return rows.first
    }

    func setMuted(clubId: UUID, muted: Bool) async throws {
        let userId = try await supabase.auth.session.user.id

        struct MuteUpdate: Encodable { let notifications_muted: Bool }

        try await supabase
            .from("club_members")
            .update(MuteUpdate(notifications_muted: muted))
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Posts

    /// Creates a post, uploading any attached images and persisting an optional poll.
    @discardableResult
    func createPost(
        clubId: UUID,
        body: String,
        imageDatas: [Data] = [],
        poll: ClubPollDraft? = nil
    ) async throws -> UUID {
        let userId = try await supabase.auth.session.user.id

        struct PostInsert: Encodable {
            let club_id: String
            let user_id: String
            let body: String
        }

        struct PostResult: Decodable { let id: UUID }

        let result: PostResult = try await supabase
            .from("club_posts")
            .insert(PostInsert(
                club_id: clubId.uuidString,
                user_id: userId.uuidString,
                body: body
            ))
            .select("id")
            .single()
            .execute()
            .value

        let postId = result.id

        if !imageDatas.isEmpty {
            let storageService = StorageService()
            struct ImageInsert: Encodable {
                let post_id: String
                let url: String
                let position: Int
            }
            var inserts: [ImageInsert] = []
            for (index, data) in imageDatas.enumerated() {
                let url = try await storageService.uploadImage(
                    bucket: "club-assets",
                    userId: userId,
                    fileName: "post-\(postId.uuidString)-\(index)-\(UUID().uuidString).jpg",
                    data: data
                )
                inserts.append(ImageInsert(post_id: postId.uuidString, url: url.absoluteString, position: index))
            }
            try await supabase.from("club_post_images").insert(inserts).execute()
        }

        if let poll, poll.options.count >= 2 {
            struct PollInsert: Encodable {
                let post_id: String
                let closes_at: String?
            }
            struct PollResult: Decodable { let id: UUID }

            let closesAtString = poll.closesAt.map { ISO8601DateFormatter().string(from: $0) }

            let pollResult: PollResult = try await supabase
                .from("club_post_polls")
                .insert(PollInsert(post_id: postId.uuidString, closes_at: closesAtString))
                .select("id")
                .single()
                .execute()
                .value

            struct OptionInsert: Encodable {
                let poll_id: String
                let text: String
                let position: Int
            }

            let options = poll.options.enumerated().map { index, text in
                OptionInsert(poll_id: pollResult.id.uuidString, text: text, position: index)
            }

            try await supabase.from("club_poll_options").insert(options).execute()
        }

        return postId
    }

    func getPosts(clubId: UUID, page: Int = 1) async throws -> [ClubPostModel] {
        let limit = 20
        let offset = (page - 1) * limit

        let rows: [ClubPostRow] = try await supabase
            .from("club_posts")
            .select(Self.postSelect)
            .eq("club_id", value: clubId.uuidString)
            .order("is_pinned", ascending: false)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return rows.map { ClubPostModel(from: $0) }
    }

    func getPost(postId: UUID) async throws -> ClubPostModel {
        let row: ClubPostRow = try await supabase
            .from("club_posts")
            .select(Self.postSelect)
            .eq("id", value: postId.uuidString)
            .single()
            .execute()
            .value

        return ClubPostModel(from: row)
    }

    /// Posts in a club whose body mentions the current user (`@username`).
    func getMentions(clubId: UUID) async throws -> [ClubPostModel] {
        let userId = try await supabase.auth.session.user.id

        struct ProfileRow: Decodable { let username: String? }
        let profile: ProfileRow = try await supabase
            .from("user_profiles")
            .select("username")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        guard let username = profile.username, !username.isEmpty else { return [] }

        let rows: [ClubPostRow] = try await supabase
            .from("club_posts")
            .select(Self.postSelect)
            .eq("club_id", value: clubId.uuidString)
            .ilike("body", pattern: "%@\(username)%")
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value

        return rows.map { ClubPostModel(from: $0) }
    }

    // MARK: - Moderation: pin / delete post

    /// Pin or unpin a post (owner/admin only — enforced by RLS).
    func setPinned(postId: UUID, pinned: Bool) async throws {
        struct PinUpdate: Encodable { let is_pinned: Bool }
        try await supabase
            .from("club_posts")
            .update(PinUpdate(is_pinned: pinned))
            .eq("id", value: postId.uuidString)
            .execute()
    }

    /// Delete a post (author or owner/admin — enforced by RLS).
    func deletePost(postId: UUID) async throws {
        try await supabase
            .from("club_posts")
            .delete()
            .eq("id", value: postId.uuidString)
            .execute()
    }

    // MARK: - Member management

    /// Promote/demote a member (owner only — enforced by RLS).
    func setMemberRole(clubId: UUID, userId: UUID, role: String) async throws {
        struct RoleUpdate: Encodable { let role: String }
        try await supabase
            .from("club_members")
            .update(RoleUpdate(role: role))
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Remove a member from a club (owner/admin only — enforced by RLS).
    func removeMember(clubId: UUID, userId: UUID) async throws {
        try await supabase
            .from("club_members")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Post Likes

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

        await notifyPostOwner(postId: postId, actorId: userId, type: "like_post")
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

    func isPostLiked(postId: UUID) async throws -> Bool {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable { let user_id: UUID }

        let rows: [Row] = try await supabase
            .from("club_post_likes")
            .select("user_id")
            .eq("user_id", value: userId.uuidString)
            .eq("post_id", value: postId.uuidString)
            .execute()
            .value

        return !rows.isEmpty
    }

    /// Set of post IDs the current user has liked within a club (single round-trip for a posts page).
    func getLikedPostIds(clubId: UUID) async throws -> Set<UUID> {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable { let post_id: UUID }

        let rows: [Row] = try await supabase
            .from("club_post_likes")
            .select("post_id, club_posts!inner(club_id)")
            .eq("user_id", value: userId.uuidString)
            .eq("club_posts.club_id", value: clubId.uuidString)
            .execute()
            .value

        return Set(rows.map(\.post_id))
    }

    // MARK: - Comments

    func getComments(postId: UUID) async throws -> [ClubCommentModel] {
        let rows: [ClubPostCommentRow] = try await supabase
            .from("club_post_comments")
            .select("*, user_profile:user_profiles!club_post_comments_user_id_user_profiles_fkey(id, full_name, username, avatar_url)")
            .eq("post_id", value: postId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map { ClubCommentModel(from: $0) }
    }

    @discardableResult
    func addComment(postId: UUID, body: String, parentCommentId: UUID? = nil) async throws -> UUID {
        let userId = try await supabase.auth.session.user.id

        struct CommentInsert: Encodable {
            let post_id: String
            let user_id: String
            let parent_comment_id: String?
            let body: String
        }

        struct CommentResult: Decodable { let id: UUID }

        let result: CommentResult = try await supabase
            .from("club_post_comments")
            .insert(CommentInsert(
                post_id: postId.uuidString,
                user_id: userId.uuidString,
                parent_comment_id: parentCommentId?.uuidString,
                body: body
            ))
            .select("id")
            .single()
            .execute()
            .value

        await notifyPostOwner(postId: postId, actorId: userId, type: "comment_post")

        return result.id
    }

    // MARK: - Comment Likes

    func likeComment(commentId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct LikeInsert: Encodable {
            let user_id: String
            let comment_id: String
        }

        try await supabase
            .from("club_post_comment_likes")
            .insert(LikeInsert(
                user_id: userId.uuidString,
                comment_id: commentId.uuidString
            ))
            .execute()
    }

    func unlikeComment(commentId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("club_post_comment_likes")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("comment_id", value: commentId.uuidString)
            .execute()
    }

    func getLikedCommentIds(postId: UUID) async throws -> Set<UUID> {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable { let comment_id: UUID }

        let rows: [Row] = try await supabase
            .from("club_post_comment_likes")
            .select("comment_id, club_post_comments!inner(post_id)")
            .eq("user_id", value: userId.uuidString)
            .eq("club_post_comments.post_id", value: postId.uuidString)
            .execute()
            .value

        return Set(rows.map(\.comment_id))
    }

    // MARK: - Polls

    /// Casts the current user's vote. Votes are final — one vote per poll, no changing.
    func voteOnPoll(pollId: UUID, optionId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct VoteInsert: Encodable {
            let poll_id: String
            let option_id: String
            let user_id: String
        }

        // Insert only; the (poll_id, user_id) primary key makes a second vote fail,
        // which enforces "vote locks after casting" at the database level too.
        try await supabase
            .from("club_poll_votes")
            .insert(VoteInsert(
                poll_id: pollId.uuidString,
                option_id: optionId.uuidString,
                user_id: userId.uuidString
            ))
            .execute()
    }

    /// The option the current user voted for in a poll, if any.
    func getMyVote(pollId: UUID) async throws -> UUID? {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable { let option_id: UUID }

        let rows: [Row] = try await supabase
            .from("club_poll_votes")
            .select("option_id")
            .eq("poll_id", value: pollId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return rows.first?.option_id
    }

    // MARK: - Invites

    /// Search users by name/username for inviting (excludes the current user).
    func searchUsers(query: String, limit: Int = 25) async throws -> [ReviewAuthor] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let userId = try await supabase.auth.session.user.id
        let escaped = trimmed.replacingOccurrences(of: ",", with: "")

        let rows: [ReviewAuthor] = try await supabase
            .from("user_profiles")
            .select("id, full_name, username, avatar_url")
            .or("username.ilike.%\(escaped)%,full_name.ilike.%\(escaped)%")
            .neq("id", value: userId.uuidString)
            .limit(limit)
            .execute()
            .value

        return rows
    }

    func inviteToClub(clubId: UUID, userId: UUID) async throws {
        let currentUserId = try await supabase.auth.session.user.id

        struct NotifInsert: Encodable {
            let user_id: String
            let actor_id: String
            let type: String
            let reference_id: String
            let reference_type: String
        }

        try await supabase
            .from("notifications")
            .insert(NotifInsert(
                user_id: userId.uuidString,
                actor_id: currentUserId.uuidString,
                type: "club_invite",
                reference_id: clubId.uuidString,
                reference_type: "club"
            ))
            .execute()
    }

    // MARK: - Moderation

    func report(targetType: String, targetId: UUID, reason: String?) async throws {
        let userId = try await supabase.auth.session.user.id

        struct ReportInsert: Encodable {
            let reporter_id: String
            let target_type: String
            let target_id: String
            let reason: String?
        }

        try await supabase
            .from("reports")
            .insert(ReportInsert(
                reporter_id: userId.uuidString,
                target_type: targetType,
                target_id: targetId.uuidString,
                reason: reason
            ))
            .execute()
    }

    func blockUser(userId blockedId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        struct BlockInsert: Encodable {
            let blocker_id: String
            let blocked_id: String
        }

        try await supabase
            .from("user_blocks")
            .insert(BlockInsert(
                blocker_id: userId.uuidString,
                blocked_id: blockedId.uuidString
            ))
            .execute()
    }

    func getBlockedUserIds() async throws -> Set<UUID> {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable { let blocked_id: UUID }

        let rows: [Row] = try await supabase
            .from("user_blocks")
            .select("blocked_id")
            .eq("blocker_id", value: userId.uuidString)
            .execute()
            .value

        return Set(rows.map(\.blocked_id))
    }

    // MARK: - Notifications (best-effort)

    private func notifyPostOwner(postId: UUID, actorId: UUID, type: String) async {
        struct OwnerRow: Decodable { let user_id: UUID }

        guard let owner: OwnerRow = try? await supabase
            .from("club_posts")
            .select("user_id")
            .eq("id", value: postId.uuidString)
            .single()
            .execute()
            .value
        else { return }

        guard owner.user_id != actorId else { return }

        struct NotifInsert: Encodable {
            let user_id: String
            let actor_id: String
            let type: String
            let reference_id: String
            let reference_type: String
        }

        _ = try? await supabase
            .from("notifications")
            .insert(NotifInsert(
                user_id: owner.user_id.uuidString,
                actor_id: actorId.uuidString,
                type: type,
                reference_id: postId.uuidString,
                reference_type: "club_post"
            ))
            .execute()
    }
}
