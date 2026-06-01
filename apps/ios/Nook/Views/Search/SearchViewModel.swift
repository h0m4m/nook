import Foundation
import SwiftUI

// MARK: - Search History Item

struct SearchHistoryItem: Codable, Identifiable, Equatable {
    var id: String { query + ":" + (filter ?? "") }
    let query: String
    let filter: String?
    let timestamp: Date

    var filterCategory: SearchMediaCategory? {
        guard let filter else { return nil }
        return SearchMediaCategory(rawValue: filter)
    }
}

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
    /// Recent search history
    var recentSearches: [SearchHistoryItem] = []

    private let mediaAPI: MediaAPIService
    private var searchTask: Task<Void, Never>?

    private static let historyKey = "search_history"
    private static let maxHistoryItems = 15

    init(mediaAPI: MediaAPIService = MediaAPIService()) {
        self.mediaAPI = mediaAPI
        loadHistory()
    }

    // MARK: - History

    func saveToHistory() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let item = SearchHistoryItem(
            query: query,
            filter: selectedFilter?.rawValue,
            timestamp: Date()
        )

        // Remove duplicate if exists
        recentSearches.removeAll { $0.id == item.id }
        // Insert at front
        recentSearches.insert(item, at: 0)
        // Cap size
        if recentSearches.count > Self.maxHistoryItems {
            recentSearches = Array(recentSearches.prefix(Self.maxHistoryItems))
        }
        persistHistory()
    }

    func removeFromHistory(_ item: SearchHistoryItem) {
        recentSearches.removeAll { $0.id == item.id }
        persistHistory()
    }

    func clearHistory() {
        recentSearches.removeAll()
        persistHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyKey),
              let items = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) else { return }
        recentSearches = items
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(recentSearches) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyKey)
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
