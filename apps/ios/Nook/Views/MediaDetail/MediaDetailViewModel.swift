import Foundation
import SwiftUI

@MainActor
@Observable
final class MediaDetailViewModel {
    // Input (from route)
    let route: MediaDetailRoute

    // Loaded state
    var detail: APIMediaDetail?
    var dbId: UUID?
    var isLoading = true
    var error: AppError?

    // Derived display properties (populated from detail or route preview)
    var title: String { detail?.title ?? route.title }
    var imageURL: URL? { detail?.imageUrl.flatMap { URL(string: $0) } ?? route.imageURL }
    var year: String? { extractYear() }
    var score: Double? { detail?.score ?? route.score }
    var scoreCount: Int? { detail?.scoreCount }
    var synopsis: String { detail?.synopsis ?? "" }
    var genres: String { detail?.genres.joined(separator: ", ") ?? "" }
    var genresList: [String] { detail?.genres ?? [] }
    var maxProgress: Int? { detail?.maxProgress }
    var sourceUrl: String? { detail?.sourceUrl }

    var category: LibraryMediaCategory? {
        switch route.mediaType {
        case "movie": .movie
        case "tv": .tvShow
        case "anime": .anime
        case "manga": .manga
        case "book": .book
        default: nil
        }
    }

    // Detail fields
    var format: String? { detail?.details["format"]?.stringValue }
    var status: String? { detail?.details["status"]?.stringValue }
    var runtime: String? { detail?.details["runtime"]?.stringValue }
    var director: String? { detail?.details["director"]?.stringValue }
    var network: String? { detail?.details["network"]?.stringValue }
    var episodeCount: Int? { detail?.details["episodes"]?.intValue }
    var chapterCount: Int? { detail?.details["chapters"]?.intValue }
    var pageCount: Int? { detail?.details["pages"]?.intValue }
    var seasonCount: Int? { detail?.details["seasons"]?.intValue }
    var releaseDate: String? {
        detail?.details["release_date"]?.stringValue
            ?? detail?.details["first_air_date"]?.stringValue
            ?? detail?.details["start_date"]?.stringValue
            ?? detail?.details["publish_date"]?.stringValue
    }
    var endDate: String? {
        detail?.details["end_date"]?.stringValue
    }
    var studios: [String]? {
        detail?.details["studios"]?.stringArrayValue
    }
    var authors: [String]? {
        detail?.details["authors"]?.stringArrayValue
    }
    var publishers: [String]? {
        detail?.details["publishers"]?.stringArrayValue
    }
    var sourceMaterial: String? {
        detail?.details["source_material"]?.stringValue
    }
    var platforms: [String]? {
        detail?.details["platforms"]?.stringArrayValue
    }
    var companies: String? {
        detail?.details["companies"]?.stringValue
    }

    // Studio/creator display (unified across types)
    var studioDisplay: String {
        if let studios, !studios.isEmpty { return studios.joined(separator: ", ") }
        if let authors, !authors.isEmpty { return authors.joined(separator: ", ") }
        if let publishers, !publishers.isEmpty { return publishers.joined(separator: ", ") }
        if let companies { return companies }
        if let network { return network }
        return ""
    }

    var directorDisplay: String {
        director ?? ""
    }

    var episodeCountDisplay: String {
        if let eps = episodeCount, eps > 0 { return "\(eps) episodes" }
        if let ch = chapterCount, ch > 0 { return "\(ch) chapters" }
        if let pg = pageCount, pg > 0 { return "\(pg) pages" }
        return ""
    }

    var airedDatesDisplay: String {
        guard let start = releaseDate else { return "" }
        if let end = endDate {
            return "\(start) — \(end)"
        }
        return start
    }

    // Related/recommendations
    var recommendations: [MediaSearchResult] {
        guard let recs = detail?.related?.recommendations else { return [] }
        return recs.map { MediaSearchResult(from: $0) }
    }

    private let mediaAPI: MediaAPIService

    init(route: MediaDetailRoute, mediaAPI: MediaAPIService = MediaAPIService()) {
        self.route = route
        self.mediaAPI = mediaAPI
    }

    func loadDetail() async {
        isLoading = true
        error = nil

        do {
            let result = try await mediaAPI.detail(
                source: route.source,
                sourceId: route.mediaId,
                mediaType: route.mediaType
            )
            detail = result
            dbId = result.dbId
            isLoading = false
        } catch {
            self.error = AppError(from: error)
            isLoading = false
        }
    }

    private func extractYear() -> String? {
        if let detail {
            // Try to extract from detail fields
            if let rd = detail.details["release_date"]?.stringValue, rd.count >= 4 {
                return String(rd.prefix(4))
            }
            if let rd = detail.details["first_air_date"]?.stringValue, rd.count >= 4 {
                return String(rd.prefix(4))
            }
            if let rd = detail.details["start_date"]?.stringValue, rd.count >= 4 {
                return String(rd.prefix(4))
            }
            if let rd = detail.details["publish_date"]?.stringValue, rd.count >= 4 {
                return String(rd.prefix(4))
            }
        }
        return route.year
    }
}
