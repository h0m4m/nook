import Foundation
import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    var results: [MediaSearchResult] = []
    var searchState: SearchState = .idle
    var searchText: String = ""
    var selectedFilter: SearchMediaCategory? = nil
    var currentPage: Int = 1
    var hasMorePages: Bool = false
    var error: AppError?
    /// mediaIds that the user has tracked during this session
    var trackedMediaIds: Set<String> = []

    private let mediaAPI: MediaAPIService
    private var searchTask: Task<Void, Never>?

    init(mediaAPI: MediaAPIService = MediaAPIService()) {
        self.mediaAPI = mediaAPI
    }

    func search() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            withAnimation(.easeOut(duration: 0.2)) {
                searchState = .idle
                results = []
            }
            return
        }

        withAnimation(.easeOut(duration: 0.15)) {
            searchState = .loading
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            await performSearch(query: query, page: 1)
        }
    }

    func loadNextPage() {
        guard hasMorePages else { return }
        guard searchTask == nil || searchTask!.isCancelled else { return }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let nextPage = currentPage + 1
        searchTask = Task {
            await performSearch(query: query, page: nextPage, append: true)
        }
    }

    private func performSearch(query: String, page: Int, append: Bool = false) async {
        guard let filter = selectedFilter else { return }
        let mediaType = filter.apiValue

        do {
            let response = try await mediaAPI.search(
                query: query,
                mediaType: mediaType,
                page: page
            )
            guard !Task.isCancelled else { return }

            let mapped = response.results.map { MediaSearchResult(from: $0) }

            withAnimation(.easeOut(duration: 0.25)) {
                if append {
                    results.append(contentsOf: mapped)
                } else {
                    results = mapped
                }
                currentPage = response.page
                hasMorePages = response.page < response.totalPages
                searchState = results.isEmpty ? .noResults : .results
                error = nil
            }
        } catch {
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.error = AppError(from: error)
                if !append {
                    searchState = .noResults
                }
            }
        }
    }
}
