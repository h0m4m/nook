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

    func loadClubs() async {
        isLoading = true
        error = nil

        do {
            async let myResult = clubService.getMyClubs()
            async let publicResult = clubService.getPublicClubs()

            myClubs = try await myResult
            publicClubs = try await publicResult
            isLoading = false
        } catch {
            self.error = AppError(from: error)
            isLoading = false
        }
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
