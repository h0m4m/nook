import SwiftUI

// MARK: - Data Models

struct MediaDetail: Identifiable, Hashable {
    let id = UUID()

    static func == (lhs: MediaDetail, rhs: MediaDetail) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    let title: String
    let year: String
    let genres: String
    let episodeCount: String
    let category: LibraryMediaCategory
    let rating: Double
    let ratingCount: String
    let imageName: String
    let placeholderColor: Color?
    let synopsis: String
    let studio: String
    let director: String
    let status: String
    let airedDates: String
    let currentEpisode: Int
    let totalEpisodes: Int
    let trackingStatus: TrackingStatus?
    let reviews: [MediaReview]

    init(
        title: String,
        year: String,
        genres: String,
        episodeCount: String,
        category: LibraryMediaCategory,
        rating: Double,
        ratingCount: String,
        imageName: String,
        placeholderColor: Color? = nil,
        synopsis: String,
        studio: String,
        director: String,
        status: String,
        airedDates: String,
        currentEpisode: Int,
        totalEpisodes: Int,
        trackingStatus: TrackingStatus? = .inProgress,
        reviews: [MediaReview] = []
    ) {
        self.title = title
        self.year = year
        self.genres = genres
        self.episodeCount = episodeCount
        self.category = category
        self.rating = rating
        self.ratingCount = ratingCount
        self.imageName = imageName
        self.placeholderColor = placeholderColor
        self.synopsis = synopsis
        self.studio = studio
        self.director = director
        self.status = status
        self.airedDates = airedDates
        self.currentEpisode = currentEpisode
        self.totalEpisodes = totalEpisodes
        self.trackingStatus = trackingStatus
        self.reviews = reviews
    }

    var progress: Double {
        guard totalEpisodes > 0 else { return 0 }
        return Double(currentEpisode) / Double(totalEpisodes)
    }
}

struct MediaReview: Identifiable {
    let id = UUID()
    let reviewerName: String
    let timeAgo: String
    let rating: Double
    let title: String
    let body: String
    let likes: String
    let comments: String
}

// MARK: - Detail Tab

enum MediaDetailTab: String, CaseIterable, Identifiable {
    case about
    case reviews
    case clubs
    case similar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .about: "About"
        case .reviews: "Reviews"
        case .clubs: "Clubs"
        case .similar: "Similar"
        }
    }
}

// MARK: - Media Detail View

struct MediaDetailView: View {
    let media: MediaDetail
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: MediaDetailTab = .about
    @State private var dominantColor: Color?
    @State private var isTracking: Bool
    @State private var isRated = false
    @State private var isReviewed = false
    @State private var isInNook = false

    init(media: MediaDetail) {
        self.media = media
        self._isTracking = State(initialValue: media.trackingStatus != nil)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    contentCard
                }
            }
            .ignoresSafeArea(edges: [.top, .bottom])

            navigationButtons
        }
        .background(Color.nook.detailBackground.ignoresSafeArea())
        .background(
            VStack(spacing: 0) {
                overscrollColor
                    .frame(height: 400)
                Spacer(minLength: 0)
            }
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(SoftDetailScrollEdge())
        .task {
            let name = media.imageName
            let color = await Task.detached {
                Self.extractDominantColor(from: name)
            }.value
            dominantColor = color
        }
    }

    private var overscrollColor: Color {
        dominantColor ?? media.placeholderColor ?? Color.nook.foreground
    }

    nonisolated static func extractDominantColor(from imageName: String) -> Color? {
        guard let uiImage = UIImage(named: imageName),
              let cgImage = uiImage.cgImage else { return nil }

        // Sample from the top strip of the image for overscroll matching
        let width = cgImage.width
        let sampleHeight = min(cgImage.height / 4, 80)

        guard let cropped = cgImage.cropping(to: CGRect(x: 0, y: 0, width: width, height: sampleHeight)) else { return nil }

        let bitmapSize = 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: bitmapSize * bitmapSize * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: bitmapSize,
            height: bitmapSize,
            bitsPerComponent: 8,
            bytesPerRow: bitmapSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cropped, in: CGRect(x: 0, y: 0, width: bitmapSize, height: bitmapSize))

        var totalR: Double = 0
        var totalG: Double = 0
        var totalB: Double = 0
        let pixelCount = bitmapSize * bitmapSize

        for i in 0..<pixelCount {
            let offset = i * 4
            totalR += Double(pixelData[offset])
            totalG += Double(pixelData[offset + 1])
            totalB += Double(pixelData[offset + 2])
        }

        return Color(
            red: totalR / Double(pixelCount) / 255.0,
            green: totalG / Double(pixelCount) / 255.0,
            blue: totalB / Double(pixelCount) / 255.0
        )
    }
}

// MARK: - Hero Section

private extension MediaDetailView {
    var heroSection: some View {
        ZStack(alignment: .top) {
            heroImage
            heroGradient
        }
        .frame(height: 320)
    }

    var heroImage: some View {
        Group {
            if let color = media.placeholderColor {
                color
            } else {
                Image(media.imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipped()
    }

    var heroGradient: some View {
        EmptyView()
    }

    var navigationButtons: some View {
        HStack {
            navButton(icon: "caret-left-bold") {
                dismiss()
            }

            Spacer()

            navButton(icon: "dots-three-bold") {
                // TODO: More options
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    func navButton(icon: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: action) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Content Card

private extension MediaDetailView {
    var contentCard: some View {
        VStack(spacing: 0) {
            mediaInfo
                .padding(.top, 32)
                .padding(.horizontal, 24)

            progressCard
                .padding(.top, 24)
                .padding(.horizontal, 24)

            actionButtons
                .padding(.top, 8)
                .padding(.horizontal, 24)

            tabBar
                .padding(.top, 12)

            tabContent
        }
        .background(
            Color.nook.detailBackground
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: NookRadii.lg,
                        topTrailingRadius: NookRadii.lg
                    )
                )
                .shadow(color: .black.opacity(0.05), radius: 15, y: -8)
        )
        .offset(y: -32)
    }
}

// MARK: - Media Info (badge, rating, title, metadata)

private extension MediaDetailView {
    var mediaInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category badge + rating row
            HStack(spacing: 8) {
                categoryBadge
                ratingDisplay
                Spacer()
            }

            // Title
            Text(media.title)
                .font(NookFont.headingMediumBold)
                .foregroundStyle(Color.nook.detailTitle)
                .padding(.top, 12)

            // Metadata row
            metadataRow
                .padding(.top, 8)
        }
    }

    var categoryBadge: some View {
        Text(media.category.label)
            .font(NookFont.tabLabel)
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(media.category.textColor)
            .padding(.horizontal, 8.5)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6.39, style: .continuous)
                    .fill(media.category.backgroundColor)
            )
    }

    var ratingDisplay: some View {
        HStack(spacing: 2) {
            Image("star-fill")
                .renderingMode(.template)
                .resizable()
                .frame(width: 10, height: 10)
                .foregroundStyle(Color.nook.detailRatingText)

            Text(String(format: "%.1f", media.rating))
                .font(NookFont.captionBold)
                .foregroundStyle(Color.nook.detailRatingText)

            Text("(\(media.ratingCount))")
                .font(.custom("PlusJakartaSans-Regular", size: 10))
                .foregroundStyle(Color.nook.detailRatingText.opacity(0.7))
        }
        .padding(.horizontal, 6.5)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6.39, style: .continuous)
                .fill(Color.nook.detailRatingBadge)
        )
    }

    var metadataRow: some View {
        HStack(spacing: 0) {
            Text(media.year)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.detailMeta)

            metaDot

            Text(media.genres)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.detailMeta)

            metaDot

            Text(media.episodeCount)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.detailMeta)
        }
    }

    var metaDot: some View {
        Circle()
            .fill(Color.nook.detailMetaDot)
            .frame(width: 4, height: 4)
            .padding(.horizontal, 8)
    }
}

// MARK: - Progress Card

private extension MediaDetailView {
    var progressCard: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Your Progress")
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.detailTitle)

                Spacer()

                HStack(spacing: 0) {
                    Text("Ep \(media.currentEpisode)")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(Color.nook.detailTabActive)

                    Text(" / \(media.totalEpisodes)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.detailMeta)
                }
            }
            .padding(.top, 17)
            .padding(.horizontal, 17)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .fill(Color.nook.detailProgressBackground)

                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .fill(Color.nook.detailTabActive)
                        .frame(width: geo.size.width * media.progress)
                }
            }
            .frame(height: 8)
            .padding(.top, 12)
            .padding(.horizontal, 17)

            // Bottom row
            HStack {
                Spacer()

                if let status = media.trackingStatus {
                    Button {
                        // TODO: Update progress
                    } label: {
                        HStack(spacing: 6) {
                            Image("pencil-simple")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                                .foregroundStyle(.white)

                            Text(status == .completed ? "Completed" : "In Progress")
                                .font(NookFont.captionBold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10.5)
                        .padding(.vertical, 6.5)
                        .background(
                            RoundedRectangle(cornerRadius: 7.78, style: .continuous)
                                .fill(Color.nook.detailTabActive)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 17)
            .padding(.bottom, 17)
        }
        .background(
            RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                .fill(Color.nook.detailProgressCard)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                        .strokeBorder(Color.nook.detailProgressCardBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Action Buttons

private extension MediaDetailView {
    var actionButtons: some View {
        HStack(spacing: 0) {
            actionButton(
                activeIcon: "bookmark-simple-fill",
                inactiveIcon: "bookmark-simple",
                activeLabel: "Tracking",
                inactiveLabel: "Track",
                isActive: $isTracking
            )

            actionButton(
                activeIcon: "star-fill",
                inactiveIcon: "star",
                activeLabel: "Rated",
                inactiveLabel: "Rate",
                isActive: $isRated
            )

            actionButton(
                activeIcon: "pencil-line-fill",
                inactiveIcon: "pencil-line",
                activeLabel: "Reviewed",
                inactiveLabel: "Review",
                isActive: $isReviewed
            )

            actionButton(
                activeIcon: "folders-fill",
                inactiveIcon: "folders",
                activeLabel: "In Nook",
                inactiveLabel: "Add to Nook",
                isActive: $isInNook
            )
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    func actionButton(activeIcon: String, inactiveIcon: String, activeLabel: String, inactiveLabel: String, isActive: Binding<Bool>) -> some View {
        let active = isActive.wrappedValue
        let resolvedIcon = active ? activeIcon : inactiveIcon
        let resolvedLabel = active ? activeLabel : inactiveLabel
        let fgColor = active ? Color.nook.detailActionActiveLabel : Color.nook.detailTitle
        let labelColor = active ? Color.nook.detailActionActiveLabel : Color.nook.detailActionLabel

        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                isActive.wrappedValue.toggle()
            }
        } label: {
            VStack(spacing: 6) {
                actionIcon(icon: resolvedIcon, isActive: active, fgColor: fgColor)

                Text(resolvedLabel)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundStyle(labelColor)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func actionIcon(icon: String, isActive: Bool, fgColor: Color) -> some View {
        let bgColor = isActive ? Color.nook.detailActionActive : Color.nook.detailActionBackground

        if #available(iOS 26, *) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(fgColor)
                .frame(width: 48, height: 48)
                .background(bgColor, in: Circle())
                .glassEffect(isActive ? .regular : .regular.interactive(), in: .circle)
        } else {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(fgColor)
                .frame(width: 48, height: 48)
                .background(bgColor)
                .clipShape(Circle())
        }
    }
}

// MARK: - Tab Bar

private extension MediaDetailView {
    var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(MediaDetailTab.allCases) { tab in
                    tabButton(tab)
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)
        }
    }

    func tabButton(_ tab: MediaDetailTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 0) {
                Text(tab.label)
                    .font(isSelected ? NookFont.labelBoldSmall : NookFont.labelMediumSmall)
                    .foregroundStyle(
                        isSelected ? Color.nook.detailTabActive : Color.nook.detailTabInactive
                    )
                    .padding(.vertical, 8)

                Rectangle()
                    .fill(isSelected ? Color.nook.detailTabActive : .clear)
                    .frame(height: 2)
            }
            .padding(.trailing, 24)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Content

private extension MediaDetailView {
    @ViewBuilder
    var tabContent: some View {
        switch selectedTab {
        case .about:
            aboutTab
        case .reviews:
            reviewsTab
        case .clubs:
            clubsTab
        case .similar:
            similarTab
        }
    }
}

// MARK: - About Tab

private extension MediaDetailView {
    var aboutTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Synopsis
            VStack(alignment: .leading, spacing: 8) {
                Text("Synopsis")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)

                Text(media.synopsis)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(Color.nook.detailMeta)
                    .lineSpacing(6)
            }

            // Details grid
            VStack(alignment: .leading, spacing: 16) {
                Text("Details")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)

                detailRow(label: "Studio", value: media.studio)
                detailRow(label: "Director", value: media.director)
                detailRow(label: "Status", value: media.status)
                detailRow(label: "Aired", value: media.airedDates)
                detailRow(label: "Episodes", value: "\(media.totalEpisodes)")
                detailRow(label: "Genre", value: media.genres)
            }
        }
        .padding(24)
        .padding(.bottom, 100)
    }

    func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.detailMeta)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.detailTitle)
        }
    }
}

// MARK: - Reviews Tab

private extension MediaDetailView {
    var reviewsTab: some View {
        VStack(spacing: 16) {
            ForEach(media.reviews) { review in
                reviewCard(review)
            }

            viewAllReviewsButton
        }
        .padding(24)
        .padding(.bottom, 100)
    }

    func reviewCard(_ review: MediaReview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: avatar + name/time + rating
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.nook.secondary)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.nook.mutedForeground)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.reviewerName)
                            .font(NookFont.labelBoldSmall)
                            .foregroundStyle(Color.nook.detailReviewTitle)

                        Text(review.timeAgo)
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.detailMeta)
                    }
                }

                Spacer()

                // Rating badge
                HStack(spacing: 2) {
                    Image("star-fill")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.nook.detailRatingText)

                    Text(String(format: "%.1f", review.rating))
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(Color.nook.detailRatingText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7.78, style: .continuous)
                        .fill(Color.nook.detailRatingBadge)
                )
            }
            .padding(.top, 21)
            .padding(.horizontal, 21)

            // Review title
            Text(review.title)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.detailReviewTitle)
                .padding(.top, 12)
                .padding(.horizontal, 21)

            // Review body
            Text("\"\(review.body)\"")
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.detailReviewBody)
                .lineSpacing(9)
                .padding(.top, 8)
                .padding(.horizontal, 21)

            // Footer: likes + comments
            HStack(spacing: 15) {
                HStack(spacing: 5) {
                    Image("heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.nook.detailMeta)

                    Text(review.likes)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.detailMeta)
                }

                HStack(spacing: 5) {
                    Image("chat-circle")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.nook.detailMeta)

                    Text(review.comments)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.detailMeta)
                }

                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 21)
            .padding(.bottom, 21)
        }
        .background(
            RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                .fill(Color.nook.detailReviewCard)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                        .strokeBorder(Color.nook.detailReviewCardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 1.5, y: 0.5)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
        )
    }

    var viewAllReviewsButton: some View {
        Button {
            // TODO: View all reviews
        } label: {
            Text("View all 4,201 reviews")
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.detailViewAllText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12.22, style: .continuous)
                        .fill(Color.nook.detailViewAllButton)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clubs Tab (Placeholder)

private extension MediaDetailView {
    var clubsTab: some View {
        VStack(spacing: 16) {
            Text("Clubs discussing this media")
                .font(NookFont.label)
                .foregroundStyle(Color.nook.detailMeta)
                .frame(maxWidth: .infinity, minHeight: 200)
        }
        .padding(24)
        .padding(.bottom, 100)
    }
}

// MARK: - Similar Tab (Placeholder)

private extension MediaDetailView {
    var similarTab: some View {
        VStack(spacing: 16) {
            Text("Similar titles")
                .font(NookFont.label)
                .foregroundStyle(Color.nook.detailMeta)
                .frame(maxWidth: .infinity, minHeight: 200)
        }
        .padding(24)
        .padding(.bottom, 100)
    }
}

// MARK: - Scroll Edge

private struct SoftDetailScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - Mock Data

extension MediaDetailView {
    static let mockMedia = MediaDetail(
        title: "The Cloud Weaver",
        year: "2024",
        genres: "Fantasy, Adventure",
        episodeCount: "24 Episodes",
        category: .anime,
        rating: 8.5,
        ratingCount: "12.4k",
        imageName: "mock-cloud-weaver",
        placeholderColor: Color(hex: 0x87CEEB),
        synopsis: "In a world where the sky holds ancient memories, a young weaver discovers she can pull threads from the clouds to reshape reality. But as she unravels the fabric of the heavens, she awakens forces that have slumbered for centuries. With allies from rival guilds and enemies hiding in plain sight, she must learn to control her gift before the sky falls silent forever.",
        studio: "Studio Ghibli",
        director: "Hayao Miyazaki",
        status: "Airing",
        airedDates: "Jan 2024 – Present",
        currentEpisode: 12,
        totalEpisodes: 24,
        trackingStatus: .inProgress,
        reviews: [
            MediaReview(
                reviewerName: "Elena Vance",
                timeAgo: "2 days ago",
                rating: 9.5,
                title: "An absolute masterpiece.",
                body: "The third act left me completely speechless. The world-building is unparalleled and the emotional payoff is entirely earned. Must watch for any fantasy fan.",
                likes: "1.2k",
                comments: "48"
            ),
            MediaReview(
                reviewerName: "Marcus Chen",
                timeAgo: "1 week ago",
                rating: 8.0,
                title: "Beautiful but slow pacing",
                body: "The animation is arguably some of the best I've seen this year. However, the middle episodes drag a bit. Still, the characters carry it through.",
                likes: "842",
                comments: "12"
            ),
        ]
    )
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MediaDetailView(media: MediaDetailView.mockMedia)
    }
}
