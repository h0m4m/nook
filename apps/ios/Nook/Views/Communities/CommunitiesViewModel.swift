import Foundation
import SwiftUI

@MainActor
@Observable
final class CommunitiesViewModel {
    var myClubs: [ClubRow] = []
    var publicClubs: [ClubRow] = []
    var isLoading = false
    var error: AppError?

    private let clubService = ClubService()

    private var lastLoaded: Date?
    private let staleAfter: TimeInterval = 120

    private var isStale: Bool {
        guard let lastLoaded else { return true }
        return Date().timeIntervalSince(lastLoaded) > staleAfter
    }

    /// Called when the Clubs tab appears. Renders the existing lists instantly
    /// and only refetches when empty or stale, so returning to the tab doesn't
    /// flash a loading state.
    func loadIfNeeded() async {
        if myClubs.isEmpty && publicClubs.isEmpty {
            await loadClubs()
        } else if isStale {
            await refreshSilently()
        }
    }

    func loadClubs() async {
        isLoading = true
        error = nil

        do {
            async let myResult = clubService.getMyClubs()
            async let publicResult = clubService.getPublicClubs()

            myClubs = try await myResult
            publicClubs = try await publicResult
            lastLoaded = Date()
            prefetchBanners()
            isLoading = false
        } catch {
            self.error = AppError(from: error)
            isLoading = false
        }
    }

    /// Background refresh that keeps the current lists on screen (no loading flag).
    private func refreshSilently() async {
        async let myResult = try? clubService.getMyClubs()
        async let publicResult = try? clubService.getPublicClubs()
        if let my = await myResult { myClubs = my }
        if let pub = await publicResult { publicClubs = pub }
        lastLoaded = Date()
        prefetchBanners()
    }

    /// Warm club banner images so they don't load in late when cards appear.
    private func prefetchBanners() {
        ImagePrefetcher.prefetch(
            (myClubs + publicClubs).map { $0.bannerUrl.flatMap { URL(string: $0) } }
        )
    }

    func joinClub(clubId: UUID) async {
        do {
            try await clubService.joinClub(clubId: clubId)
            await loadClubs()
        } catch {
            self.error = AppError(from: error)
        }
    }

    func leaveClub(clubId: UUID) async {
        do {
            try await clubService.leaveClub(clubId: clubId)
            await loadClubs()
        } catch {
            self.error = AppError(from: error)
        }
    }

    func isMember(clubId: UUID) -> Bool {
        myClubs.contains { $0.id == clubId }
    }
}
