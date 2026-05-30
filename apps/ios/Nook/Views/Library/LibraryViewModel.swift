import Foundation
import SwiftUI
import Supabase

@MainActor
@Observable
final class LibraryViewModel {
    var items: [TrackedMediaItem] = []
    var selectedFilter: LibraryFilter = .all
    var selectedSort: LibrarySortOption = .lastUpdated
    var searchText: String = ""
    var isLoading = false
    var error: AppError?

    private let trackingService = TrackingService()

    var filteredItems: [TrackedMediaItem] {
        var results = items

        switch selectedFilter {
        case .all: break
        case .inProgress:
            results = results.filter { $0.status == "in_progress" }
        case .planned:
            results = results.filter { $0.status == "planned" }
        case .onHold:
            results = results.filter { $0.status == "on_hold" }
        case .dropped:
            results = results.filter { $0.status == "dropped" }
        case .completed:
            results = results.filter { $0.status == "completed" }
        }

        if !searchText.isEmpty {
            results = results.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        return results
    }

    func loadLibrary() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        isLoading = true
        error = nil

        do {
            items = try await trackingService.getLibrary(userId: userId)
            isLoading = false
        } catch {
            self.error = AppError(from: error)
            isLoading = false
        }
    }

    func trackMedia(
        mediaItemId: UUID,
        status: TrackingStatus,
        progress: Int = 0,
        score: Double? = nil
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            try await trackingService.track(
                userId: userId,
                mediaItemId: mediaItemId,
                status: status.dbValue,
                progress: progress,
                score: score
            )
            await loadLibrary()
        } catch {
            self.error = AppError(from: error)
        }
    }

    func updateTracking(
        trackingId: UUID,
        status: TrackingStatus?,
        progress: Int?,
        score: Double?
    ) async {
        do {
            try await trackingService.updateTracking(
                trackingId: trackingId,
                status: status?.dbValue,
                progress: progress,
                score: score
            )
            await loadLibrary()
        } catch {
            self.error = AppError(from: error)
        }
    }

    func removeTracking(trackingId: UUID) async {
        do {
            try await trackingService.removeTracking(trackingId: trackingId)
            await loadLibrary()
        } catch {
            self.error = AppError(from: error)
        }
    }
}
