import SwiftUI

// MARK: - Tracking Status

enum TrackingStatus {
    case watching
    case reading
    case playing
    case completed

    var label: String {
        switch self {
        case .watching: "Watching"
        case .reading: "Reading"
        case .playing: "Playing"
        case .completed: "Completed"
        }
    }

    var dotColor: Color {
        switch self {
        case .watching: Color.nook.libraryStatusActive
        case .reading: Color.nook.libraryStatusReading
        case .playing: Color.nook.libraryStatusActive
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

    var textColor: Color { .white }

    var backgroundColor: Color {
        switch self {
        case .anime: Color.nook.badgeAnimeText
        case .tvShow: Color.nook.badgeTvShowText
        case .book: Color.nook.badgeBookText
        case .game: Color.nook.categoryGame
        case .movie: Color.nook.categoryMovie
        case .manga: Color.nook.categoryManga
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
    case watching
    case reading
    case playing
    case completed

    var id: String {
        switch self {
        case .all: "all"
        case .watching: "watching"
        case .reading: "reading"
        case .playing: "playing"
        case .completed: "completed"
        }
    }

    var label: String {
        switch self {
        case .all: "All Media"
        case .watching: "Watching"
        case .reading: "Reading"
        case .playing: "Playing"
        case .completed: "Completed"
        }
    }
}

// MARK: - Library View

struct LibraryView: View {
    @State private var selectedFilter: LibraryFilter = .all
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var items: [LibraryItem] = LibraryView.mockItems

    private var filteredItems: [LibraryItem] {
        var results = items

        switch selectedFilter {
        case .all: break
        case .watching:
            results = results.filter { $0.status == .watching }
        case .reading:
            results = results.filter { $0.status == .reading }
        case .playing:
            results = results.filter { $0.status == .playing }
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
        ZStack(alignment: .top) {
            // Scrollable content
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(filteredItems) { item in
                        LibraryItemRow(item: item)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, isSearching ? 152 : 206)
                .padding(.bottom, 100)
            }
            .background(Color.nook.background)

            // Sticky header
            headerSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            if isSearching {
                searchBar
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                headerTitle
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            filterChips
                .padding(.top, isSearching ? 16 : 24)
                .padding(.bottom, 12)
        }
        .background(
            Color.nook.headerBackground
                .background(.ultraThinMaterial)
                .ignoresSafeArea(.container, edges: .top)
        )
    }

    private var headerTitle: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Library")
                    .font(NookFont.outfitDisplay.weight(.bold))
                    .font(.custom("Outfit-Bold", size: 30))
                    .foregroundStyle(Color.nook.sectionTitle)

                Text("Tracking \(items.count) items")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.cardSubtitle)
            }

            Spacer()

            // Search / filter button
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    isSearching = true
                }
            } label: {
                Circle()
                    .fill(Color.nook.secondary)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.nook.sectionTitle)
                    }
            }
            .buttonStyle(.plain)
            .offset(y: 8)
        }
        .padding(.horizontal, 24)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image("magnifying-glass-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(Color.nook.searchBarPlaceholder)

            TextField(
                "Search your library...",
                text: $searchText,
                prompt: Text("Search your library...")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.searchBarPlaceholder)
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.searchBarText)

            if !searchText.isEmpty || isSearching {
                Button {
                    searchText = ""
                    withAnimation(.easeOut(duration: 0.25)) {
                        isSearching = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.nook.cardSubtitle)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.nook.secondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.nook.searchBarBackground)
        .clipShape(Capsule())
        .padding(.horizontal, 24)
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
        }
    }

    private func filterChip(_ filter: LibraryFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.label)
                .font(isSelected ? NookFont.labelBoldSmall : NookFont.labelMediumSmall)
                .foregroundStyle(isSelected ? .white : Color.nook.sectionTitle)
                .padding(.horizontal, 20)
                .frame(height: 42)
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
                .shadow(
                    color: isSelected ? .black.opacity(0.1) : .clear,
                    radius: 3,
                    x: 0,
                    y: 2
                )
                .shadow(
                    color: isSelected ? .black.opacity(0.1) : .clear,
                    radius: 1.5,
                    x: 0,
                    y: -1
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Library Item Row

private struct LibraryItemRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            posterImage
            itemDetails
        }
        .frame(height: 144)
    }

    // MARK: - Poster

    private var posterImage: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let color = item.placeholderColor {
                    color
                } else {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 96, height: 144)
            .clipShape(RoundedRectangle(cornerRadius: 26.67, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -0.5)

            // Category badge
            Text(item.category.label)
                .font(.custom("PlusJakartaSans-Bold", size: 8))
                .tracking(-0.4)
                .foregroundStyle(item.category.textColor)
                .padding(.horizontal, 4.5)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 2.22, style: .continuous)
                        .fill(item.category.backgroundColor)
                )
                .padding(6)
        }
    }

    // MARK: - Details

    private var itemDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 25)

            // Title + status dot
            HStack {
                Text(item.title)
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.cardTitle)
                    .lineLimit(1)

                Spacer()

                if item.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(item.status.dotColor)
                } else {
                    Circle()
                        .fill(item.status.dotColor)
                        .frame(width: 8, height: 8)
                }
            }

            // Progress detail
            Text(item.progressDetail)
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.cardSubtitle)
                .padding(.top, 4)

            // Progress bar
            progressBar
                .padding(.top, 12)

            // Action button + rating
            actionRow
                .padding(.top, 6)

            Spacer()
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(item.status.progressTrackColor)
                    .frame(height: 6)

                Capsule()
                    .fill(item.status.progressFillColor)
                    .frame(width: geometry.size.width * item.progress, height: 6)
            }
        }
        .frame(height: 6)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            // Update / Replay button
            Button {
                // TODO: action
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: item.status.actionIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.nook.sectionTitle)
                        .frame(width: 11, height: 11)

                    Text(item.status.actionLabel)
                        .font(.custom("PlusJakartaSans-Bold", size: 11))
                        .foregroundStyle(Color.nook.sectionTitle)
                }
                .padding(.horizontal, 12)
                .frame(height: 29)
                .background(
                    RoundedRectangle(cornerRadius: 8.06, style: .continuous)
                        .fill(Color.nook.secondary)
                )
            }
            .buttonStyle(.plain)

            // Rating
            if let rating = item.rating {
                HStack(spacing: 2) {
                    Image("star-fill")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Color.nook.accent)

                    Text(String(format: "%.1f", rating))
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.accent)
                }
            } else {
                Text("No rating yet")
                    .font(NookFont.label)
                    .font(.custom("PlusJakartaSans-Medium", size: 12))
                    .foregroundStyle(Color.nook.cardSubtitle)
            }
        }
    }
}

// MARK: - Mock Data

extension LibraryView {
    static let mockItems: [LibraryItem] = [
        LibraryItem(
            title: "The Cloud Weaver",
            category: .anime,
            status: .watching,
            progressDetail: "S1, Ep 12 / 24",
            progress: 0.5,
            rating: 8.5,
            imageName: "mock-cloud-weaver",
            placeholderColor: Color(hex: 0x87CEEB)
        ),
        LibraryItem(
            title: "Foundation's Edge",
            category: .book,
            status: .reading,
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
