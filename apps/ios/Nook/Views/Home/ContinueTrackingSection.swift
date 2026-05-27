import SwiftUI

// MARK: - Data Model

struct TrackingItem: Identifiable {
    let id = UUID()
    let title: String
    let progress: String
    let category: MediaCategory
    let imageName: String
    let placeholderColor: Color?

    init(title: String, progress: String, category: MediaCategory, imageName: String, placeholderColor: Color? = nil) {
        self.title = title
        self.progress = progress
        self.category = category
        self.imageName = imageName
        self.placeholderColor = placeholderColor
    }
}

enum MediaCategory {
    case anime
    case tvShow
    case book

    var label: String {
        switch self {
        case .anime: "ANIME"
        case .tvShow: "TV SHOW"
        case .book: "BOOK"
        }
    }

    var textColor: Color {
        switch self {
        case .anime: Color.nook.badgeAnimeText
        case .tvShow: Color.nook.badgeTvShowText
        case .book: Color.nook.badgeBookText
        }
    }

    var backgroundColor: Color {
        switch self {
        case .anime: Color.nook.badgeAnimeBg
        case .tvShow: Color.nook.badgeTvShowBg
        case .book: Color.nook.badgeBookBg
        }
    }
}

// MARK: - Section

struct ContinueTrackingSection: View {
    let items: [TrackingItem]

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

            Button {
                // TODO: See all action
            } label: {
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
                    NavigationLink(value: MediaDetailView.mockMedia) {
                        TrackingCard(item: item)
                    }
                    .buttonStyle(.plain)
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
            cardImage
            cardText
        }
        .frame(width: 180)
    }

    private var cardImage: some View {
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
            .frame(width: 180, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 44))
            .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -0.5)

            categoryBadge
                .padding(12)
        }
    }

    private var categoryBadge: some View {
        Text(item.category.label)
            .font(NookFont.tabLabel)
            .textCase(.uppercase)
            .foregroundStyle(item.category.textColor)
            .padding(.horizontal, 6.5)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(item.category.backgroundColor)
                    .background(.ultraThinMaterial, in: Capsule())
            )
    }

    private var cardText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.cardTitle)
                .lineLimit(1)
                .padding(.top, 12)

            Text(item.progress)
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.cardSubtitle)
                .padding(.top, 4)
        }
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
