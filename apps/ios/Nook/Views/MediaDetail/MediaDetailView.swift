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
    @State private var showTrackingSheet = false
    @State private var selectedStatus: TrackingStatus?
    @State private var currentEpisode: Int
    @State private var userScore: Int?

    init(media: MediaDetail) {
        self.media = media
        self._isTracking = State(initialValue: media.trackingStatus != nil)
        self._selectedStatus = State(initialValue: media.trackingStatus)
        self._currentEpisode = State(initialValue: media.currentEpisode)
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
        .sheet(isPresented: $showTrackingSheet) {
            TrackingSheetView(
                mediaTitle: media.title,
                totalEpisodes: media.totalEpisodes,
                selectedStatus: $selectedStatus,
                currentEpisode: $currentEpisode,
                userScore: $userScore,
                isTracking: $isTracking,
                isRated: $isRated
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
        .frame(height: 321)
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
        .frame(height: 321)
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

            navButton(icon: "export-bold") {
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
            sheetActionButton(
                activeIcon: "bookmark-simple-fill",
                inactiveIcon: "bookmark-simple",
                activeLabel: "Tracking",
                inactiveLabel: "Track",
                isActive: isTracking
            )

            sheetActionButton(
                activeIcon: "star-fill",
                inactiveIcon: "star",
                activeLabel: "Rated",
                inactiveLabel: "Rate",
                isActive: isRated
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
    func sheetActionButton(activeIcon: String, inactiveIcon: String, activeLabel: String, inactiveLabel: String, isActive: Bool) -> some View {
        let resolvedIcon = isActive ? activeIcon : inactiveIcon
        let resolvedLabel = isActive ? activeLabel : inactiveLabel
        let fgColor = isActive ? Color.nook.detailActionActiveLabel : Color.nook.detailTitle
        let labelColor = isActive ? Color.nook.detailActionActiveLabel : Color.nook.detailActionLabel

        Button {
            showTrackingSheet = true
        } label: {
            VStack(spacing: 6) {
                actionIcon(icon: resolvedIcon, isActive: isActive, fgColor: fgColor)

                Text(resolvedLabel)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundStyle(labelColor)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.nook.mutedForeground)
                        )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(review.reviewerName)
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.detailReviewTitle)

                        Text(review.timeAgo)
                            .font(.custom("PlusJakartaSans-Regular", size: 10))
                            .foregroundStyle(Color.nook.detailMeta)
                    }
                }

                Spacer()

                // Rating badge
                HStack(spacing: 2) {
                    Image("star-fill")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(Color.nook.detailRatingText)

                    Text(String(format: "%.1f", review.rating))
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
            .padding(.top, 21)
            .padding(.horizontal, 21)

            // Review title
            Text(review.title)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.detailReviewTitle)
                .padding(.top, 12)
                .padding(.horizontal, 21)

            // Review body
            Text("\"\(review.body)\"")
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.detailReviewBody)
                .lineSpacing(6)
                .padding(.top, 6)
                .padding(.horizontal, 21)

            // Footer: likes + comments
            HStack(spacing: 15) {
                HStack(spacing: 4) {
                    Image("heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.nook.detailMeta)

                    Text(review.likes)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.detailMeta)
                }

                HStack(spacing: 4) {
                    Image("chat-circle")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
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
            RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous)
                .fill(Color.nook.detailReviewCard)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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

// MARK: - Similar Tab

private extension MediaDetailView {
    var similarTab: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
            ],
            spacing: 24
        ) {
            ForEach(Self.mockSimilarItems) { item in
                similarCard(item)
            }
        }
        .padding(24)
        .padding(.bottom, 100)
    }

    func similarCard(_ item: SimilarItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))

                // Category badge
                Text(item.category.label)
                    .font(NookFont.tabLabel)
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(item.category.textColor)
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(item.category.backgroundColor)
                            .background(.ultraThinMaterial, in: Capsule())
                    )
                    .padding(10)
            }

            Text(item.title)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.detailTitle)
                .lineLimit(1)
                .padding(.top, 10)

            HStack(spacing: 4) {
                Image("star-fill")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.nook.detailRatingText)

                Text(String(format: "%.1f", item.rating))
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.detailRatingText)

                Text(item.year)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.detailMeta)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Similar Item Model

struct SimilarItem: Identifiable {
    let id = UUID()
    let title: String
    let category: LibraryMediaCategory
    let rating: Double
    let year: String
    let imageName: String
    let placeholderColor: Color?
}

extension MediaDetailView {
    static let mockSimilarItems: [SimilarItem] = [
        SimilarItem(
            title: "Whisper of the Wind",
            category: .anime,
            rating: 8.9,
            year: "2023",
            imageName: "mock-similar-1",
            placeholderColor: Color(hex: 0xB8D4E3)
        ),
        SimilarItem(
            title: "Starfall Chronicles",
            category: .anime,
            rating: 8.2,
            year: "2024",
            imageName: "mock-similar-2",
            placeholderColor: Color(hex: 0xE3C4A8)
        ),
        SimilarItem(
            title: "The Last Garden",
            category: .anime,
            rating: 9.1,
            year: "2023",
            imageName: "mock-similar-3",
            placeholderColor: Color(hex: 0xA8D5BA)
        ),
        SimilarItem(
            title: "Iron Bloom",
            category: .anime,
            rating: 7.8,
            year: "2024",
            imageName: "mock-similar-4",
            placeholderColor: Color(hex: 0xD4A8C4)
        ),
        SimilarItem(
            title: "Echoes of Silence",
            category: .anime,
            rating: 8.6,
            year: "2022",
            imageName: "mock-similar-5",
            placeholderColor: Color(hex: 0xC4C8E3)
        ),
        SimilarItem(
            title: "Dawnbreak",
            category: .anime,
            rating: 8.4,
            year: "2024",
            imageName: "mock-similar-6",
            placeholderColor: Color(hex: 0xE3D4A8)
        ),
    ]
}

// MARK: - Tracking Sheet

struct TrackingSheetView: View {
    let mediaTitle: String
    let totalEpisodes: Int
    @Binding var selectedStatus: TrackingStatus?
    @Binding var currentEpisode: Int
    @Binding var userScore: Int?
    @Binding var isTracking: Bool
    @Binding var isRated: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date = .now
    @State private var endDate: Date = .now

    private let statuses: [TrackingStatus] = [
        .inProgress, .completed, .planned, .onHold, .dropped,
    ]

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    statusSection
                    sectionDivider
                    progressSection
                    sectionDivider
                    scoreSection
                    sectionDivider
                    dateSection
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color.nook.detailBackground)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.detailMeta)

            Spacer()

            Text(mediaTitle)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.detailTitle)
                .lineLimit(1)

            Spacer()

            Button("Save") {
                isTracking = selectedStatus != nil || currentEpisode > 0
                isRated = userScore != nil
                dismiss()
            }
            .font(NookFont.labelBoldSmall)
            .foregroundStyle(Color.nook.detailTabActive)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.nook.detailTabBorder)
            .frame(height: 1)
            .padding(.horizontal, 24)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Status")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)

                Spacer()

                if let status = selectedStatus {
                    Text(status.label)
                        .font(NookFont.labelMediumSmall)
                        .foregroundStyle(Color.nook.detailMeta)
                }
            }

            FlowLayout(spacing: 10) {
                ForEach(statuses, id: \.self) { status in
                    statusChip(status)
                }
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private func statusChip(_ status: TrackingStatus) -> some View {
        let isSelected = selectedStatus == status

        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedStatus = selectedStatus == status ? nil : status
            }
        } label: {
            Text(status.label)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(isSelected ? .white : Color.nook.detailTitle)
                .padding(.horizontal, 20)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.nook.detailTabActive : .clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? .clear : Color.nook.detailTabBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Progress")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)

                Spacer()

                Text("Ep \(currentEpisode) / \(totalEpisodes)")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailMeta)
            }

            Picker("Episode", selection: $currentEpisode) {
                ForEach(0...totalEpisodes, id: \.self) { ep in
                    Text("\(ep)").tag(ep)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
        .padding(24)
    }

    // MARK: - Score Section

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Score")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)

                Spacer()

                Text(scoreSummary)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailMeta)
            }

            Picker("Score", selection: scoreBinding) {
                Text("–").tag(0)
                ForEach((1...10).reversed(), id: \.self) { score in
                    Text("\(score)").tag(score)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
        .padding(24)
    }

    private var scoreSummary: String {
        guard let score = userScore else { return "Not Yet Scored" }
        return "\(score) – \(scoreLabel(for: score))"
    }

    private func scoreLabel(for score: Int) -> String {
        switch score {
        case 10: "Masterpiece"
        case 9: "Excellent"
        case 8: "Great"
        case 7: "Good"
        case 6: "Decent"
        case 5: "Average"
        case 4: "Below Average"
        case 3: "Poor"
        case 2: "Terrible"
        case 1: "Appalling"
        default: "Not Yet Scored"
        }
    }

    private var scoreBinding: Binding<Int> {
        Binding(
            get: { userScore ?? 0 },
            set: { userScore = $0 == 0 ? nil : $0 }
        )
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Date")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)

                Spacer()

                Text(dateSummary)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailMeta)
            }

            VStack(spacing: 12) {
                dateRow(label: "Start Date", date: $startDate)
                dateRow(label: "Finish Date", date: $endDate)
            }
        }
        .padding(24)
    }

    private func dateRow(label: String, date: Binding<Date>) -> some View {
        DatePicker(
            label,
            selection: date,
            displayedComponents: .date
        )
        .font(NookFont.labelMediumSmall)
        .foregroundStyle(Color.nook.detailTitle)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.nook.detailTabBorder, lineWidth: 1)
        )
    }

    private var dateSummary: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
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
