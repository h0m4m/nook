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

}

// MARK: - Search Result Model

struct SearchResultItem: Identifiable {
    let id = UUID()
    let title: String
    let category: SearchMediaCategory
    let year: String
    let rating: Double
    let genres: String
    let imageName: String
    let placeholderColor: Color?
    var isAdded: Bool

    init(
        title: String,
        category: SearchMediaCategory,
        year: String,
        rating: Double,
        genres: String,
        imageName: String,
        placeholderColor: Color? = nil,
        isAdded: Bool = false
    ) {
        self.title = title
        self.category = category
        self.year = year
        self.rating = rating
        self.genres = genres
        self.imageName = imageName
        self.placeholderColor = placeholderColor
        self.isAdded = isAdded
    }
}

// MARK: - Search State

private enum SearchState: Equatable {
    case idle
    case loading
    case results
    case noResults
}

// MARK: - Search View

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedFilter: SearchMediaCategory? = nil
    @State private var recentSearches: [SearchResultItem] = SearchView.mockRecentSearches
    @State private var searchResults: [SearchResultItem] = []
    @State private var userInterests: [SearchMediaCategory] = []
    @State private var searchState: SearchState = .idle
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private var displayedResults: [SearchResultItem] {
        switch searchState {
        case .idle:
            var results = recentSearches
            if let filter = selectedFilter {
                results = results.filter { $0.category == filter }
            }
            return results
        case .results:
            var results = searchResults
            if let filter = selectedFilter {
                results = results.filter { $0.category == filter }
            }
            return results
        case .loading, .noResults:
            return []
        }
    }

    var body: some View {
        scrollContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.nook.searchBackground)
            .modifier(
                SearchTopBar(
                    searchText: $searchText,
                    selectedFilter: selectedFilter,
                    isSearchFocused: $isSearchFocused
                )
            )
            .onChange(of: searchText) { _, newValue in
                handleSearchTextChange(newValue)
            }
            .onChange(of: selectedFilter) { _, _ in
                // Re-trigger search with current text when filter changes
                if !searchText.isEmpty {
                    handleSearchTextChange(searchText)
                }
            }
            .task {
                await loadUserInterests()
            }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterChips

                switch searchState {
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
        Group {
            if !recentSearches.isEmpty {
                sectionHeader("RECENT SEARCHES")

                ForEach(Array(displayedResults.enumerated()), id: \.element.id) { index, item in
                    SearchResultRow(item: item) {
                        toggleAdded(for: item, in: &recentSearches)
                    }
                    .padding(.horizontal, 24)

                    if index < displayedResults.count - 1 {
                        Spacer().frame(height: 24)
                    }
                }
            } else {
                SearchEmptyState(
                    icon: "magnifying-glass-bold",
                    title: "Search for anything",
                    subtitle: "Find movies, shows, anime, books, manga, and games"
                )
            }
        }
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
            let results = displayedResults

            HStack(spacing: 0) {
                sectionHeader("\(results.count) RESULT\(results.count == 1 ? "" : "S")")
                Spacer()
            }

            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                SearchResultRow(item: item) {
                    toggleAdded(for: item, in: &searchResults)
                }
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                if index < results.count - 1 {
                    Spacer().frame(height: 24)
                }
            }
        }
    }

    // MARK: - No Results

    private var noResultsContent: some View {
        SearchEmptyState(
            icon: "magnifying-glass-bold",
            title: "No results found",
            subtitle: selectedFilter != nil
                ? "Try removing the \(selectedFilter!.label) filter or searching for something else"
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
                filterChip(label: "All", isSelected: selectedFilter == nil) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedFilter = nil
                    }
                }

                ForEach(userInterests) { category in
                    filterChip(
                        label: category.label,
                        dotColor: category.dotColor,
                        isSelected: selectedFilter == category
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedFilter = category
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

    // MARK: - Search Logic

    private func handleSearchTextChange(_ text: String) {
        searchTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                searchState = .idle
                searchResults = []
            }
            return
        }

        withAnimation(.easeOut(duration: 0.15)) {
            searchState = .loading
        }

        searchTask = Task {
            // Debounce — wait 400ms before firing
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            await performSearch(query: trimmed)
        }
    }

    private func performSearch(query: String) async {
        // TODO: Replace with real Supabase search once the media catalog exists.
        // For now, filter the mock data set to simulate live results.
        let allMock = SearchView.mockAllMedia
        let lowerQuery = query.lowercased()

        let matched = allMock.filter { item in
            item.title.lowercased().contains(lowerQuery)
                || item.genres.lowercased().contains(lowerQuery)
                || item.category.label.lowercased().contains(lowerQuery)
        }

        // Simulate network latency
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                searchResults = matched
                searchState = matched.isEmpty ? .noResults : .results
            }
        }
    }

    // MARK: - Actions

    private func toggleAdded(for item: SearchResultItem, in list: inout [SearchResultItem]) {
        guard let index = list.firstIndex(where: { $0.id == item.id }) else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            list[index].isAdded.toggle()
        }
        generator.impactOccurred()
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
                userInterests = SearchMediaCategory.allCases.filter {
                    interests.contains($0.rawValue)
                }
            }
        } catch {
            userInterests = SearchMediaCategory.allCases
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

private struct SearchEmptyState: View {
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

private struct SearchShimmerRow: View {
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

private struct SearchBarBackground: ViewModifier {
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

private struct SoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let item: SearchResultItem
    let onToggleAdded: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            posterImage

            VStack(alignment: .leading, spacing: 4) {
                categoryAndYear
                titleText
                ratingAndGenres
            }

            Spacer(minLength: 8)

            addButton
        }
        .frame(height: 80)
    }

    private var posterImage: some View {
        Group {
            if let color = item.placeholderColor {
                color
            } else {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 64, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 17.78, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -0.5)
    }

    private var categoryAndYear: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(item.category.uppercaseLabel)
                .font(NookFont.tabLabel)
                .tracking(0.5)
                .foregroundStyle(item.category.dotColor)

            Circle()
                .fill(Color.nook.searchSectionLabel)
                .frame(width: 3, height: 3)

            Text(item.year)
                .font(NookFont.tabLabel)
                .tracking(0.5)
                .foregroundStyle(Color.nook.searchSectionLabel)
        }
    }

    private var titleText: some View {
        Text(item.title)
            .font(NookFont.labelBold)
            .foregroundStyle(Color.nook.searchBarText)
            .lineLimit(1)
    }

    private var ratingAndGenres: some View {
        HStack(spacing: 6) {
            Image("star-fill")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12, height: 12)
                .foregroundStyle(Color.nook.reviewRating)

            Text(String(format: "%.1f", item.rating))
                .font(NookFont.captionBold)
                .foregroundStyle(Color.nook.reviewRating)

            Text(item.genres)
                .font(NookFont.caption.italic())
                .foregroundStyle(Color.nook.searchSectionLabel)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if #available(iOS 26, *) {
            glassAddButton
        } else {
            classicAddButton
        }
    }

    @available(iOS 26, *)
    private var glassAddButton: some View {
        Button(action: onToggleAdded) {
            Group {
                if item.isAdded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image("plus-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 40, height: 40)
            .background(item.isAdded ? Color.nook.searchAddedButton : .white, in: Circle())
            .glassEffect(
                item.isAdded ? .regular : .regular.interactive(),
                in: .circle
            )
        }
        .buttonStyle(.plain)
    }

    private var classicAddButton: some View {
        Button(action: onToggleAdded) {
            Circle()
                .fill(item.isAdded ? Color.nook.searchAddedButton : Color.nook.searchAddButton)
                .frame(width: 40, height: 40)
                .overlay {
                    if item.isAdded {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image("plus-bold")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Color.nook.searchAddedButton)
                    }
                }
                .shadow(
                    color: item.isAdded ? .black.opacity(0.1) : .clear,
                    radius: 3,
                    x: 0,
                    y: 2
                )
                .shadow(
                    color: item.isAdded ? .black.opacity(0.1) : .clear,
                    radius: 1.5,
                    x: 0,
                    y: -1
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mock Data

extension SearchView {
    static let mockRecentSearches: [SearchResultItem] = [
        SearchResultItem(
            title: "Astris",
            category: .movies,
            year: "2023",
            rating: 9.2,
            genres: "Sci-fi, Drama, Mystery",
            imageName: "mock-astris",
            placeholderColor: Color(hex: 0x2C3E50)
        ),
        SearchResultItem(
            title: "Iron & Ember",
            category: .games,
            year: "2022",
            rating: 8.8,
            genres: "Action RPG, Open World",
            imageName: "mock-iron-ember",
            placeholderColor: Color(hex: 0xE67E22),
            isAdded: true
        ),
        SearchResultItem(
            title: "The Cloud Weaver",
            category: .anime,
            year: "2024",
            rating: 8.5,
            genres: "Fantasy, Adventure",
            imageName: "mock-cloud-weaver",
            placeholderColor: Color(hex: 0x87CEEB)
        ),
    ]

    static let mockAllMedia: [SearchResultItem] = [
        // Movies
        SearchResultItem(
            title: "Astris",
            category: .movies,
            year: "2023",
            rating: 9.2,
            genres: "Sci-fi, Drama, Mystery",
            imageName: "mock-astris",
            placeholderColor: Color(hex: 0x2C3E50)
        ),
        SearchResultItem(
            title: "Dune: Part Three",
            category: .movies,
            year: "2026",
            rating: 8.9,
            genres: "Sci-fi, Adventure, Drama",
            imageName: "mock-dune",
            placeholderColor: Color(hex: 0xC2A059)
        ),
        SearchResultItem(
            title: "The Midnight Garden",
            category: .movies,
            year: "2025",
            rating: 7.8,
            genres: "Drama, Romance",
            imageName: "mock-midnight-garden",
            placeholderColor: Color(hex: 0x2D4A3E)
        ),

        // TV Shows
        SearchResultItem(
            title: "Severance",
            category: .tvShows,
            year: "2022",
            rating: 8.7,
            genres: "Thriller, Drama, Sci-fi",
            imageName: "mock-severance",
            placeholderColor: Color(hex: 0x3B5998)
        ),
        SearchResultItem(
            title: "The Bear",
            category: .tvShows,
            year: "2022",
            rating: 8.9,
            genres: "Drama, Comedy",
            imageName: "mock-the-bear",
            placeholderColor: Color(hex: 0x8B4513)
        ),

        // Anime
        SearchResultItem(
            title: "The Cloud Weaver",
            category: .anime,
            year: "2024",
            rating: 8.5,
            genres: "Fantasy, Adventure",
            imageName: "mock-cloud-weaver",
            placeholderColor: Color(hex: 0x87CEEB)
        ),
        SearchResultItem(
            title: "Frieren: Beyond Journey's End",
            category: .anime,
            year: "2023",
            rating: 9.1,
            genres: "Fantasy, Adventure, Drama",
            imageName: "mock-frieren",
            placeholderColor: Color(hex: 0x9B8EC4)
        ),
        SearchResultItem(
            title: "Dandadan",
            category: .anime,
            year: "2024",
            rating: 8.6,
            genres: "Action, Comedy, Supernatural",
            imageName: "mock-dandadan",
            placeholderColor: Color(hex: 0xE84393)
        ),

        // Manga
        SearchResultItem(
            title: "Chainsaw Man",
            category: .manga,
            year: "2018",
            rating: 8.8,
            genres: "Action, Supernatural, Horror",
            imageName: "mock-chainsaw-man",
            placeholderColor: Color(hex: 0xD63031)
        ),
        SearchResultItem(
            title: "Blue Lock",
            category: .manga,
            year: "2018",
            rating: 8.2,
            genres: "Sports, Drama",
            imageName: "mock-blue-lock",
            placeholderColor: Color(hex: 0x0984E3)
        ),

        // Books
        SearchResultItem(
            title: "Foundation's Edge",
            category: .books,
            year: "1982",
            rating: 8.4,
            genres: "Sci-fi, Philosophy",
            imageName: "mock-foundations-edge",
            placeholderColor: Color(hex: 0xD4A373)
        ),
        SearchResultItem(
            title: "Project Hail Mary",
            category: .books,
            year: "2021",
            rating: 9.0,
            genres: "Sci-fi, Adventure",
            imageName: "mock-hail-mary",
            placeholderColor: Color(hex: 0x2C3E50)
        ),

        // Games
        SearchResultItem(
            title: "Iron & Ember",
            category: .games,
            year: "2022",
            rating: 8.8,
            genres: "Action RPG, Open World",
            imageName: "mock-iron-ember",
            placeholderColor: Color(hex: 0xE67E22)
        ),
        SearchResultItem(
            title: "Elden Ring: Nightreign",
            category: .games,
            year: "2025",
            rating: 9.3,
            genres: "Action RPG, Co-op",
            imageName: "mock-elden-ring",
            placeholderColor: Color(hex: 0xFDA523)
        ),
        SearchResultItem(
            title: "Hollow Knight: Silksong",
            category: .games,
            year: "2025",
            rating: 9.1,
            genres: "Metroidvania, Action",
            imageName: "mock-silksong",
            placeholderColor: Color(hex: 0xDFE6E9)
        ),
    ]
}

// MARK: - Preview

#Preview("Idle") {
    SearchView()
}
