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

// MARK: - Library View

struct LibraryView: View {
    @State private var selectedFilter: LibraryFilter = .all
    @State private var items: [LibraryItem] = LibraryView.mockItems

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

        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            headerTitle
            filterChips
            libraryItems
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.nook.searchBackground)
    }

    // MARK: - Header

    private var headerTitle: some View {
        HStack(alignment: .center) {
            Text("Library")
                .font(NookFont.headingLarge)
                .foregroundStyle(Color.nook.sectionTitle)

            Spacer()

            // Search + Sort buttons
            HStack(spacing: 0) {
                Button {
                    // No action
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

                Button {
                    // No action
                } label: {
                    Image("sort-ascending-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.nook.sectionTitle)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
            .background(Color.nook.searchBarBackground)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
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
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func filterChip(_ filter: LibraryFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
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

    // MARK: - Library Items

    private var libraryItems: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("\(filteredItems.count) ITEMS")
                    .font(NookFont.tabLabel)
                    .tracking(1)
                    .foregroundStyle(Color.nook.searchSectionLabel)
                    .padding(.bottom, 24)

                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    LibraryItemRow(item: item)

                    if index < filteredItems.count - 1 {
                        Spacer().frame(height: 24)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 100)
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
                .foregroundStyle(item.category.backgroundColor)

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

    private var actionButton: some View {
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
