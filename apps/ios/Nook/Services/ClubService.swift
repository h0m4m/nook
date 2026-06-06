import Foundation
import Supabase

// MARK: - Drafts

struct ClubPollDraft: Sendable {
    let options: [String]
    let closesAt: Date?
}

final class ClubService: Sendable {

    private let api = APIClient()

    // Embeds reused across post queries.
    private static let postSelect = """
    *, \
    user_profile:user_profiles!club_posts_user_id_user_profiles_fkey(id, full_name, username, avatar_url), \
    images:club_post_images(id, url, position), \
    media:club_post_media(position, media_item:media_items(id, source, source_id, media_type, title, image_url, year)), \
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

        struct Payload: Encodable, Sendable {
            let name: String
            let description: String?
            let category: String
            let privacy: String
            let theme_color: String?
            let banner_url: String?
            let icon_url: String?
        }

        // The gateway creates the club AND the owner membership row server-side.
        let result: ContentIdResponse = try await api.content("create_club", Payload(
            name: name,
            description: description,
            category: category,
            privacy: privacy,
            theme_color: themeColor,
            banner_url: bannerUrl,
            icon_url: iconUrl
        ))

        return result.id
    }

    /// Whether the current user is allowed to create a club right now, and if not,
    /// a human-readable reason. Mirrors the server-side `evaluate_club_creation`
    /// gates (verification / account age / cooldown / lifetime cap / traction) so
    /// the UI can explain the block before the user fills out the form. The DB
    /// trigger remains the source of truth.
    func clubCreationEligibility() async throws -> ClubCreationEligibility {
        try await supabase
            .rpc("can_create_club")
            .execute()
            .value
    }

    /// Update editable club details (owner/manager only — enforced by RLS; the
    /// name is immutable and a 7-day cooldown is enforced by a DB trigger).
    /// New banner/icon images are uploaded only when their `Data` is provided.
    func updateClub(
        clubId: UUID,
        description: String?,
        category: String,
        privacy: String,
        themeColor: String?,
        bannerData: Data?,
        iconData: Data?
    ) async throws {
        let userId = try await supabase.auth.session.user.id
        let storageService = StorageService()

        var bannerUrl: String?
        if let bannerData {
            let url = try await storageService.uploadImage(
                bucket: "club-assets", userId: userId,
                fileName: "banner-\(UUID().uuidString).jpg", data: bannerData
            )
            bannerUrl = url.absoluteString
        }
        var iconUrl: String?
        if let iconData {
            let url = try await storageService.uploadImage(
                bucket: "club-assets", userId: userId,
                fileName: "icon-\(UUID().uuidString).jpg", data: iconData
            )
            iconUrl = url.absoluteString
        }

        struct Payload: Encodable, Sendable {
            let club_id: String
            let description: String?
            let category: String
            let privacy: String
            let theme_color: String?
            let banner_url: String?
            let icon_url: String?
        }

        let _: ContentIdResponse = try await api.content("update_club", Payload(
            club_id: clubId.uuidString,
            description: description,
            category: category,
            privacy: privacy,
            theme_color: themeColor,
            banner_url: bannerUrl,
            icon_url: iconUrl
        ))
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

    /// Delete a club (owner only — enforced by RLS). Cascades to members/posts/etc.
    func deleteClub(clubId: UUID) async throws {
        try await supabase
            .from("clubs")
            .delete()
            .eq("id", value: clubId.uuidString)
            .execute()
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

        // Any join resolves a pending invite + its notification.
        try? await clearMyInvite(clubId: clubId)
        // The "club_join" notification to the owner is created server-side by a
        // trigger on club_members.
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
        mediaItemIds: [UUID] = [],
        poll: ClubPollDraft? = nil
    ) async throws -> UUID {
        let userId = try await supabase.auth.session.user.id

        // Images are uploaded to storage here (we have the bytes); their public
        // URLs are handed to the gateway, which moderates them and persists the
        // post + attachments + poll server-side in one shot.
        struct ImagePayload: Encodable, Sendable {
            let url: String
            let position: Int
        }
        var images: [ImagePayload] = []
        if !imageDatas.isEmpty {
            let storageService = StorageService()
            for (index, data) in imageDatas.enumerated() {
                let url = try await storageService.uploadImage(
                    bucket: "club-assets",
                    userId: userId,
                    fileName: "post-\(index)-\(UUID().uuidString).jpg",
                    data: data
                )
                images.append(ImagePayload(url: url.absoluteString, position: index))
            }
        }

        struct MediaPayload: Encodable, Sendable {
            let media_item_id: String
            let position: Int
        }
        let media = mediaItemIds.enumerated().map { index, id in
            MediaPayload(media_item_id: id.uuidString, position: index)
        }

        struct PollPayload: Encodable, Sendable {
            let closes_at: String?
            let options: [String]
        }
        var pollPayload: PollPayload?
        if let poll, poll.options.count >= 2 {
            pollPayload = PollPayload(
                closes_at: poll.closesAt.map { ISO8601DateFormatter().string(from: $0) },
                options: poll.options
            )
        }

        struct Payload: Encodable, Sendable {
            let club_id: String
            let body: String
            let images: [ImagePayload]
            let media: [MediaPayload]
            let poll: PollPayload?
        }

        let result: ContentIdResponse = try await api.content("create_club_post", Payload(
            club_id: clubId.uuidString,
            body: body,
            images: images,
            media: media,
            poll: pollPayload
        ))

        return result.id
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

    /// All posts authored by a user, newest first, across every club. RLS limits
    /// the result to clubs that are public or that the viewer belongs to. Used by
    /// the Posts tab on a user's profile.
    func getPostsByUser(userId: UUID, limit: Int = 20) async throws -> [ClubPostModel] {
        let rows: [ClubPostRow] = try await supabase
            .from("club_posts")
            .select(Self.postSelect)
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.map { ClubPostModel(from: $0) }
    }

    /// Lightweight name + theme lookup for a set of clubs, used to label posts on a
    /// profile with the club they were posted in.
    func getClubBriefs(ids: [UUID]) async throws -> [UUID: ClubBrief] {
        guard !ids.isEmpty else { return [:] }

        struct BriefRow: Decodable {
            let id: UUID
            let name: String
            let theme_color: String?
            let category: String
        }

        let rows: [BriefRow] = try await supabase
            .from("clubs")
            .select("id, name, theme_color, category")
            .in("id", values: ids.map { $0.uuidString })
            .execute()
            .value

        return Dictionary(uniqueKeysWithValues: rows.map { row in
            (row.id, ClubBrief(id: row.id, name: row.name, themeColor: row.theme_color, category: row.category))
        })
    }

    /// Posts in a club that involve the current user: an @mention of my username,
    /// a comment by someone else on my post, or a reply by someone else to my comment.
    func getMentions(clubId: UUID) async throws -> [ClubPostModel] {
        struct IdRow: Decodable { let post_id: UUID }

        let idRows: [IdRow] = try await supabase
            .rpc("get_club_mention_post_ids", params: ["p_club_id": clubId.uuidString])
            .execute()
            .value

        let ids = idRows.map { $0.post_id.uuidString }
        guard !ids.isEmpty else { return [] }

        let rows: [ClubPostRow] = try await supabase
            .from("club_posts")
            .select(Self.postSelect)
            .in("id", values: ids)
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
        // The "like_post" notification is created server-side by a trigger on
        // club_post_likes.
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
        struct Payload: Encodable, Sendable {
            let post_id: String
            let body: String
            let parent_comment_id: String?
        }

        // The "comment_post" notification (and any @mention notifications) are
        // created server-side by a trigger on club_post_comments.
        let result: ContentIdResponse = try await api.content("create_club_post_comment", Payload(
            post_id: postId.uuidString,
            body: body,
            parent_comment_id: parentCommentId?.uuidString
        ))

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

    /// Invite a user: records a pending invite (grants visibility/join rights for
    /// private clubs) and sends them a notification.
    func inviteToClub(clubId: UUID, userId: UUID) async throws {
        let currentUserId = try await supabase.auth.session.user.id

        struct InviteUpsert: Encodable {
            let club_id: String
            let invitee_id: String
            let inviter_id: String
            let status: String
        }

        // ignoreDuplicates: an existing invite is left as-is (re-inviting is a no-op,
        // not an error — the inviter has no UPDATE rights on the row).
        try await supabase
            .from("club_invites")
            .upsert(
                InviteUpsert(
                    club_id: clubId.uuidString,
                    invitee_id: userId.uuidString,
                    inviter_id: currentUserId.uuidString,
                    status: "pending"
                ),
                onConflict: "club_id,invitee_id",
                ignoreDuplicates: true
            )
            .execute()
        // The "club_invite" notification is created server-side by a trigger on
        // club_invites (only fires on a genuinely new invite, so re-invites don't
        // duplicate it).
    }

    /// Invitee ids with a pending invite to this club that the current user can
    /// see (their own sent invites, or all if owner/manager).
    func getInvitedUserIds(clubId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let invitee_id: UUID }
        let rows: [Row] = try await supabase
            .from("club_invites")
            .select("invitee_id")
            .eq("club_id", value: clubId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
        return Set(rows.map(\.invitee_id))
    }

    /// Whether the current user has a pending invite to this club.
    func hasPendingInvite(clubId: UUID) async throws -> Bool {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await supabase
            .from("club_invites")
            .select("id")
            .eq("club_id", value: clubId.uuidString)
            .eq("invitee_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value

        return !rows.isEmpty
    }

    /// Accept an invite: join the club (which also clears the invite + notification).
    func acceptInvite(clubId: UUID) async throws {
        try await joinClub(clubId: clubId)
    }

    /// Decline an invite: clear it (the invitee loses access to a private club).
    func declineInvite(clubId: UUID) async throws {
        try await clearMyInvite(clubId: clubId)
    }

    private func clearMyInvite(clubId: UUID) async throws {
        let userId = try await supabase.auth.session.user.id
        try await supabase
            .from("club_invites")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .eq("invitee_id", value: userId.uuidString)
            .execute()

        // Keep notifications in sync — resolve the invite notification too.
        _ = try? await supabase
            .from("notifications")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("type", value: "club_invite")
            .eq("reference_id", value: clubId.uuidString)
            .execute()
    }

}

// MARK: - Supporting Types

/// Minimal club info (name + theme) for labelling a post with its club without
/// fetching the full club row.
struct ClubBrief: Sendable, Hashable {
    let id: UUID
    let name: String
    let themeColor: String?
    let category: String
}

/// Result of the `can_create_club` RPC: whether the caller may create a club and,
/// if not, a machine code + friendly message describing why.
struct ClubCreationEligibility: Decodable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?

    var blockedMessage: String? {
        ok ? nil : (message ?? "You can't create a club right now.")
    }
}
