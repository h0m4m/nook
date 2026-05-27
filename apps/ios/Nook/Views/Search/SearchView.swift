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

// MARK: - Search View

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedFilter: SearchMediaCategory? = nil
    @State private var recentSearches: [SearchResultItem] = SearchView.mockRecentSearches
    @State private var userInterests: [SearchMediaCategory] = []

    var filteredResults: [SearchResultItem] {
        var results = recentSearches
        if let filter = selectedFilter {
            results = results.filter { $0.category == filter }
        }
        return results
    }

    var body: some View {
        scrollContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.nook.searchBackground)
            .modifier(SearchTopBar(searchText: $searchText, selectedFilter: selectedFilter))
            .task {
                await loadUserInterests()
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterChips

                // Section header
                Text("RECENT SEARCHES")
                    .font(NookFont.tabLabel)
                    .tracking(1)
                    .foregroundStyle(Color.nook.searchSectionLabel)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                // Result rows
                ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, item in
                    SearchResultRow(item: item) {
                        toggleAdded(item)
                    }
                    .padding(.horizontal, 24)

                    if index < filteredResults.count - 1 {
                        Spacer().frame(height: 24)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .modifier(SoftScrollEdge())
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                filterChip(label: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }

                // Category chips based on user interests
                ForEach(userInterests) { category in
                    filterChip(
                        label: category.label,
                        dotColor: category.dotColor,
                        isSelected: selectedFilter == category
                    ) {
                        selectedFilter = category
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 14)
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

    // MARK: - Actions

    private func toggleAdded(_ item: SearchResultItem) {
        guard let index = recentSearches.firstIndex(where: { $0.id == item.id }) else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            recentSearches[index].isAdded.toggle()
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
            // Fallback: show all categories
            userInterests = SearchMediaCategory.allCases
        }
    }
}

// MARK: - Top bar (safeAreaBar on iOS 26, safeAreaInset fallback)

private struct SearchTopBar: ViewModifier {
    @Binding var searchText: String
    var selectedFilter: SearchMediaCategory?

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
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .modifier(SearchBarBackground())
        .padding(.horizontal, 24)
    }
}

// MARK: - Search bar background (glass on iOS 26, solid fallback)

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
}

// MARK: - Preview

#Preview {
    SearchView()
}
