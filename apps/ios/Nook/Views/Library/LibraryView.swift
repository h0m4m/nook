import SwiftUI

// MARK: - Tracking Status

enum TrackingStatus {
    case inProgress
    case planned
    case onHold
    case dropped
    case completed

    var label: String {
        switch self {
        case .inProgress: "In Progress"
        case .planned: "Planned"
        case .onHold: "On Hold"
        case .dropped: "Dropped"
        case .completed: "Completed"
        }
    }

    var dotColor: Color {
        switch self {
        case .inProgress: Color.nook.libraryStatusActive
        case .planned: Color.nook.libraryStatusReading
        case .onHold: Color.nook.accent
        case .dropped: Color.nook.cardSubtitle
        case .completed: Color.nook.libraryStatusActive
        }
    }

    var progressFillColor: Color {
        switch self {
        case .completed: Color.nook.libraryStatusActive
        default: Color.nook.primary
        }
    }

    var progressTrackColor: Color {
        switch self {
        case .completed: Color.nook.libraryCompletedTrack
        default: Color.nook.secondary
        }
    }

    var actionLabel: String {
        switch self {
        case .completed: "Replay"
        default: "Update"
        }
    }

    var actionIcon: String {
        switch self {
        case .completed: "arrow.counterclockwise"
        default: "plus"
        }
    }
}

// MARK: - Library Media Category

enum LibraryMediaCategory: String, CaseIterable, Identifiable {
    case anime
    case tvShow
    case book
    case game
    case movie
    case manga

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anime: "ANIME"
        case .tvShow: "TV SHOW"
        case .book: "BOOK"
        case .game: "GAME"
        case .movie: "MOVIE"
        case .manga: "MANGA"
        }
    }

    var textColor: Color {
        switch self {
        case .anime: Color.nook.badgeAnimeText
        case .tvShow: Color.nook.badgeTvShowText
        case .book: Color.nook.badgeBookText
        case .game: Color.nook.badgeGameText
        case .movie: Color.nook.badgeMovieText
        case .manga: Color.nook.badgeMangaText
        }
    }

    var backgroundColor: Color {
        switch self {
        case .anime: Color.nook.badgeAnimeBg
        case .tvShow: Color.nook.badgeTvShowBg
        case .book: Color.nook.badgeBookBg
        case .game: Color.nook.badgeGameBg
        case .movie: Color.nook.badgeMovieBg
        case .manga: Color.nook.badgeMangaBg
        }
    }
}

// MARK: - Library Item Model

struct LibraryItem: Identifiable {
    let id = UUID()
    let title: String
    let category: LibraryMediaCategory
    let status: TrackingStatus
    let progressDetail: String
    let progress: Double // 0.0 to 1.0
    let rating: Double?
    let imageName: String
    let placeholderColor: Color?

    init(
        title: String,
        category: LibraryMediaCategory,
        status: TrackingStatus,
        progressDetail: String,
        progress: Double,
        rating: Double? = nil,
        imageName: String,
        placeholderColor: Color? = nil
    ) {
        self.title = title
        self.category = category
        self.status = status
        self.progressDetail = progressDetail
        self.progress = progress
        self.rating = rating
        self.imageName = imageName
        self.placeholderColor = placeholderColor
    }
}

// MARK: - Library Filter

enum LibraryFilter: CaseIterable, Identifiable {
    case all
    case inProgress
    case planned
    case onHold
    case dropped
    case completed

    var id: String {
        switch self {
        case .all: "all"
        case .inProgress: "inProgress"
        case .planned: "planned"
        case .onHold: "onHold"
        case .dropped: "dropped"
        case .completed: "completed"
        }
    }

    var label: String {
        switch self {
        case .all: "All"
        case .inProgress: "In Progress"
        case .planned: "Planned"
        case .onHold: "On Hold"
        case .dropped: "Dropped"
        case .completed: "Completed"
        }
    }
}

// MARK: - Library Sort Option

enum LibrarySortOption: CaseIterable, Identifiable {
    case status
    case alphabetical
    case score
    case progress
    case airStartDate
    case lastUpdated

    var id: String {
        switch self {
        case .status: "status"
        case .alphabetical: "alphabetical"
        case .score: "score"
        case .progress: "progress"
        case .airStartDate: "airStartDate"
        case .lastUpdated: "lastUpdated"
        }
    }

    var label: String {
        switch self {
        case .status: "Status"
        case .alphabetical: "Alphabetical"
        case .score: "Score"
        case .progress: "Progress"
        case .airStartDate: "Air Start Date"
        case .lastUpdated: "Last Updated"
        }
    }
}

// MARK: - Library View

struct LibraryView: View {
    @State private var selectedFilter: LibraryFilter = .all
    @State private var selectedSort: LibrarySortOption = .status
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var items: [LibraryItem] = LibraryView.mockItems
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [LibraryItem] {
        var results = items

        switch selectedFilter {
        case .all: break
        case .inProgress:
            results = results.filter { $0.status == .inProgress }
        case .planned:
            results = results.filter { $0.status == .planned }
        case .onHold:
            results = results.filter { $0.status == .onHold }
        case .dropped:
            results = results.filter { $0.status == .dropped }
        case .completed:
            results = results.filter { $0.status == .completed }
        }

        if !searchText.isEmpty {
            results = results.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        return results
    }

    var body: some View {
        scrollContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.nook.searchBackground)
            .modifier(
                LibraryTopBar(
                    isSearchActive: $isSearchActive,
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused,
                    selectedSort: $selectedSort
                )
            )
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterChips

                Text("\(filteredItems.count) ITEMS")
                    .font(NookFont.tabLabel)
                    .tracking(1)
                    .foregroundStyle(Color.nook.searchSectionLabel)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    LibraryItemRow(item: item)
                        .padding(.horizontal, 24)

                    if index < filteredItems.count - 1 {
                        Spacer().frame(height: 24)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .modifier(LibrarySoftScrollEdge())
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func filterChip(_ filter: LibraryFilter) -> some View {
        let isSelected = selectedFilter == filter

        if #available(iOS 26, *) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedFilter = filter
                }
            } label: {
                Text(filter.label)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .padding(.horizontal, 20)
                    .frame(height: 38)
                    .background(
                        isSelected ? Color.nook.searchFilterSelected : .white,
                        in: Capsule()
                    )
                    .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedFilter = filter
                }
            } label: {
                Text(filter.label)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(isSelected ? .white : Color.nook.searchFilterText)
                    .padding(.horizontal, 20)
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

}

// MARK: - Top Bar (safeAreaBar on iOS 26, safeAreaInset fallback)

private struct LibraryTopBar: ViewModifier {
    @Binding var isSearchActive: Bool
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    @Binding var selectedSort: LibrarySortOption
    @Namespace private var headerNamespace

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                topBarContent
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                topBarContent
                    .background(Color.nook.searchBackground)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var topBarContent: some View {
        if isSearchActive {
            expandedSearchBar
        } else {
            collapsedHeader
        }
    }

    // MARK: - Collapsed Header (Title + Search/Sort buttons)

    private var collapsedHeader: some View {
        HStack(alignment: .center) {
            Text("Library")
                .font(NookFont.headingMediumBold)
                .foregroundStyle(Color.nook.sectionTitle)
                .transition(.opacity)

            Spacer()

            headerButtons
                .matchedGeometryEffect(id: "searchBar", in: headerNamespace)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var headerButtons: some View {
        if #available(iOS 26, *) {
            glassHeaderButtons
        } else {
            classicHeaderButtons
        }
    }

    @available(iOS 26, *)
    private var glassHeaderButtons: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isSearchActive = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchFocused.wrappedValue = true
                }
            } label: {
                Image("magnifying-glass-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.nook.sectionTitle)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            sortButton
        }
        .background(.white, in: Capsule())
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var classicHeaderButtons: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isSearchActive = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchFocused.wrappedValue = true
                }
            } label: {
                Image("magnifying-glass-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.nook.sectionTitle)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            sortButton
        }
        .background(Color.nook.searchBarBackground)
        .clipShape(Capsule())
    }

    private var sortButton: some View {
        Menu {
            Picker(selection: $selectedSort) {
                ForEach(LibrarySortOption.allCases) { option in
                    Text(option.label)
                        .tag(option)
                }
            } label: {
                Text("Sort By")
            }
        } label: {
            Image("sort-ascending-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.sectionTitle)
                .frame(width: 40, height: 40)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
    }

    // MARK: - Expanded Search Bar

    private var expandedSearchBar: some View {
        HStack(spacing: 10) {
            searchField
                .matchedGeometryEffect(id: "searchBar", in: headerNamespace)
            dismissButton
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 12) {
            Image("magnifying-glass-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.searchBarPlaceholder)

            TextField(
                "Search",
                text: $searchText,
                prompt: Text("Search")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.searchBarPlaceholder)
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.searchBarText)
            .focused(isSearchFocused)
        }
        .padding(.horizontal, 18)
        .frame(height: 40)
        .modifier(LibrarySearchBarBackground())
    }

    @ViewBuilder
    private var dismissButton: some View {
        if #available(iOS 26, *) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    searchText = ""
                    isSearchActive = false
                    isSearchFocused.wrappedValue = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.nook.sectionTitle)
                    .frame(width: 36, height: 36)
                    .background(.white, in: Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    searchText = ""
                    isSearchActive = false
                    isSearchFocused.wrappedValue = false
                }
            } label: {
                Circle()
                    .fill(Color.nook.searchBarBackground)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.nook.sectionTitle)
                    }
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }
}

// MARK: - Search bar background (glass on iOS 26, solid fallback)

private struct LibrarySearchBarBackground: ViewModifier {
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

private struct LibrarySoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - Library Item Row

private struct LibraryItemRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 16) {
            posterImage

            VStack(alignment: .leading, spacing: 4) {
                categoryAndStatus
                titleText
                progressInfo
            }

            Spacer(minLength: 8)

            actionButton
        }
        .frame(height: 80)
    }

    // MARK: - Poster

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

    // MARK: - Category & Status

    private var categoryAndStatus: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(item.category.label)
                .font(NookFont.tabLabel)
                .tracking(0.5)
                .foregroundStyle(item.category.textColor)

            Circle()
                .fill(Color.nook.searchSectionLabel)
                .frame(width: 3, height: 3)

            Text(item.status.label)
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

    // MARK: - Progress

    private var progressInfo: some View {
        HStack(spacing: 6) {
            if let rating = item.rating {
                Image("star-fill")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.nook.reviewRating)

                Text(String(format: "%.1f", rating))
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.reviewRating)
            }

            Text(item.progressDetail)
                .font(NookFont.caption.italic())
                .foregroundStyle(Color.nook.searchSectionLabel)
                .lineLimit(1)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if #available(iOS 26, *) {
            glassActionButton
        } else {
            classicActionButton
        }
    }

    @available(iOS 26, *)
    private var glassActionButton: some View {
        Button {
            // TODO: action
        } label: {
            Group {
                if item.status == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: item.status.actionIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 40, height: 40)
            .background(
                item.status == .completed ? Color.nook.searchAddedButton : .white,
                in: Circle()
            )
            .glassEffect(
                item.status == .completed ? .regular : .regular.interactive(),
                in: .circle
            )
        }
        .buttonStyle(.plain)
    }

    private var classicActionButton: some View {
        Button {
            // TODO: action
        } label: {
            Circle()
                .fill(item.status == .completed ? Color.nook.searchAddedButton : Color.nook.searchAddButton)
                .frame(width: 40, height: 40)
                .overlay {
                    if item.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: item.status.actionIcon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.nook.searchAddedButton)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mock Data

extension LibraryView {
    static let mockItems: [LibraryItem] = [
        LibraryItem(
            title: "The Cloud Weaver",
            category: .anime,
            status: .inProgress,
            progressDetail: "S1, Ep 12 / 24",
            progress: 0.5,
            rating: 8.5,
            imageName: "mock-cloud-weaver",
            placeholderColor: Color(hex: 0x87CEEB)
        ),
        LibraryItem(
            title: "Foundation's Edge",
            category: .book,
            status: .inProgress,
            progressDetail: "Pg 142 / 480",
            progress: 0.3,
            imageName: "mock-foundations-edge",
            placeholderColor: Color(hex: 0xD4A373)
        ),
        LibraryItem(
            title: "Iron & Ember",
            category: .game,
            status: .completed,
            progressDetail: "42 hours played",
            progress: 1.0,
            rating: 9.0,
            imageName: "mock-iron-ember",
            placeholderColor: Color(hex: 0xE67E22)
        ),
    ]
}

// MARK: - Preview

#Preview {
    LibraryView()
}
