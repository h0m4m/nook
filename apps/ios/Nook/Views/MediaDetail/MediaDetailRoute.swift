import SwiftUI

/// Lightweight navigation value for media detail.
/// Contains preview data from search results so the detail view can show
/// something immediately while the full detail loads.
struct MediaDetailRoute: Identifiable, Hashable {
    let id = UUID()
    let mediaId: String
    let source: String
    let mediaType: String

    // Preview data from search result (shown while loading)
    let title: String
    let imageURL: URL?
    let year: String?
    let score: Double?

    static func == (lhs: MediaDetailRoute, rhs: MediaDetailRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(from result: MediaSearchResult) {
        self.mediaId = result.mediaId
        self.source = result.source
        self.mediaType = result.mediaType
        self.title = result.title
        self.imageURL = result.imageURL
        self.year = result.year
        self.score = result.score
    }

    init(
        mediaId: String,
        source: String,
        mediaType: String,
        title: String,
        imageURL: URL? = nil,
        year: String? = nil,
        score: Double? = nil
    ) {
        self.mediaId = mediaId
        self.source = source
        self.mediaType = mediaType
        self.title = title
        self.imageURL = imageURL
        self.year = year
        self.score = score
    }
}
