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

    var isOwnerOrAdmin: Bool {
        role == "owner" || role == "admin"
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

    var pinnedPost: ClubPostModel? {
        visiblePosts.first { $0.isPinned }
    }

    /// Non-pinned posts (the pinned one is shown separately as a highlight card).
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

    /// Optimistically toggles a like and persists it.
    func toggleLike(postId: UUID) {
        let wasLiked = likedPostIds.contains(postId)
        if wasLiked {
            likedPostIds.remove(postId)
        } else {
            likedPostIds.insert(postId)
        }
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
