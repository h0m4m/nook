import SwiftUI

/// Wrapper that loads media detail from the API and passes it to MediaDetailView.
/// Used when navigating from search results via MediaDetailRoute.
struct MediaDetailLoadingView: View {
    @State private var viewModel: MediaDetailViewModel

    init(route: MediaDetailRoute) {
        self._viewModel = State(initialValue: MediaDetailViewModel(route: route))
    }

    var body: some View {
        Group {
            if viewModel.detail != nil {
                MediaDetailView(media: makeMediaDetail())
            } else if viewModel.isLoading {
                loadingState
            } else if let error = viewModel.error {
                errorState(error)
            }
        }
        .task {
            await viewModel.loadDetail()
        }
    }

    private func makeMediaDetail() -> MediaDetail {
        MediaDetail(
            title: viewModel.title,
            year: viewModel.year ?? "",
            genres: viewModel.genres,
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
            reviews: []
        )
    }

    private var loadingState: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero placeholder with preview image
                    Group {
                        if let url = viewModel.route.imageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Color.nook.foreground
                                }
                            }
                        } else {
                            Color.nook.foreground
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 321)
                    .clipped()

                    // Content skeleton
                    VStack(alignment: .leading, spacing: 16) {
                        Text(viewModel.route.title)
                            .font(NookFont.headingSmall)
                            .foregroundStyle(Color.nook.detailTitle)

                        // Shimmer lines
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.nook.searchShimmerBase)
                                .frame(height: 14)
                                .opacity(0.6)
                        }
                    }
                    .padding(24)
                }
            }
            .ignoresSafeArea(edges: [.top, .bottom])
        }
        .background(Color.nook.detailBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func errorState(_ error: AppError) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.nook.searchSectionLabel)

            Text(error.localizedDescription)
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.searchSectionLabel)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.loadDetail() }
            } label: {
                Text("Retry")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 40)
                    .background(Color.nook.primary, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
        .background(Color.nook.detailBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}
