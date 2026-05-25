import SwiftUI

// MARK: - Data Model

struct ReviewItem: Identifiable {
    let id = UUID()
    let reviewerName: String
    let mediaTitle: String
    let rating: Double
    let body: String
    let likes: String
    let comments: String
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
                    ReviewCard(item: item)
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
        VStack(spacing: 0) {
            cardHeader
                .padding(.top, 21)
                .padding(.horizontal, 21)

            cardBody
                .padding(.top, 12)
                .padding(.horizontal, 21)

            cardFooter
                .padding(.top, 12)
                .padding(.horizontal, 21)
                .padding(.bottom, 16)
        }
        .frame(width: 280, height: 200)
        .background(
            RoundedRectangle(cornerRadius: NookRadii.lg)
                .fill(Color.nook.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NookRadii.lg)
                .strokeBorder(Color.nook.reviewBorder, lineWidth: 1)
        )
    }

    // MARK: - Header (avatar, name, rating)

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(spacing: 8) {
                // Avatar
                Circle()
                    .fill(Color.nook.secondary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.nook.mutedForeground)
                    )

                // Name & media
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.reviewerName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.cardTitle)
                        .lineLimit(1)

                    HStack(spacing: 2) {
                        Text("reviewed")
                            .font(.custom("PlusJakartaSans-Regular", size: 10))
                            .foregroundStyle(Color.nook.cardSubtitle)

                        Text(item.mediaTitle)
                            .font(.custom("PlusJakartaSans-Regular", size: 10))
                            .foregroundStyle(Color.nook.cardTitle)
                    }
                }
            }

            Spacer()

            // Rating
            HStack(spacing: 4) {
                Image("star-fill")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.nook.reviewRating)

                Text(String(format: "%.1f", item.rating))
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.reviewRating)
            }
        }
    }

    // MARK: - Body (review text)

    private var cardBody: some View {
        Text("\"\(item.body)\"")
            .font(.custom("PlusJakartaSans-Italic", size: 14))
            .foregroundStyle(Color.nook.reviewBody)
            .lineSpacing(6)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer (likes, comments)

    private var cardFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.nook.reviewBorder)

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
            .padding(.top, 10)
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
            body: "An absolute masterclass in visual storytelling. The third act left me completely speechless. Must watch on...",
            likes: "1.2k",
            comments: "48"
        ),
        ReviewItem(
            reviewerName: "Marcus",
            mediaTitle: "Solaris",
            rating: 8.7,
            body: "A slow burn that rewards patience. The cinematography alone makes it worth every minute.",
            likes: "842",
            comments: "31"
        ),
        ReviewItem(
            reviewerName: "Aria Chen",
            mediaTitle: "Neon Drift",
            rating: 9.1,
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
