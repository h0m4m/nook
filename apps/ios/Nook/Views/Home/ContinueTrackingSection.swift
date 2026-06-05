import SwiftUI

// MARK: - Data Model

struct TrackingItem: Identifiable {
    let id = UUID()
    let title: String
    let progress: String
    let category: MediaCategory
    let imageName: String
    let imageURL: URL?
    let placeholderColor: Color?

    // Routing data (nil for mock items)
    let source: String?
    let sourceId: String?
    let mediaType: String?
    let year: String?
    let score: Double?

    /// Navigation route to the real media detail screen, when routing data is available.
    var detailRoute: MediaDetailRoute? {
        guard let source, let sourceId, let mediaType else { return nil }
        return MediaDetailRoute(
            mediaId: sourceId,
            source: source,
            mediaType: mediaType,
            title: title,
            imageURL: imageURL,
            year: year,
            score: score
        )
    }

    init(title: String, progress: String, category: MediaCategory, imageName: String, imageURL: URL? = nil, placeholderColor: Color? = nil) {
        self.title = title
        self.progress = progress
        self.category = category
        self.imageName = imageName
        self.imageURL = imageURL
        self.placeholderColor = placeholderColor
        self.source = nil
        self.sourceId = nil
        self.mediaType = nil
        self.year = nil
        self.score = nil
    }

    init(from item: TrackedMediaItem) {
        self.title = item.title
        self.imageURL = item.imageURL
        self.imageName = ""
        self.placeholderColor = nil
        self.source = item.source
        self.sourceId = item.sourceId
        self.mediaType = item.mediaType
        self.year = item.year
        self.score = item.score

        let progressText: String
        if item.progress > 0 {
            progressText = item.mediaType == "game"
                ? hoursTrackedLabel(item.progress)
                : "Progress: \(item.progress)"
        } else {
            progressText = TrackingStatus.from(dbValue: item.status)?.label ?? item.status
        }
        self.progress = progressText

        switch item.mediaType {
        case "anime": self.category = .anime
        case "tv": self.category = .tvShow
        case "book": self.category = .book
        case "game": self.category = .game
        case "movie": self.category = .movie
        case "manga": self.category = .manga
        default: self.category = .anime
        }
    }
}

enum MediaCategory {
    case anime
    case tvShow
    case book
    case game
    case movie
    case manga

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

// MARK: - Section

struct ContinueTrackingSection: View {
    let items: [TrackingItem]
    var onSeeAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader
            scrollContent
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text("Continue tracking")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.sectionTitle)

            Spacer()

            Button(action: onSeeAll) {
                Text("See all")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.sectionAction)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(items) { item in
                    if let route = item.detailRoute {
                        NavigationLink(value: route) {
                            TrackingCard(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        TrackingCard(item: item)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Card

private struct TrackingCard: View {
    let item: TrackingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            posterImage

            Text(item.title)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.cardTitle)
                .lineLimit(1)
                .padding(.top, 10)

            HStack(spacing: 6) {
                categoryBadge

                Text(item.progress)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.cardSubtitle)
            }
            .padding(.top, 6)
        }
        .frame(width: 180)
    }

    private var posterImage: some View {
        Group {
            if let url = item.imageURL {
                MediaPosterImage(
                    url: url,
                    width: 180,
                    height: 240,
                    cornerRadius: NookRadii.md
                )
            } else if let color = item.placeholderColor {
                color
                    .frame(width: 180, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))
            } else if !item.imageName.isEmpty {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))
            } else {
                Color.nook.searchShimmerBase
                    .frame(width: 180, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))
            }
        }
    }

    private var categoryBadge: some View {
        Text(item.category.label)
            .font(NookFont.tabLabel)
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(item.category.textColor)
            .padding(.horizontal, 6.5)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6.39, style: .continuous)
                    .fill(item.category.backgroundColor)
            )
    }
}

// MARK: - Mock Data

extension ContinueTrackingSection {
    static let mockItems: [TrackingItem] = [
        TrackingItem(
            title: "The Cloud Weaver",
            progress: "Ep 12 of 24",
            category: .anime,
            imageName: "mock-cloud-weaver",
            placeholderColor: Color(hex: 0x87CEEB)
        ),
        TrackingItem(
            title: "SOUS",
            progress: "S2, Ep 04",
            category: .tvShow,
            imageName: "mock-sous",
            placeholderColor: Color(hex: 0x4A3243)
        ),
        TrackingItem(
            title: "The Guest List",
            progress: "Pg 142 of 320",
            category: .book,
            imageName: "mock-guest-list",
            placeholderColor: Color(hex: 0xD4A373)
        ),
    ]
}

// MARK: - Preview

#Preview {
    ScrollView {
        ContinueTrackingSection(items: ContinueTrackingSection.mockItems)
    }
    .background(Color.nook.background)
}
