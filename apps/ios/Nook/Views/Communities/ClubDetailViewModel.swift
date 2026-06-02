import Foundation
import SwiftUI
import Supabase

@MainActor
@Observable
final class ClubDetailViewModel {
    var club: ClubRow?
    var posts: [ClubPostModel] = []
    var mentions: [ClubPostModel] = []
    var members: [ClubMemberRow] = []
    var likedPostIds: Set<UUID> = []
    var blockedUserIds: Set<UUID> = []
    var isMember = false
    var isMuted = false
    var role: String?
    var currentUserId: UUID?
    var isLoading = false
    var isLoadingPosts = false
    var hasLoadedMentions = false
    var error: AppError?
    var currentPage = 1
    var hasMorePosts = true

    private let clubService = ClubService()
    let clubId: UUID

    init(clubId: UUID) {
        self.clubId = clubId
    }

    var isOwner: Bool { role == "owner" }
    var isOwnerOrAdmin: Bool {
        role == "owner" || role == "admin"
    }

    /// Accent color for this club, parsed from the stored theme hex.
    var accentColor: Color {
        ClubItem.color(fromHex: ClubItem.parseHex(club?.themeColor)) ?? Color.nook.clubDetailJoinedButton
    }

    /// Can the current user moderate (pin / delete any post)?
    var canModerate: Bool { isOwnerOrAdmin }

    /// Can the current user delete this specific post (own post, or moderator)?
    func canDeletePost(_ post: ClubPostModel) -> Bool {
        canModerate || post.userId == currentUserId
    }
    func canDeletePost(authorId: UUID?) -> Bool {
        canModerate || (authorId != nil && authorId == currentUserId)
    }

    /// Posts excluding those authored by blocked users.
    var visiblePosts: [ClubPostModel] {
        posts.filter { !blockedUserIds.contains($0.userId) }
    }

    var visibleMentions: [ClubPostModel] {
        mentions.filter { !blockedUserIds.contains($0.userId) }
    }

    var visibleMembers: [ClubMemberRow] {
        members.filter { !blockedUserIds.contains($0.userId) }
    }

    /// Pinned posts, shown first in the feed with a badge.
    var pinnedPosts: [ClubPostModel] {
        visiblePosts.filter { $0.isPinned }
    }

    /// Non-pinned posts.
    var feedPosts: [ClubPostModel] {
        visiblePosts.filter { !$0.isPinned }
    }

    /// Posts that carry a poll (for the Polls tab).
    var pollPosts: [ClubPostModel] {
        visiblePosts.filter { $0.poll != nil }
    }

    func loadClub() async {
        isLoading = true
        error = nil

        do {
            currentUserId = try? await supabase.auth.session.user.id
            async let clubResult = clubService.getClub(clubId: clubId)
            async let membershipResult = clubService.getMyMembership(clubId: clubId)
            async let membersResult = clubService.getMembers(clubId: clubId)

            club = try await clubResult
            let membership = try await membershipResult
            isMember = membership != nil
            role = membership?.role
            isMuted = membership?.notificationsMuted ?? false
            members = try await membersResult
            blockedUserIds = (try? await clubService.getBlockedUserIds()) ?? []
            isLoading = false

            await loadPosts(page: 1)
        } catch {
            self.error = AppError(from: error)
            isLoading = false
        }
    }

    func loadPosts(page: Int) async {
        isLoadingPosts = true
        do {
            let newPosts = try await clubService.getPosts(clubId: clubId, page: page)
            if page == 1 {
                posts = newPosts
                likedPostIds = (try? await clubService.getLikedPostIds(clubId: clubId)) ?? likedPostIds
            } else {
                posts.append(contentsOf: newPosts)
            }
            currentPage = page
            hasMorePosts = newPosts.count == 20
            isLoadingPosts = false
        } catch {
            self.error = AppError(from: error)
            isLoadingPosts = false
        }
    }

    func loadNextPage() {
        guard hasMorePosts, !isLoadingPosts else { return }
        Task {
            await loadPosts(page: currentPage + 1)
        }
    }

    func loadMentions() async {
        guard !hasLoadedMentions else { return }
        do {
            mentions = try await clubService.getMentions(clubId: clubId)
            hasLoadedMentions = true
        } catch {
            // Non-critical; leave mentions empty.
        }
    }

    func joinClub() async {
        do {
            try await clubService.joinClub(clubId: clubId)
            isMember = true
            role = "member"
            club = try? await clubService.getClub(clubId: clubId)
            members = (try? await clubService.getMembers(clubId: clubId)) ?? members
        } catch {
            self.error = AppError(from: error)
        }
    }

    func leaveClub() async {
        do {
            try await clubService.leaveClub(clubId: clubId)
            isMember = false
            role = nil
            club = try? await clubService.getClub(clubId: clubId)
            members = (try? await clubService.getMembers(clubId: clubId)) ?? members
        } catch {
            self.error = AppError(from: error)
        }
    }

    func createPost(body: String, imageDatas: [Data] = [], poll: ClubPollDraft? = nil) async {
        do {
            try await clubService.createPost(clubId: clubId, body: body, imageDatas: imageDatas, poll: poll)
            await loadPosts(page: 1)
        } catch {
            self.error = AppError(from: error)
        }
    }

    func isPostLiked(_ postId: UUID) -> Bool {
        likedPostIds.contains(postId)
    }

    /// Optimistically toggles a like — flips the heart AND adjusts the visible
    /// count immediately — then persists it.
    func toggleLike(postId: UUID) {
        let wasLiked = likedPostIds.contains(postId)
        if wasLiked {
            likedPostIds.remove(postId)
        } else {
            likedPostIds.insert(postId)
        }
        adjustLikeCount(postId: postId, delta: wasLiked ? -1 : 1)

        Task {
            do {
                if wasLiked {
                    try await clubService.unlikePost(postId: postId)
                } else {
                    try await clubService.likePost(postId: postId)
                }
            } catch {
                // Revert on failure.
                if wasLiked { likedPostIds.insert(postId) } else { likedPostIds.remove(postId) }
                adjustLikeCount(postId: postId, delta: wasLiked ? 1 : -1)
            }
        }
    }

    private func adjustLikeCount(postId: UUID, delta: Int) {
        if let i = posts.firstIndex(where: { $0.id == postId }) {
            posts[i].likesCount = max(posts[i].likesCount + delta, 0)
        }
        if let j = mentions.firstIndex(where: { $0.id == postId }) {
            mentions[j].likesCount = max(mentions[j].likesCount + delta, 0)
        }
    }

    // MARK: - Moderation

    func togglePin(postId: UUID) {
        guard let i = posts.firstIndex(where: { $0.id == postId }) else { return }
        let newValue = !posts[i].isPinned
        posts[i].isPinned = newValue
        Task {
            do {
                try await clubService.setPinned(postId: postId, pinned: newValue)
            } catch {
                if let k = posts.firstIndex(where: { $0.id == postId }) {
                    posts[k].isPinned = !newValue
                }
                self.error = AppError(from: error)
            }
        }
    }

    func deletePost(postId: UUID) {
        posts.removeAll { $0.id == postId }
        mentions.removeAll { $0.id == postId }
        Task {
            try? await clubService.deletePost(postId: postId)
        }
    }

    func isPinned(_ postId: UUID) -> Bool {
        posts.first { $0.id == postId }?.isPinned ?? false
    }

    // MARK: - Member management

    func setMemberRole(userId: UUID, role newRole: String) {
        if let i = members.firstIndex(where: { $0.userId == userId }) {
            let row = members[i]
            members[i] = ClubMemberRow(clubId: row.clubId, userId: row.userId, role: newRole, joinedAt: row.joinedAt, userProfile: row.userProfile)
        }
        Task {
            do {
                try await clubService.setMemberRole(clubId: clubId, userId: userId, role: newRole)
            } catch {
                members = (try? await clubService.getMembers(clubId: clubId)) ?? members
                self.error = AppError(from: error)
            }
        }
    }

    func removeMember(userId: UUID) {
        members.removeAll { $0.userId == userId }
        Task {
            do {
                try await clubService.removeMember(clubId: clubId, userId: userId)
                club = try? await clubService.getClub(clubId: clubId)
            } catch {
                members = (try? await clubService.getMembers(clubId: clubId)) ?? members
                self.error = AppError(from: error)
            }
        }
    }

    func toggleMute() {
        let newValue = !isMuted
        isMuted = newValue
        Task {
            try? await clubService.setMuted(clubId: clubId, muted: newValue)
        }
    }

    func blockUser(_ userId: UUID) {
        blockedUserIds.insert(userId)
        Task {
            try? await clubService.blockUser(userId: userId)
        }
    }

    func reportClub(reason: String?) {
        Task {
            try? await clubService.report(targetType: "club", targetId: clubId, reason: reason)
        }
    }
}
