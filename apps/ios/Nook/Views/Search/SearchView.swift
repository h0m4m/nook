import SwiftUI

// MARK: - Search Media Category

enum SearchMediaCategory: String, CaseIterable, Identifiable {
    case movies = "movies"
    case tvShows = "tv_shows"
    case anime = "anime"
    case manga = "manga"
    case books = "books"
    case games = "games"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .movies: "Movies"
        case .tvShows: "TV Shows"
        case .anime: "Anime"
        case .manga: "Manga"
        case .books: "Books"
        case .games: "Games"
        }
    }

    var uppercaseLabel: String {
        switch self {
        case .movies: "MOVIE"
        case .tvShows: "TV SHOW"
        case .anime: "ANIME"
        case .manga: "MANGA"
        case .books: "BOOK"
        case .games: "VIDEOGAME"
        }
    }

    var dotColor: Color {
        switch self {
        case .movies: Color.nook.badgeMovieText
        case .tvShows: Color.nook.badgeTvShowText
        case .anime: Color.nook.badgeAnimeText
        case .manga: Color.nook.badgeMangaText
        case .books: Color.nook.badgeBookText
        case .games: Color.nook.badgeGameText
        }
    }

    var apiValue: String {
        switch self {
        case .movies: "movie"
        case .tvShows: "tv"
        case .anime: "anime"
        case .manga: "manga"
        case .books: "book"
        case .games: "game"
        }
    }

    var source: String {
        switch self {
        case .movies, .tvShows: "thetvdb"
        case .anime, .manga: "kitsu"
        case .books: "openlibrary"
        case .games: "igdb"
        }
    }

    static func from(apiMediaType: String) -> SearchMediaCategory? {
        switch apiMediaType {
        case "movie": .movies
        case "tv": .tvShows
        case "anime": .anime
        case "manga": .manga
        case "book": .books
        case "game": .games
        default: nil
        }
    }
}

// MARK: - Search Result Model

struct SearchResultItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let category: SearchMediaCategory
    let year: String
    let rating: Double
    let genres: String
    let imageName: String
    let placeholderColor: Color?
    let totalEpisodes: Int

    // Tracking state — populated when user interacts with tracking sheet
    var selectedStatus: TrackingStatus?
    var currentEpisode: Int = 0
    var userScore: Int?

    var isTracked: Bool {
        selectedStatus != nil || currentEpisode > 0 || userScore != nil
    }

    init(
        title: String,
        category: SearchMediaCategory,
        year: String,
        rating: Double,
        genres: String,
        imageName: String,
        placeholderColor: Color? = nil,
        totalEpisodes: Int = 0,
        selectedStatus: TrackingStatus? = nil,
        currentEpisode: Int = 0,
        userScore: Int? = nil
    ) {
        self.title = title
        self.category = category
        self.year = year
        self.rating = rating
        self.genres = genres
        self.imageName = imageName
        self.placeholderColor = placeholderColor
        self.totalEpisodes = totalEpisodes
        self.selectedStatus = selectedStatus
        self.currentEpisode = currentEpisode
        self.userScore = userScore
    }
}

// MARK: - Search State
// Defined in TrackMediaSheet.swift (shared)

// MARK: - Search View

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var userInterests: [SearchMediaCategory] = SearchMediaCategory.allCases
    @State private var trackingItemID: UUID?
    @State private var sheetStatus: TrackingStatus?
    @State private var sheetEpisode: Int = 0
    @State private var sheetScore: Int?
    @State private var sheetIsTracking = false
    @State private var sheetIsRated = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.trackingState) private var trackingState

    var body: some View {
        scrollContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.nook.searchBackground)
            .modifier(
                SearchTopBar(
                    searchText: $viewModel.searchText,
                    selectedFilter: viewModel.selectedFilter,
                    isSearchFocused: $isSearchFocused
                )
            )
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.search()
            }
            .onChange(of: viewModel.selectedFilter) { _, _ in
                if !viewModel.searchText.isEmpty {
                    viewModel.search()
                }
            }
            .task {
                await loadUserInterests()
            }
            .sheet(isPresented: Binding(
                get: { trackingItemID != nil },
                set: { if !$0 { persistSearchTracking(); trackingItemID = nil } }
            )) {
                if let item = findTrackingItem() {
                    TrackingSheetView(
                        mediaTitle: item.title,
                        totalEpisodes: 0,
                        category: LibraryMediaCategory.from(apiMediaType: item.mediaType),
                        selectedStatus: $sheetStatus,
                        currentEpisode: $sheetEpisode,
                        userScore: $sheetScore,
                        isTracking: $sheetIsTracking,
                        isRated: $sheetIsRated
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.nook.detailBackground)
                }
            }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterChips

                switch viewModel.searchState {
                case .idle:
                    idleContent
                case .loading:
                    loadingContent
                case .results:
                    resultsContent
                case .noResults:
                    noResultsContent
                }
            }
            .padding(.bottom, 100)
        }
        .modifier(SoftScrollEdge())
    }

    // MARK: - Idle (Recent Searches)

    private var idleContent: some View {
        SearchEmptyState(
            icon: "magnifying-glass-bold",
            title: "Search for anything",
            subtitle: "Find movies, shows, anime, books, and manga"
        )
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 24) {
            ForEach(0..<4, id: \.self) { _ in
                SearchShimmerRow()
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Results

    private var resultsContent: some View {
        Group {
            let results = viewModel.results

            HStack(spacing: 0) {
                sectionHeader("\(results.count) RESULT\(results.count == 1 ? "" : "S")")
                Spacer()
            }

            LazyVStack(spacing: 24) {
                ForEach(results) { item in
                    NavigationLink(value: MediaDetailRoute(from: item)) {
                        APISearchResultRow(
                            item: item,
                            isTracked: viewModel.trackedMediaIds.contains(item.mediaId)
                                || trackingState.trackedMediaIds.contains(item.mediaId)
                        ) {
                            openTrackingSheet(for: item)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .onAppear {
                        if item.id == results.last?.id {
                            viewModel.loadNextPage()
                        }
                    }
                }
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }
        }
    }

    // MARK: - No Results

    private var noResultsContent: some View {
        SearchEmptyState(
            icon: "magnifying-glass-bold",
            title: "No results found",
            subtitle: viewModel.selectedFilter != nil
                ? "Try removing the \(viewModel.selectedFilter!.label) filter or searching for something else"
                : "Try a different search term"
        )
    }

    // MARK: - Shared Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(NookFont.tabLabel)
            .tracking(1)
            .foregroundStyle(Color.nook.searchSectionLabel)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(userInterests) { category in
                    filterChip(
                        label: category.label,
                        dotColor: category.dotColor,
                        isSelected: viewModel.selectedFilter == category
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewModel.selectedFilter = category
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private func filterChip(
        label: String,
        dotColor: Color? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                HStack(spacing: 6) {
                    if let dotColor, !isSelected {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(label)
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .padding(.horizontal, isSelected && dotColor == nil ? 22.5 : 20)
                .frame(height: 38)
                .background(
                    isSelected ? Color.nook.searchFilterSelected : .white,
                    in: Capsule()
                )
                .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: action) {
                HStack(spacing: 6) {
                    if let dotColor, !isSelected {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(label)
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isSelected ? .white : Color.nook.searchFilterText)
                }
                .padding(.horizontal, isSelected && dotColor == nil ? 22.5 : 20)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.nook.searchFilterSelected : Color.white)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : Color.nook.searchFilterBorder,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tracking Sheet

    private func openTrackingSheet(for item: MediaSearchResult) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        sheetStatus = nil
        sheetEpisode = 0
        sheetScore = nil
        sheetIsTracking = false
        sheetIsRated = false
        trackingItemID = item.id

        generator.impactOccurred()
    }

    private func persistSearchTracking() {
        guard sheetIsTracking,
              let status = sheetStatus,
              let item = findTrackingItem() else { return }

        // Mark as tracked immediately so the button updates
        viewModel.trackedMediaIds.insert(item.mediaId)

        Task {
            guard let userId = try? await supabase.auth.session.user.id else { return }

            // Ensure media_item exists in DB by calling media-detail Edge Function
            let mediaAPI = MediaAPIService()
            let detail = try? await mediaAPI.detail(
                source: item.source,
                sourceId: item.mediaId,
                mediaType: item.mediaType
            )

            guard let dbId = detail?.dbId else { return }

            let trackingService = TrackingService()
            try? await trackingService.track(
                userId: userId,
                mediaItemId: dbId,
                status: status.dbValue,
                progress: sheetEpisode,
                score: sheetScore.map { Double($0) }
            )
        }
    }

    private func findTrackingItem() -> MediaSearchResult? {
        guard let id = trackingItemID else { return nil }
        return viewModel.results.first { $0.id == id }
    }

    private func loadUserInterests() async {
        guard let user = try? await supabase.auth.session.user else { return }
        let userId = user.id

        struct ProfileRow: Decodable {
            let interests: [String]?
        }

        do {
            let row: ProfileRow = try await supabase
                .from("user_profiles")
                .select("interests")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            if let interests = row.interests {
                let filtered = SearchMediaCategory.allCases.filter {
                    interests.contains($0.rawValue)
                }
                if !filtered.isEmpty {
                    userInterests = filtered
                }
            }
            // Default to first interest if no filter selected yet
            if viewModel.selectedFilter == nil {
                viewModel.selectedFilter = userInterests.first
            }
        } catch {
            // Keep the default (all categories)
            if viewModel.selectedFilter == nil {
                viewModel.selectedFilter = userInterests.first
            }
        }
    }
}

// MARK: - Top bar

private struct SearchTopBar: ViewModifier {
    @Binding var searchText: String
    var selectedFilter: SearchMediaCategory?
    var isSearchFocused: FocusState<Bool>.Binding

    private var placeholder: String {
        if let filter = selectedFilter {
            "Search \(filter.label)..."
        } else {
            "Search movies, books, games..."
        }
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                searchBarContent
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                searchBarContent
                    .background(Color.nook.searchBackground)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    private var searchBarContent: some View {
        HStack(spacing: 12) {
            Image("magnifying-glass-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.searchBarPlaceholder)

            TextField(
                placeholder,
                text: $searchText,
                prompt: Text(placeholder)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.searchBarPlaceholder)
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.searchBarText)
            .focused(isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.nook.searchBarPlaceholder)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .modifier(SearchBarBackground())
        .padding(.horizontal, 24)
    }
}

// MARK: - Empty State

struct SearchEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundStyle(Color.nook.searchEmptyIcon)

            Text(title)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.searchBarText)

            Text(subtitle)
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.searchEmptyText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - Shimmer Row

struct SearchShimmerRow: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            // Poster placeholder
            RoundedRectangle(cornerRadius: 17.78, style: .continuous)
                .fill(Color.nook.searchShimmerBase)
                .frame(width: 64, height: 80)

            VStack(alignment: .leading, spacing: 8) {
                // Category + year
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.nook.searchShimmerBase)
                    .frame(width: 90, height: 10)

                // Title
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.nook.searchShimmerBase)
                    .frame(width: 160, height: 14)

                // Rating + genres
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.nook.searchShimmerBase)
                    .frame(width: 120, height: 10)
            }

            Spacer()

            // Button placeholder
            Circle()
                .fill(Color.nook.searchShimmerBase)
                .frame(width: 40, height: 40)
        }
        .frame(height: 80)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(
            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear { isAnimating = true }
    }
}

// MARK: - Search bar background

struct SearchBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background(.white, in: Capsule())
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(Color.nook.searchBarBackground)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Scroll edge blur (iOS 26+)

struct SoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - API Search Result Row (uses MediaSearchResult from real API)

struct APISearchResultRow: View {
    let item: MediaSearchResult
    var isTracked: Bool = false
    let onTapAction: () -> Void

    private var category: SearchMediaCategory? {
        SearchMediaCategory.from(apiMediaType: item.mediaType)
    }

    var body: some View {
        HStack(spacing: 16) {
            MediaPosterImage(
                url: item.imageURL,
                width: 64,
                height: 80,
                fallbackColor: category?.dotColor.opacity(0.3) ?? Color.nook.searchShimmerBase
            )
            .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -0.5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    if let cat = category {
                        Text(cat.uppercaseLabel)
                            .font(NookFont.tabLabel)
                            .tracking(0.5)
                            .foregroundStyle(cat.dotColor)
                    }

                    if item.year != nil {
                        Circle()
                            .fill(Color.nook.searchSectionLabel)
                            .frame(width: 3, height: 3)

                        Text(item.year ?? "")
                            .font(NookFont.tabLabel)
                            .tracking(0.5)
                            .foregroundStyle(Color.nook.searchSectionLabel)
                    }
                }

                Text(item.title)
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.searchBarText)
                    .lineLimit(1)

                if let score = item.score {
                    HStack(spacing: 6) {
                        Image("star-fill")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundStyle(Color.nook.reviewRating)

                        Text(String(format: "%.1f", score))
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.reviewRating)
                    }
                }
            }

            Spacer(minLength: 8)

            addButton
        }
        .frame(height: 80)
    }

    @ViewBuilder
    private var addButton: some View {
        let icon = isTracked ? "pencil-simple-line-fill" : "plus-bold"
        let bgColor = isTracked ? Color.nook.searchAddedButton : Color.nook.searchAddButton

        if #available(iOS 26, *) {
            Button(action: onTapAction) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isTracked ? Color.white : Color.primary)
                    .frame(width: 40, height: 40)
                    .background(bgColor, in: Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onTapAction) {
                Circle()
                    .fill(bgColor)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(isTracked ? Color.white : Color.nook.searchAddedButton)
                    }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview("Idle") {
    SearchView()
}
