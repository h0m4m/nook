import Foundation
import SwiftUI
import Supabase

@MainActor
@Observable
final class ClubDetailViewModel {
    var club: ClubRow?
    var posts: [ClubPostModel] = []
    var members: [ClubMemberRow] = []
    var isMember = false
    var isLoading = false
    var isLoadingPosts = false
    var error: AppError?
    var currentPage = 1
    var hasMorePosts = true

    private let clubService = ClubService()
    private let clubId: UUID

    init(clubId: UUID) {
        self.clubId = clubId
    }

    func loadClub() async {
        isLoading = true
        error = nil

        do {
            async let clubResult = clubService.getClub(clubId: clubId)
            async let memberResult = clubService.isMember(clubId: clubId)
            async let membersResult = clubService.getMembers(clubId: clubId)

            club = try await clubResult
            isMember = try await memberResult
            members = try await membersResult
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

    func joinClub() async {
        do {
            try await clubService.joinClub(clubId: clubId)
            isMember = true
            // Refresh club to get updated member count
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
            club = try? await clubService.getClub(clubId: clubId)
            members = (try? await clubService.getMembers(clubId: clubId)) ?? members
        } catch {
            self.error = AppError(from: error)
        }
    }

    func createPost(body: String) async {
        do {
            try await clubService.createPost(clubId: clubId, body: body)
            await loadPosts(page: 1)
        } catch {
            self.error = AppError(from: error)
        }
    }

    func likePost(postId: UUID) async {
        do {
            try await clubService.likePost(postId: postId)
        } catch {
            // Silently fail for optimistic likes
        }
    }

    func unlikePost(postId: UUID) async {
        do {
            try await clubService.unlikePost(postId: postId)
        } catch {
            // Silently fail
        }
    }
}
