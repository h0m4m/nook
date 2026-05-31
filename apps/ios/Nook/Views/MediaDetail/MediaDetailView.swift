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
    let genres: String        // Truncated (≤2) for hero subtext
    let genresFull: String    // Full list for details tab
    let episodeCount: String
    let category: LibraryMediaCategory
    let rating: Double
    let ratingCount: String
    let imageName: String
    let imageURL: URL?
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
    let dbId: UUID?

    init(
        title: String,
        year: String,
        genres: String,
        genresFull: String = "",
        episodeCount: String,
        category: LibraryMediaCategory,
        rating: Double,
        ratingCount: String,
        imageName: String,
        imageURL: URL? = nil,
        placeholderColor: Color? = nil,
        synopsis: String,
        studio: String,
        director: String,
        status: String,
        airedDates: String,
        currentEpisode: Int,
        totalEpisodes: Int,
        trackingStatus: TrackingStatus? = .inProgress,
        reviews: [MediaReview] = [],
        dbId: UUID? = nil
    ) {
        self.title = title
        self.year = year
        self.genres = genres
        self.genresFull = genresFull.isEmpty ? genres : genresFull
        self.episodeCount = episodeCount
        self.category = category
        self.rating = rating
        self.ratingCount = ratingCount
        self.imageName = imageName
        self.imageURL = imageURL
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
        self.dbId = dbId
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

    /// Convert to a `ReviewItem` for navigating to the review detail page.
    func toReviewItem(mediaTitle: String) -> ReviewItem {
        ReviewItem(
            reviewerName: reviewerName,
            mediaTitle: mediaTitle,
            rating: rating,
            title: title,
            body: body,
            likes: likes,
            comments: comments
        )
    }
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
    /// When true, shimmer placeholders are shown for content that hasn't loaded yet.
    var isLoading: Bool = false
    /// Called when the user saves tracking. Passes the media's sourceId (or dbId string).
    var onTracked: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: MediaDetailTab = .about
    @State private var dominantColor: Color?
    @State private var isTracking: Bool
    @State private var isRated = false
    @State private var isReviewed = false
    @State private var isInNook = false
    @State private var showTrackingSheet = false
    @State private var showReviewSheet = false
    @State private var selectedStatus: TrackingStatus?
    @State private var currentEpisode: Int
    @State private var userScore: Int?
    @State private var reviewRating: Int = 0
    @State private var reviewTitle: String = ""
    @State private var reviewBody: String = ""
    @State private var containsSpoilers: Bool = false
    @State private var loadedReviews: [Review] = []
    @State private var isLoadingReviews = false

    init(media: MediaDetail, isLoading: Bool = false, onTracked: (() -> Void)? = nil) {
        self.media = media
        self.isLoading = isLoading
        self.onTracked = onTracked
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
        .modifier(InteractivePopGesture())
        .modifier(SoftDetailScrollEdge())
        .task {
            if let url = media.imageURL {
                let color = await Task.detached {
                    await Self.extractDominantColor(fromURL: url)
                }.value
                dominantColor = color
            } else if !media.imageName.isEmpty {
                let name = media.imageName
                let color = await Task.detached {
                    Self.extractDominantColor(from: name)
                }.value
                dominantColor = color
            }

            // Check if already tracking this media
            await loadExistingTracking()
        }
        .sheet(isPresented: $showTrackingSheet, onDismiss: {
            persistTracking()
        }) {
            TrackingSheetView(
                mediaTitle: media.title,
                totalEpisodes: media.totalEpisodes,
                category: media.category,
                selectedStatus: $selectedStatus,
                currentEpisode: $currentEpisode,
                userScore: $userScore,
                isTracking: $isTracking,
                isRated: $isRated
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.nook.detailBackground)
        }
        .sheet(isPresented: $showReviewSheet, onDismiss: {
            Task { await loadReviews() }
        }) {
            ReviewSheetView(
                media: media,
                rating: $reviewRating,
                title: $reviewTitle,
                reviewText: $reviewBody,
                containsSpoilers: $containsSpoilers,
                isReviewed: $isReviewed
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.nook.detailBackground)
        }
    }

    private var overscrollColor: Color {
        dominantColor ?? media.placeholderColor ?? Color.nook.foreground
    }

    nonisolated static func extractDominantColor(fromURL url: URL) async -> Color? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return nil }
        return extractDominantColorFromCGImage(cgImage)
    }

    nonisolated static func extractDominantColor(from imageName: String) -> Color? {
        guard let uiImage = UIImage(named: imageName),
              let cgImage = uiImage.cgImage else { return nil }
        return extractDominantColorFromCGImage(cgImage)
    }

    private var progressLabel: String {
        switch media.category {
        case .book: "Pages"
        case .manga: "Chapters"
        case .movie: "Runtime"
        default: "Episodes"
        }
    }

    private var studioLabel: String {
        switch media.category {
        case .book: "Author"
        case .manga: "Author"
        case .game: "Developer"
        default: "Studio"
        }
    }

    /// Short label used in the progress card counter (e.g. "Ep 1", "Pg 142")
    private var progressCountLabel: String {
        switch media.category {
        case .book: "Pg \(currentEpisode)"
        case .manga: "Ch \(currentEpisode)"
        case .movie: currentEpisode > 0 ? "Watched" : "Not watched"
        default: "Ep \(currentEpisode)"
        }
    }

    private func loadExistingTracking() async {
        guard let dbId = media.dbId,
              let userId = try? await supabase.auth.session.user.id else { return }
        let service = TrackingService()
        if let existing = try? await service.getTrackingForMedia(userId: userId, mediaItemId: dbId) {
            selectedStatus = TrackingStatus.from(dbValue: existing.status)
            currentEpisode = existing.progress
            userScore = existing.score.map { Int($0) }
            isTracking = true
            isRated = existing.score != nil
        }
    }

    private func persistTracking() {
        guard isTracking, let status = selectedStatus, let dbId = media.dbId else { return }
        onTracked?()
        Task {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            let service = TrackingService()
            try? await service.track(
                userId: userId,
                mediaItemId: dbId,
                status: status.dbValue,
                progress: currentEpisode,
                score: userScore.map { Double($0) }
            )
        }
    }

    nonisolated static func extractDominantColorFromCGImage(_ cgImage: CGImage) -> Color? {
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
    }

    var heroImage: some View {
        Group {
            if let url = media.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fit)
                    case .failure:
                        Color.nook.foreground
                            .aspectRatio(2/3, contentMode: .fit)
                    case .empty:
                        Color.nook.foreground
                            .aspectRatio(2/3, contentMode: .fit)
                    @unknown default:
                        Color.nook.foreground
                            .aspectRatio(2/3, contentMode: .fit)
                    }
                }
            } else if !media.imageName.isEmpty {
                Image(media.imageName)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fit)
            } else {
                Color.nook.foreground
                    .aspectRatio(2/3, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
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

            navButton(icon: "export") {
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
                    .contentShape(Circle())
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
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
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
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

            if isLoading {
                loadingContentSkeleton
            } else {
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

    /// Shimmer placeholders shown while full detail is loading.
    var loadingContentSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress card shimmer
            RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                .fill(Color.nook.searchShimmerBase)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .opacity(0.4)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            // Action buttons shimmer
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(Color.nook.searchShimmerBase)
                            .frame(width: 48, height: 48)
                            .opacity(0.4)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.nook.searchShimmerBase)
                            .frame(width: 36, height: 10)
                            .opacity(0.4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)

            // Synopsis shimmer
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(maxWidth: i == 4 ? 180 : .infinity)
                        .frame(height: 13)
                        .opacity(0.4)
                }
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Media Info (badge, rating, title, metadata)

private extension MediaDetailView {
    var mediaInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category badge + rating row
            HStack(spacing: 8) {
                if isLoading {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: 60, height: 24)
                        .opacity(0.6)
                } else {
                    categoryBadge
                    if media.rating > 0 {
                        ratingDisplay
                    }
                }
                Spacer()
            }

            // Title — shown immediately from route preview data
            Text(media.title)
                .font(NookFont.headingMediumBold)
                .foregroundStyle(Color.nook.detailTitle)
                .padding(.top, 12)

            // Metadata row
            if isLoading {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.nook.searchShimmerBase)
                    .frame(width: 160, height: 12)
                    .opacity(0.5)
                    .padding(.top, 10)
            } else {
                metadataRow
                    .padding(.top, 8)
            }
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
        // Build non-empty parts: year, genres (if present), episode count (non-movies only)
        let parts: [String] = {
            var p: [String] = []
            if !media.year.isEmpty { p.append(media.year) }
            if !media.genres.isEmpty { p.append(media.genres) }
            if media.category != .movie, !media.episodeCount.isEmpty {
                p.append(media.episodeCount)
            }
            return p
        }()

        return HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                Text(part)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailMeta)
                if index < parts.count - 1 {
                    metaDot
                }
            }
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
        let progress: Double = media.totalEpisodes > 0
            ? Double(currentEpisode) / Double(media.totalEpisodes)
            : 0

        return VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Your Progress")
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.detailTitle)

                Spacer()

                Group {
                    if media.category == .movie {
                        Text(progressCountLabel)
                            .font(NookFont.labelBoldSmall)
                            .foregroundStyle(Color.nook.detailTabActive)
                    } else {
                        HStack(spacing: 0) {
                            Text(progressCountLabel)
                                .font(NookFont.labelBoldSmall)
                                .foregroundStyle(Color.nook.detailTabActive)

                            if media.totalEpisodes > 0 {
                                Text(" / \(media.totalEpisodes)")
                                    .font(NookFont.caption)
                                    .foregroundStyle(Color.nook.detailMeta)
                            }
                        }
                    }
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
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
            .padding(.top, 12)
            .padding(.horizontal, 17)

            // Bottom row
            HStack {
                Spacer()

                if let status = selectedStatus {
                    Button {
                        showTrackingSheet = true
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

            reviewSheetButton

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

    private var reviewSheetButton: some View {
        let active = isReviewed
        let icon = active ? "pencil-line-fill" : "pencil-line"
        let label = active ? "Reviewed" : "Review"
        let fgColor = active ? Color.nook.detailActionActiveLabel : Color.nook.detailTitle
        let labelColor = active ? Color.nook.detailActionActiveLabel : Color.nook.detailActionLabel

        return Button {
            showReviewSheet = true
        } label: {
            VStack(spacing: 6) {
                actionIcon(icon: icon, isActive: active, fgColor: fgColor)

                Text(label)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundStyle(labelColor)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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

                detailRow(label: studioLabel, value: media.studio)
                detailRow(label: "Director", value: media.director)
                detailRow(label: "Status", value: media.status)
                detailRow(label: "Aired", value: media.airedDates)
                if media.category != .movie {
                    detailRow(label: progressLabel, value: media.episodeCount)
                }
                detailRow(label: "Genre", value: media.genresFull)
            }
        }
        .padding(24)
        .padding(.bottom, 100)
    }

    @ViewBuilder
    func detailRow(label: String, value: String) -> some View {
        if !value.isEmpty {
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
}

// MARK: - Reviews Tab

private extension MediaDetailView {
    var reviewsTab: some View {
        VStack(spacing: 16) {
            if isLoadingReviews {
                ForEach(0..<3, id: \.self) { _ in
                    SearchShimmerRow()
                }
            } else if loadedReviews.isEmpty {
                VStack(spacing: 12) {
                    Text("No reviews yet")
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.detailMeta)
                    Text("Be the first to review this")
                        .font(NookFont.bodySmall)
                        .foregroundStyle(Color.nook.detailMeta.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(loadedReviews) { review in
                    NavigationLink(value: ReviewItem(
                        reviewerName: review.authorName,
                        mediaTitle: media.title,
                        rating: review.rating,
                        title: review.title ?? "",
                        body: review.body,
                        likes: "\(review.likesCount)",
                        comments: "0"
                    )) {
                        loadedReviewCard(review)
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(24)
        .padding(.bottom, 100)
        .task {
            await loadReviews()
        }
    }

    private func loadReviews() async {
        guard let dbId = media.dbId else { return }
        isLoadingReviews = true
        let service = ReviewService()
        loadedReviews = (try? await service.getReviewsForMedia(mediaItemId: dbId)) ?? []
        isLoadingReviews = false
    }

    func loadedReviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    AsyncImage(url: review.authorAvatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle()
                                .fill(Color.nook.secondary)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.nook.mutedForeground)
                                )
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 0) {
                        Text(review.authorName)
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.detailReviewTitle)

                        Text(review.createdAt, style: .relative)
                            .font(.custom("PlusJakartaSans-Regular", size: 10))
                            .foregroundStyle(Color.nook.detailMeta)
                    }
                }

                Spacer()

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

            if review.isSpoiler {
                Text("⚠ Contains spoilers")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.accent)
                    .padding(.top, 8)
            }

            if let title = review.title, !title.isEmpty {
                Text(title)
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailReviewTitle)
                    .padding(.top, 12)
            }

            Text(review.body)
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.detailReviewBody)
                .lineSpacing(4)
                .lineLimit(4)
                .padding(.top, 8)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image("heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 14, height: 14)
                    Text("\(review.likesCount)")
                        .font(NookFont.caption)
                }
                .foregroundStyle(Color.nook.detailMeta)

                Spacer()
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                .stroke(Color.nook.detailTabBorder, lineWidth: 1)
        }
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

}

// MARK: - Clubs Tab

private extension MediaDetailView {
    var clubsTab: some View {
        tabEmptyState(
            title: "No clubs yet",
            subtitle: "Clubs discussing this title will appear here"
        )
    }
}

// MARK: - Similar Tab

private extension MediaDetailView {
    var similarTab: some View {
        tabEmptyState(
            title: "No recommendations yet",
            subtitle: "Similar titles will appear here once available"
        )
    }
}

// MARK: - Tab Empty State

private extension MediaDetailView {
    func tabEmptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.detailMeta)
            Text(subtitle)
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.detailMeta.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
        .padding(.bottom, 100)
    }
}

// MARK: - Tracking Sheet

struct TrackingSheetView: View {
    let mediaTitle: String
    let totalEpisodes: Int
    let category: LibraryMediaCategory
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

    private var progressCountLabel: String {
        switch category {
        case .book: "Pg \(currentEpisode)"
        case .manga: "Ch \(currentEpisode)"
        case .movie: currentEpisode > 0 ? "Watched" : "Not watched"
        default: "Ep \(currentEpisode)"
        }
    }

    private var progressHeaderLabel: String {
        if category == .movie { return progressCountLabel }
        if totalEpisodes == 0 { return "\(progressCountLabel) / ?" }
        return "\(progressCountLabel) / \(totalEpisodes)"
    }

    private var progressNumberField: some View {
        HStack {
            Button {
                if currentEpisode > 0 { currentEpisode -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.nook.detailTitle)
            }
            .buttonStyle(.plain)

            Spacer()

            TextField("0", value: $currentEpisode, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.detailTitle)
                .frame(width: 80)

            Spacer()

            Button {
                currentEpisode += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.nook.detailTitle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 120)
    }

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
        .onAppear {
            if selectedStatus == nil {
                selectedStatus = .planned
            }
        }
        .onChange(of: currentEpisode) { _, newEpisode in
            withAnimation(.easeOut(duration: 0.2)) {
                if totalEpisodes > 0 && newEpisode >= totalEpisodes {
                    selectedStatus = .completed
                } else if newEpisode > 0 && (selectedStatus == .planned || selectedStatus == nil) {
                    selectedStatus = .inProgress
                } else if newEpisode == 0 && selectedStatus == .inProgress {
                    selectedStatus = .planned
                }
            }
        }
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
                let newStatus = selectedStatus == status ? nil : status
                selectedStatus = newStatus

                if totalEpisodes > 0 {
                    if newStatus == .completed {
                        currentEpisode = totalEpisodes
                    } else if newStatus == .planned || newStatus == nil {
                        currentEpisode = 0
                    }
                }
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

                Text(progressHeaderLabel)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailMeta)
            }

            if category == .movie {
                Picker("Watched", selection: $currentEpisode) {
                    Text("Not watched").tag(0)
                    Text("Watched").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            } else if totalEpisodes > 0 {
                Picker("Episode", selection: $currentEpisode) {
                    ForEach(0...totalEpisodes, id: \.self) { ep in
                        Text("\(ep)").tag(ep)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            } else {
                progressNumberField
            }
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

// MARK: - Review Sheet

struct ReviewSheetView: View {
    let media: MediaDetail
    @Binding var rating: Int
    @Binding var title: String
    @Binding var reviewText: String
    @Binding var containsSpoilers: Bool
    @Binding var isReviewed: Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: ReviewField?
    @State private var richText: AttributedString = ""
    @State private var formatter: RichTextFormatterProtocol = {
        if #available(iOS 26, *) {
            return RichTextFormatter()
        } else {
            return PlainTextFormatter()
        }
    }()

    enum ReviewField {
        case title, reviewBody
    }

    private var isWriting: Bool {
        focusedField != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                reviewHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        mediaCard
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                            .frame(maxHeight: isWriting ? 0 : nil)
                            .clipped()
                            .opacity(isWriting ? 0 : 1)

                        ratingSection
                            .padding(.top, isWriting ? 0 : 28)
                            .padding(.horizontal, 16)
                            .frame(maxHeight: isWriting ? 0 : nil)
                            .clipped()
                            .opacity(isWriting ? 0 : 1)

                        reviewFields
                            .padding(.top, isWriting ? 16 : 28)
                            .padding(.horizontal, 16)
                    }
                    .animation(.easeOut(duration: 0.2), value: isWriting)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)

                formattingToolbar
                    .frame(maxHeight: isWriting ? 0 : nil)
                    .clipped()
                    .opacity(isWriting ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: isWriting)
            }
            .background(Color.nook.detailBackground)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    keyboardToolbar
                }
            }
        }
    }

    // MARK: - Header

    private var reviewHeader: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.detailTitle)
                    .frame(width: 36, height: 36)
                    .background(Color.nook.card)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                // TODO: Save draft
            } label: {
                Text("Save Draft")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailTitle)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(Color.nook.card)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.nook.detailTabBorder, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    if let dbId = media.dbId, (!reviewText.isEmpty || rating > 0) {
                        let service = ReviewService()
                        try? await service.createReview(
                            mediaItemId: dbId,
                            title: title.isEmpty ? nil : title,
                            body: reviewText.isEmpty ? "No text" : reviewText,
                            rating: Double(rating),
                            isSpoiler: containsSpoilers
                        )
                    }
                    isReviewed = !reviewText.isEmpty || rating > 0
                    dismiss()
                }
            } label: {
                Text("Publish")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(Color.nook.primary)
                            .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Media Card

    private var mediaCard: some View {
        HStack(spacing: 13) {
            Group {
                if let url = media.imageURL {
                    MediaPosterImage(url: url, width: 64, height: 90)
                } else if let color = media.placeholderColor {
                    color
                        .frame(width: 64, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 17.78, style: .continuous))
                } else if !media.imageName.isEmpty {
                    Image(media.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 17.78, style: .continuous))
                } else {
                    Color.nook.searchShimmerBase
                        .frame(width: 64, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 17.78, style: .continuous))
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 1.5, y: 0.5)

            VStack(alignment: .leading, spacing: 0) {
                Text(media.title)
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)
                    .lineLimit(1)

                HStack(spacing: 2) {
                    Image("star-fill")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(Color.nook.detailRatingText)

                    Text("\(String(format: "%.1f", media.rating)) / 10 Avg")
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.detailRatingText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.nook.detailRatingBadge)
                )
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                .fill(Color.nook.card)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                        .strokeBorder(Color.nook.detailProgressCardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(spacing: 16) {
            Text("YOUR RATING")
                .font(NookFont.labelSmall)
                .tracking(0.7)
                .foregroundStyle(Color.nook.detailMeta)

            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.nook.primary)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.nook.primary.opacity(0.1), radius: 7.5, y: 5)
                            .shadow(color: Color.nook.primary.opacity(0.1), radius: 3)

                        Text(rating > 0 ? "\(rating)" : "–")
                            .font(NookFont.outfitHeadingSmall)
                            .foregroundStyle(.white)
                    }

                    Text(ratingLabel)
                        .font(NookFont.tabLabel)
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.nook.detailTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 68)

                Slider(
                    value: Binding(
                        get: { Double(rating) },
                        set: { rating = Int($0.rounded()) }
                    ),
                    in: 0...10,
                    step: 1
                )
                .tint(Color.nook.primary)

                Text("10")
                    .font(NookFont.outfitHeadingSmall)
                    .foregroundStyle(Color.nook.detailMeta.opacity(0.3))
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 10: "Masterpiece"
        case 9: "Excellent"
        case 8: "Great"
        case 7: "Good"
        case 6: "Decent"
        case 5: "Average"
        case 4: "Below Avg"
        case 3: "Poor"
        case 2: "Terrible"
        case 1: "Appalling"
        default: "Not Rated"
        }
    }

    // MARK: - Review Fields

    private var reviewFields: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                TextField(
                    "Review Title (Optional)",
                    text: $title
                )
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.detailTitle)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .reviewBody
                }

                Rectangle()
                    .fill(Color.nook.detailTabBorder)
                    .frame(height: 1)
                    .padding(.top, 12)
            }

            richTextEditor
        }
    }

    @ViewBuilder
    private var richTextEditor: some View {
        if #available(iOS 26, *), let richFormatter = formatter as? RichTextFormatter {
            RichTextEditorView(
                formatter: richFormatter,
                reviewText: $reviewText,
                focusedField: $focusedField
            )
        } else {
            ZStack(alignment: .topLeading) {
                if reviewText.isEmpty {
                    Text("Share your thoughts...")
                        .font(NookFont.label)
                        .foregroundStyle(Color.nook.detailMeta)
                        .padding(.top, 16)
                        .onTapGesture {
                            focusedField = .reviewBody
                        }
                }

                TextEditor(text: $reviewText)
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.detailTitle)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .reviewBody)
                    .frame(minHeight: 200)
                    .padding(.top, 8)
                    .padding(.leading, -5)
            }
        }
    }

    // MARK: - Formatting Toolbar (floating bar)

    private var formattingToolbar: some View {
        HStack(spacing: 4) {
            toolbarIcon(icon: "bold", isSystem: true, isActive: isBold) {
                toggleBold()
            }
            toolbarIcon(icon: "text-italic-bold", isSystem: false, isActive: isItalic) {
                toggleItalic()
            }
            toolbarIcon(icon: "quotes-bold", isSystem: false, isActive: isQuote) {
                toggleQuote()
            }

            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 4)

            spoilerToggle

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.nook.card)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Keyboard Toolbar

    private var keyboardToolbar: some View {
        HStack(spacing: 4) {
            toolbarIcon(icon: "bold", isSystem: true, isActive: isBold) {
                toggleBold()
            }
            toolbarIcon(icon: "text-italic-bold", isSystem: false, isActive: isItalic) {
                toggleItalic()
            }
            toolbarIcon(icon: "quotes-bold", isSystem: false, isActive: isQuote) {
                toggleQuote()
            }

            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 4)

            spoilerToggle

            Spacer()

            Button {
                focusedField = nil
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.nook.detailTitle)
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private var spoilerToggle: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                containsSpoilers.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(containsSpoilers ? "eye-slash-fill" : "eye-slash-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)

                Text("Spoilers")
                    .font(NookFont.caption)
            }
            .foregroundStyle(
                containsSpoilers ? Color.nook.primary : Color.nook.detailMeta
            )
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(containsSpoilers ? Color.nook.primary.opacity(0.1) : .clear)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                containsSpoilers ? Color.nook.primary : Color.nook.detailTabBorder,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func toolbarIcon(icon: String, isSystem: Bool, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isSystem {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
            }
            .foregroundStyle(isActive ? Color.nook.primary : Color.nook.detailTitle)
            .frame(width: 32, height: 32)
            .background(
                isActive
                    ? Color.nook.primary.opacity(0.1)
                    : .clear,
                in: Circle()
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Formatting Actions

    private var isBold: Bool { formatter.isBold }
    private var isItalic: Bool { formatter.isItalic }
    private var isQuote: Bool { formatter.isQuote }

    private func toggleBold() { formatter.toggleBold() }
    private func toggleItalic() { formatter.toggleItalic() }
    private func toggleQuote() { formatter.toggleQuote(); focusedField = .reviewBody }
}

// MARK: - Rich Text Formatter Protocol

@MainActor
protocol RichTextFormatterProtocol {
    var isBold: Bool { get }
    var isItalic: Bool { get }
    var isQuote: Bool { get }
    func toggleBold()
    func toggleItalic()
    func toggleQuote()
    func insertLink()
}

final class PlainTextFormatter: RichTextFormatterProtocol {
    var isBold: Bool { false }
    var isItalic: Bool { false }
    var isQuote: Bool { false }
    func toggleBold() {}
    func toggleItalic() {}
    func toggleQuote() {}
    func insertLink() {}
}

@available(iOS 26, *)
@Observable
final class RichTextFormatter: RichTextFormatterProtocol {
    var richText: AttributedString = ""
    var selection = AttributedTextSelection()
    var fontContext: Font.Context?

    /// Tracks whether the current line is in quote mode so new lines extend the quote.
    private(set) var quoteMode = false

    var isBold: Bool {
        guard let ctx = fontContext else { return false }
        let font = selection.typingAttributes(in: richText).font
        return (font ?? .default).resolve(in: ctx).isBold
    }

    var isItalic: Bool {
        guard let ctx = fontContext else { return false }
        let font = selection.typingAttributes(in: richText).font
        return (font ?? .default).resolve(in: ctx).isItalic
    }

    var isQuote: Bool {
        quoteMode
    }

    func toggleBold() {
        let newValue = !isBold
        richText.transformAttributes(in: &selection) {
            $0.font = ($0.font ?? .default).bold(newValue)
        }
    }

    func toggleItalic() {
        let newValue = !isItalic
        richText.transformAttributes(in: &selection) {
            $0.font = ($0.font ?? .default).italic(newValue)
        }
    }

    func toggleQuote() {
        if isQuote {
            removeQuoteFromCurrentLine()
            quoteMode = false
        } else {
            addQuoteToCurrentLine()
            quoteMode = true
        }
    }

    func insertLink() {
        // No-op, removed
    }

    /// Called when new text is inserted — auto-continues quote on new lines.
    func handleTextChange(oldText: AttributedString) {
        guard quoteMode else { return }

        let newChars = String(richText.characters)
        let oldChars = String(oldText.characters)
        guard newChars.count > oldChars.count else { return }

        let oldNewlineCount = oldChars.filter { $0 == "\n" }.count
        let newNewlineCount = newChars.filter { $0 == "\n" }.count

        guard newNewlineCount > oldNewlineCount else {
            // Regular typing — ensure paragraph style on current line
            ensureQuoteParagraphStyle()
            return
        }

        // A newline was just inserted — check if we should continue or exit quote
        let lines = newChars.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else { return }

        // Find the newly created empty line after a quote line
        // Walk lines to find a quote line followed by an empty line
        var charOffset = 0
        for i in 0..<lines.count {
            let line = String(lines[i])
            if i > 0 {
                let prevLine = String(lines[i - 1])
                if prevLine.hasPrefix("▎ ") && line.isEmpty {
                    let prevContent = String(prevLine.dropFirst(2))
                    if prevContent.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                        // Empty quote line (just "▎ ") + Enter → remove it and exit quote
                        let removeStart = charOffset - prevLine.count - 1
                        if removeStart >= 0 {
                            let attrStart = richText.index(richText.startIndex, offsetByCharacters: removeStart)
                            let attrEnd = richText.index(richText.startIndex, offsetByCharacters: charOffset)
                            if attrStart < attrEnd, attrEnd <= richText.endIndex {
                                richText.removeSubrange(attrStart..<attrEnd)
                            }
                        }
                        quoteMode = false
                        return
                    }

                    // Has content — insert quote prefix + paragraph style on new line
                    let attrIdx = richText.index(richText.startIndex, offsetByCharacters: charOffset)
                    var quotePrefix = AttributedString("▎ ")
                    quotePrefix.foregroundColor = Color.nook.detailMeta
                    quotePrefix.paragraphStyle = Self.quoteParagraphStyle
                    richText.insert(quotePrefix, at: attrIdx)
                    return
                }
            }
            charOffset += line.count + 1
        }
    }

    // MARK: - Private Quote Helpers

    static let quoteIndent: CGFloat = 16

    private static var quoteParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 0
        style.headIndent = quoteIndent
        return style
    }

    private func addQuoteToCurrentLine() {
        let plainString = String(richText.characters)

        if plainString.isEmpty {
            var quotePrefix = AttributedString("▎ ")
            quotePrefix.foregroundColor = Color.nook.detailMeta
            quotePrefix.paragraphStyle = Self.quoteParagraphStyle
            richText = quotePrefix
            return
        }

        // Add quote prefix to the last line
        let lineStartCharOffset: Int
        if let lastNL = plainString.lastIndex(of: "\n") {
            lineStartCharOffset = plainString.distance(from: plainString.startIndex, to: plainString.index(after: lastNL))
        } else {
            lineStartCharOffset = 0
        }

        let lineFromStart = plainString.dropFirst(lineStartCharOffset)
        guard !lineFromStart.hasPrefix("▎ ") else { return }

        let attrStartIdx = richText.index(richText.startIndex, offsetByCharacters: lineStartCharOffset)

        var quotePrefix = AttributedString("▎ ")
        quotePrefix.foregroundColor = Color.nook.detailMeta
        quotePrefix.paragraphStyle = Self.quoteParagraphStyle
        richText.insert(quotePrefix, at: attrStartIdx)

        // Apply paragraph style to the rest of the line too
        applyParagraphStyleToLine(from: lineStartCharOffset)
    }

    private func removeQuoteFromCurrentLine() {
        let plainString = String(richText.characters)
        guard !plainString.isEmpty else { return }

        let lineStartCharOffset: Int
        if let lastNL = plainString.lastIndex(of: "\n") {
            lineStartCharOffset = plainString.distance(from: plainString.startIndex, to: plainString.index(after: lastNL))
        } else {
            lineStartCharOffset = 0
        }

        let lineFromStart = plainString.dropFirst(lineStartCharOffset)
        guard lineFromStart.hasPrefix("▎ ") else { return }

        // Remove "▎ " (2 characters)
        let attrStartIdx = richText.index(richText.startIndex, offsetByCharacters: lineStartCharOffset)
        let attrEndIdx = richText.index(richText.startIndex, offsetByCharacters: lineStartCharOffset + 2)
        richText.removeSubrange(attrStartIdx..<attrEndIdx)

        // Reset paragraph style
        removeParagraphStyleFromLine(from: lineStartCharOffset)
    }

    private func ensureQuoteParagraphStyle() {
        let plainString = String(richText.characters)
        guard !plainString.isEmpty else { return }
        let lineStartCharOffset: Int
        if let lastNL = plainString.lastIndex(of: "\n") {
            lineStartCharOffset = plainString.distance(from: plainString.startIndex, to: plainString.index(after: lastNL))
        } else {
            lineStartCharOffset = 0
        }
        applyParagraphStyleToLine(from: lineStartCharOffset)
    }

    private func applyParagraphStyleToLine(from charOffset: Int) {
        let startIdx = richText.index(richText.startIndex, offsetByCharacters: charOffset)
        let plainString = String(richText.characters)
        let lineEnd = plainString.dropFirst(charOffset)
        let lineLength: Int
        if let nlIdx = lineEnd.firstIndex(of: "\n") {
            lineLength = plainString.distance(from: lineEnd.startIndex, to: nlIdx)
        } else {
            lineLength = lineEnd.count
        }
        guard lineLength > 0 else { return }
        let endIdx = richText.index(richText.startIndex, offsetByCharacters: charOffset + lineLength)
        if startIdx < endIdx, endIdx <= richText.endIndex {
            richText[startIdx..<endIdx].paragraphStyle = Self.quoteParagraphStyle
        }
    }

    private func removeParagraphStyleFromLine(from charOffset: Int) {
        let startIdx = richText.index(richText.startIndex, offsetByCharacters: charOffset)
        let plainString = String(richText.characters)
        let lineEnd = plainString.dropFirst(charOffset)
        let lineLength: Int
        if let nlIdx = lineEnd.firstIndex(of: "\n") {
            lineLength = plainString.distance(from: lineEnd.startIndex, to: nlIdx)
        } else {
            lineLength = lineEnd.count
        }
        guard lineLength > 0 else { return }
        let endIdx = richText.index(richText.startIndex, offsetByCharacters: charOffset + lineLength)
        if startIdx < endIdx, endIdx <= richText.endIndex {
            richText[startIdx..<endIdx].paragraphStyle = NSParagraphStyle.default
        }
    }
}

// MARK: - Rich Text Editor (iOS 26+)

@available(iOS 26, *)
private struct RichTextEditorView: View {
    @Bindable var formatter: RichTextFormatter
    @Binding var reviewText: String
    var focusedField: FocusState<ReviewSheetView.ReviewField?>.Binding

    @Environment(\.fontResolutionContext) private var fontResolutionContext

    var body: some View {
        ZStack(alignment: .topLeading) {
            if formatter.richText.characters.isEmpty {
                Text("Share your thoughts...")
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.detailMeta)
                    .padding(.top, 16)
                    .onTapGesture {
                        focusedField.wrappedValue = .reviewBody
                    }
            }

            TextEditor(text: $formatter.richText, selection: $formatter.selection)
                .font(NookFont.label)
                .foregroundStyle(Color.nook.detailTitle)
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .focused(focusedField, equals: .reviewBody)
                .frame(minHeight: 200)
                .padding(.top, 8)
                .padding(.leading, -5)
                .onChange(of: formatter.richText) { oldValue, newValue in
                    reviewText = String(newValue.characters)
                    formatter.handleTextChange(oldText: oldValue)
                }
                .onAppear {
                    formatter.fontContext = fontResolutionContext
                }
                .onChange(of: fontResolutionContext) {
                    formatter.fontContext = fontResolutionContext
                }
        }
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
