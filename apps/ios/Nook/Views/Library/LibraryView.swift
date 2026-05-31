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

    var dbValue: String {
        switch self {
        case .inProgress: "in_progress"
        case .planned: "planned"
        case .onHold: "on_hold"
        case .dropped: "dropped"
        case .completed: "completed"
        }
    }

    static func from(dbValue: String) -> TrackingStatus? {
        switch dbValue {
        case "in_progress": .inProgress
        case "planned": .planned
        case "on_hold": .onHold
        case "dropped": .dropped
        case "completed": .completed
        default: nil
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

    static func from(apiMediaType: String) -> LibraryMediaCategory {
        switch apiMediaType {
        case "movie": .movie
        case "tv": .tvShow
        case "anime": .anime
        case "manga": .manga
        case "book": .book
        case "game": .game
        default: .movie
        }
    }
}

// MARK: - Library Item Model

struct LibraryItem: Identifiable {
    let id = UUID()
    let title: String
    let category: LibraryMediaCategory
    var status: TrackingStatus
    let progressDetail: String
    let progress: Double // 0.0 to 1.0
    var rating: Double?
    let imageName: String
    let placeholderColor: Color?
    let totalEpisodes: Int
    var currentEpisode: Int
    var userScore: Int?

    init(
        title: String,
        category: LibraryMediaCategory,
        status: TrackingStatus,
        progressDetail: String,
        progress: Double,
        rating: Double? = nil,
        imageName: String,
        placeholderColor: Color? = nil,
        totalEpisodes: Int = 0,
        currentEpisode: Int = 0,
        userScore: Int? = nil
    ) {
        self.title = title
        self.category = category
        self.status = status
        self.progressDetail = progressDetail
        self.progress = progress
        self.rating = rating
        self.imageName = imageName
        self.placeholderColor = placeholderColor
        self.totalEpisodes = totalEpisodes
        self.currentEpisode = currentEpisode
        self.userScore = userScore
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
    @State private var viewModel = LibraryViewModel()
    @State private var isSearchActive = false
    @State private var trackingItemID: UUID?
    @State private var sheetStatus: TrackingStatus?
    @State private var sheetEpisode: Int = 0
    @State private var sheetScore: Int?
    @State private var sheetIsTracking = false
    @State private var sheetIsRated = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        scrollContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.nook.searchBackground)
            .modifier(
                LibraryTopBar(
                    isSearchActive: $isSearchActive,
                    searchText: $viewModel.searchText,
                    isSearchFocused: $isSearchFocused,
                    selectedSort: $viewModel.selectedSort
                )
            )
            .task {
                await viewModel.loadLibrary()
            }
            .refreshable {
                await viewModel.loadLibrary()
            }
            .sheet(isPresented: Binding(
                get: { trackingItemID != nil },
                set: { if !$0 { handleSheetDismiss(); trackingItemID = nil } }
            )) {
                if let item = viewModel.items.first(where: { $0.id == trackingItemID }) {
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

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterChips

                if let error = viewModel.error {
                    ErrorBanner(message: error.localizedDescription) {
                        viewModel.error = nil
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                if viewModel.isLoading && viewModel.items.isEmpty {
                    VStack(spacing: 24) {
                        ForEach(0..<4, id: \.self) { _ in
                            SearchShimmerRow()
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 8)
                } else if viewModel.filteredItems.isEmpty {
                    SearchEmptyState(
                        icon: "books-bold",
                        title: "Nothing here yet",
                        subtitle: "Search for media and start tracking to build your library"
                    )
                } else {
                    Text("\(viewModel.filteredItems.count) ITEMS")
                        .font(NookFont.tabLabel)
                        .tracking(1)
                        .foregroundStyle(Color.nook.searchSectionLabel)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    LazyVStack(spacing: 24) {
                        ForEach(viewModel.filteredItems) { item in
                            NavigationLink(value: MediaDetailRoute(
                                mediaId: item.sourceId,
                                source: item.source,
                                mediaType: item.mediaType,
                                title: item.title,
                                imageURL: item.imageURL,
                                year: item.year,
                                score: item.score
                            )) {
                                RealLibraryItemRow(item: item) {
                                    openTrackingSheet(for: item)
                                }
                                .padding(.horizontal, 24)
                            }
                            .buttonStyle(.plain)
                        }
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
        let isSelected = viewModel.selectedFilter == filter

        if #available(iOS 26, *) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.selectedFilter = filter
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
                    viewModel.selectedFilter = filter
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

    // MARK: - Tracking Sheet

    private func openTrackingSheet(for item: TrackedMediaItem) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        sheetStatus = TrackingStatus.from(dbValue: item.status)
        sheetEpisode = item.progress
        sheetScore = item.score.map { Int($0) }
        sheetIsTracking = true
        sheetIsRated = item.score != nil
        trackingItemID = item.id

        generator.impactOccurred()
    }

    private func handleSheetDismiss() {
        guard let id = trackingItemID,
              let item = viewModel.items.first(where: { $0.id == id }) else { return }

        Task {
            await viewModel.updateTracking(
                trackingId: item.id,
                status: sheetStatus,
                progress: sheetEpisode,
                score: sheetScore.map { Double($0) }
            )
        }
    }
}

// MARK: - Top Bar (safeAreaBar on iOS 26, safeAreaInset fallback)

private struct LibraryTopBar: ViewModifier {
    @Binding var isSearchActive: Bool
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    @Binding var selectedSort: LibrarySortOption

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

            Spacer()

            headerButtons
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
                withAnimation(.easeOut(duration: 0.25)) {
                    isSearchActive = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                withAnimation(.easeOut(duration: 0.25)) {
                    isSearchActive = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                withAnimation(.easeOut(duration: 0.25)) {
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
            .transition(.opacity)
        } else {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
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
            .transition(.opacity)
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
    let onTapAction: () -> Void

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

    private var editIcon: some View {
        Image("pencil-simple-line-fill")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
    }

    @available(iOS 26, *)
    private var glassActionButton: some View {
        Button(action: onTapAction) {
            editIcon
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.nook.searchAddedButton, in: Circle())
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
    }

    private var classicActionButton: some View {
        Button(action: onTapAction) {
            Circle()
                .fill(Color.nook.searchAddedButton)
                .frame(width: 40, height: 40)
                .overlay {
                    editIcon
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: -1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Real Library Item Row (uses TrackedMediaItem from Supabase)

private struct RealLibraryItemRow: View {
    let item: TrackedMediaItem
    let onTapAction: () -> Void

    private var category: LibraryMediaCategory {
        LibraryMediaCategory.from(apiMediaType: item.mediaType)
    }

    private var status: TrackingStatus {
        TrackingStatus.from(dbValue: item.status) ?? .planned
    }

    private var progressDetail: String {
        if item.progress > 0 {
            return "Progress: \(item.progress)"
        }
        return status.label
    }

    var body: some View {
        HStack(spacing: 16) {
            MediaPosterImage(
                url: item.imageURL,
                width: 64,
                height: 80,
                fallbackColor: category.textColor.opacity(0.3)
            )
            .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -0.5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    Text(category.label)
                        .font(NookFont.tabLabel)
                        .tracking(0.5)
                        .foregroundStyle(category.textColor)

                    Circle()
                        .fill(Color.nook.searchSectionLabel)
                        .frame(width: 3, height: 3)

                    Text(status.label)
                        .font(NookFont.tabLabel)
                        .tracking(0.5)
                        .foregroundStyle(Color.nook.searchSectionLabel)
                }

                Text(item.title)
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.searchBarText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let score = item.score {
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

                    Text(progressDetail)
                        .font(NookFont.caption.italic())
                        .foregroundStyle(Color.nook.searchSectionLabel)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            realActionButton
        }
        .frame(height: 80)
    }

    @ViewBuilder
    private var realActionButton: some View {
        if #available(iOS 26, *) {
            Button(action: onTapAction) {
                Image("pencil-simple-line-fill")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.nook.searchAddedButton, in: Circle())
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onTapAction) {
                Circle()
                    .fill(Color.nook.searchAddedButton)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image("pencil-simple-line-fill")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: -1)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Mock Data (for previews)

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
            placeholderColor: Color(hex: 0x87CEEB),
            totalEpisodes: 24,
            currentEpisode: 12,
            userScore: 9
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
            placeholderColor: Color(hex: 0xE67E22),
            userScore: 9
        ),
    ]
}

// MARK: - Preview

#Preview {
    LibraryView()
}
