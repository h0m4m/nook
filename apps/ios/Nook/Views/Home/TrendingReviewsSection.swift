import SwiftUI

// MARK: - Data Model

struct ReviewItem: Identifiable, Hashable {
    let id = UUID()
    let dbId: UUID?
    let reviewerUserId: UUID?
    let reviewerName: String
    let mediaTitle: String
    let mediaImageURL: URL?
    let mediaSource: String?
    let mediaSourceId: String?
    let mediaType: String?
    let createdAt: Date?
    let rating: Double
    let title: String
    let body: String
    let likes: String
    let comments: String

    init(
        reviewerName: String,
        mediaTitle: String,
        mediaImageURL: URL? = nil,
        createdAt: Date? = nil,
        rating: Double,
        title: String,
        body: String,
        likes: String,
        comments: String,
        dbId: UUID? = nil,
        reviewerUserId: UUID? = nil,
        mediaSource: String? = nil,
        mediaSourceId: String? = nil,
        mediaType: String? = nil
    ) {
        self.reviewerName = reviewerName
        self.mediaTitle = mediaTitle
        self.mediaImageURL = mediaImageURL
        self.createdAt = createdAt
        self.rating = rating
        self.title = title
        self.body = body
        self.likes = likes
        self.comments = comments
        self.dbId = dbId
        self.reviewerUserId = reviewerUserId
        self.mediaSource = mediaSource
        self.mediaSourceId = mediaSourceId
        self.mediaType = mediaType
    }

    init(from review: Review) {
        self.dbId = review.id
        self.reviewerUserId = review.userId
        self.reviewerName = review.authorName
        self.mediaTitle = review.mediaTitle ?? ""
        self.mediaImageURL = review.mediaImageURL
        self.mediaSource = review.mediaSource
        self.mediaSourceId = review.mediaSourceId
        self.mediaType = review.mediaType
        self.createdAt = review.createdAt
        self.rating = review.rating
        self.title = review.title ?? ""
        self.body = review.body
        self.likes = "\(review.likesCount)"
        self.comments = "0"
    }

    /// Build a MediaDetailRoute for navigating to the media detail page.
    var mediaDetailRoute: MediaDetailRoute? {
        guard let source = mediaSource, let sourceId = mediaSourceId, let type = mediaType else { return nil }
        return MediaDetailRoute(
            mediaId: sourceId,
            source: source,
            mediaType: type,
            title: mediaTitle,
            imageURL: mediaImageURL
        )
    }
}

// MARK: - Section

struct TrendingReviewsSection: View {
    let items: [ReviewItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader
            scrollContent
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text("Trending reviews")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.sectionTitle)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        ReviewCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Card

private struct ReviewCard: View {
    let item: ReviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
                .padding(.top, 21)
                .padding(.horizontal, 21)

            // Media being reviewed — on its own full-width row so long
            // titles don't get cramped next to the avatar / rating badge.
            reviewedLine
                .padding(.top, 10)
                .padding(.horizontal, 21)

            // Title
            Text(item.title)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.cardTitle)
                .lineLimit(1)
                .padding(.top, 12)
                .padding(.horizontal, 21)

            // Body (Markdown rendered)
            Text(markdownAttributed(item.body))
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.reviewBody)
                .lineSpacing(6)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.horizontal, 21)

            Spacer(minLength: 0)

            cardFooter
                .padding(.horizontal, 21)
                .padding(.bottom, 21)
        }
        .frame(width: 280, height: 252)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
    }

    // MARK: - Header (avatar, name, rating badge)

    private var cardHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            NavigationLink(value: item.reviewerUserId.map { UserProfile.reference(id: $0, displayName: item.reviewerName) } ?? .profileFor(name: item.reviewerName)) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.nook.secondary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.nook.mutedForeground)
                        )

                    Text(item.reviewerName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.cardTitle)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            // Rating badge
            HStack(spacing: 2) {
                Image("star-fill")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.nook.detailRatingText)

                Text(String(format: "%.1f", item.rating))
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.detailRatingText)
            }
            .padding(.horizontal, 6.5)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6.39, style: .continuous)
                    .fill(Color.nook.detailRatingBadge)
            )
        }
    }

    // MARK: - Reviewed media line (own row)

    private var reviewedLine: some View {
        HStack(spacing: 3) {
            Text("reviewed")
                .font(.custom("PlusJakartaSans-Regular", size: 11))
                .foregroundStyle(Color.nook.cardSubtitle)

            Text(item.mediaTitle)
                .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                .foregroundStyle(Color.nook.cardTitle)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Footer (likes, comments)

    private var cardFooter: some View {
        HStack(spacing: 15) {
            HStack(spacing: 4) {
                Image("heart")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.cardSubtitle)

                Text(item.likes)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.cardSubtitle)
            }

            HStack(spacing: 4) {
                Image("chat-circle")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.cardSubtitle)

                Text(item.comments)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.cardSubtitle)
            }

            Spacer()
        }
    }
}

// MARK: - Mock Data

extension TrendingReviewsSection {
    static let mockItems: [ReviewItem] = [
        ReviewItem(
            reviewerName: "Elena Vance",
            mediaTitle: "Astris",
            rating: 9.5,
            title: "An absolute masterpiece.",
            body: "An absolute masterclass in visual storytelling. The third act left me completely speechless. Must watch on...",
            likes: "1.2k",
            comments: "48"
        ),
        ReviewItem(
            reviewerName: "Marcus",
            mediaTitle: "Solaris",
            rating: 8.7,
            title: "Beautiful but slow pacing",
            body: "A slow burn that rewards patience. The cinematography alone makes it worth every minute.",
            likes: "842",
            comments: "31"
        ),
        ReviewItem(
            reviewerName: "Aria Chen",
            mediaTitle: "Neon Drift",
            rating: 9.1,
            title: "A new standard for anime",
            body: "This redefines what anime can be. Every frame is a painting, every scene hits differently.",
            likes: "2.1k",
            comments: "96"
        ),
    ]
}

// MARK: - Preview

#Preview {
    ScrollView {
        TrendingReviewsSection(items: TrendingReviewsSection.mockItems)
    }
    .background(Color.nook.background)
}
