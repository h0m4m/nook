import SwiftUI

/// Wrapper that loads media detail from the API and passes it to MediaDetailView.
/// Used when navigating from search results via MediaDetailRoute.
struct MediaDetailLoadingView: View {
    @State private var viewModel: MediaDetailViewModel
    @Environment(\.trackingState) private var trackingState

    init(route: MediaDetailRoute) {
        self._viewModel = State(initialValue: MediaDetailViewModel(route: route))
    }

    var body: some View {
        // Always render MediaDetailView immediately using whatever data is available.
        // This avoids a view swap (and scroll reset) when the detail finishes loading.
        MediaDetailView(
            media: makeMediaDetail(),
            isLoading: viewModel.isLoading,
            onTracked: {
                trackingState.markTracked(viewModel.route.mediaId)
            },
            resolvedDbId: viewModel.dbId
        )
        .task {
            await viewModel.loadDetail()
        }
    }

    private func makeMediaDetail() -> MediaDetail {
        MediaDetail(
            title: viewModel.title,
            year: viewModel.year ?? "",
            genres: viewModel.genresSubtext,
            genresFull: viewModel.genres,
            episodeCount: viewModel.episodeCountDisplay,
            category: viewModel.category ?? .movie,
            rating: viewModel.score ?? 0,
            ratingCount: viewModel.scoreCount.map { "\($0)" } ?? "",
            imageName: "",
            imageURL: viewModel.imageURL,
            synopsis: viewModel.synopsis,
            studio: viewModel.studioDisplay,
            director: viewModel.directorDisplay,
            status: viewModel.status ?? "",
            airedDates: viewModel.airedDatesDisplay,
            currentEpisode: 0,
            totalEpisodes: viewModel.maxProgress ?? 0,
            trackingStatus: nil,
            reviews: [],
            dbId: viewModel.dbId
        )
    }
}
