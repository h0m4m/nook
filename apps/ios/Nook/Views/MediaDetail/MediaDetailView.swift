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
    let recommendations: [MediaSearchResult]
    let dbId: UUID?
    /// Source identity (provider, source-specific id, API media type) — used to
    /// rebuild a `MediaSearchResult` for flows like "Add to Nook".
    let source: String?
    let mediaId: String?
    let mediaType: String?
    /// Game platforms (IGDB) — empty for other media types.
    let platforms: [String]

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
        recommendations: [MediaSearchResult] = [],
        dbId: UUID? = nil,
        source: String? = nil,
        mediaId: String? = nil,
        mediaType: String? = nil,
        platforms: [String] = []
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
        self.recommendations = recommendations
        self.dbId = dbId
        self.source = source
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.platforms = platforms
    }


    var progress: Double {
        guard totalEpisodes > 0 else { return 0 }
        return Double(currentEpisode) / Double(totalEpisodes)
    }

    /// Rebuild a `MediaSearchResult` from this detail's source identity.
    /// Returns nil when the source identity is unavailable (e.g. mock data).
    var asSearchResult: MediaSearchResult? {
        guard let source, let mediaId, let mediaType else { return nil }
        return MediaSearchResult(
            mediaId: mediaId,
            source: source,
            mediaType: mediaType,
            title: title,
            imageURL: imageURL,
            year: year.isEmpty ? nil : year,
            score: rating > 0 ? rating : nil
        )
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
    /// Overrides media.dbId — passed separately so it can update after the API call resolves.
    var resolvedDbId: UUID?

    /// The authoritative DB identifier — prefers the overridden value.
    private var dbId: UUID? { resolvedDbId ?? media.dbId }

    /// Reviews with blocked authors filtered out (instant on block — see BlockStore).
    private var visibleReviews: [Review] {
        loadedReviews.filter { !BlockStore.shared.isBlocked($0.userId) }
    }
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: MediaDetailTab = .about
    @State private var isTracking: Bool
    @State private var isRated = false
    @State private var isReviewed = false
    @State private var showAddToNookSheet = false
    @State private var showTrackingSheet = false
    @State private var showReviewSheet = false
    @State private var selectedStatus: TrackingStatus?
    @State private var currentEpisode: Int
    @State private var userScore: Int?
    @State private var reviewTitle: String = ""
    @State private var reviewBody: String = ""
    @State private var containsSpoilers: Bool = false
    @State private var loadedReviews: [Review] = []
    @State private var isLoadingReviews = false
    @State private var reviewsLoadToken = UUID()

    /// Single source of truth for rating — both tracking sheet score and review sheet rating use this.
    private var reviewRatingBinding: Binding<Int> {
        Binding(
            get: { userScore ?? 0 },
            set: { newValue in
                userScore = newValue > 0 ? newValue : nil
                isRated = newValue > 0
            }
        )
    }

    init(media: MediaDetail, isLoading: Bool = false, onTracked: (() -> Void)? = nil, resolvedDbId: UUID? = nil) {
        self.media = media
        self.isLoading = isLoading
        self.onTracked = onTracked
        self.resolvedDbId = resolvedDbId
        self._isTracking = State(initialValue: media.trackingStatus != nil)
        self._selectedStatus = State(initialValue: media.trackingStatus)
        self._currentEpisode = State(initialValue: media.currentEpisode)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                if isLoading {
                    loadingContentSkeleton
                } else {
                    progressCard
                        .padding(.top, 20)
                        .padding(.horizontal, 16)

                    actionButtons
                        .padding(.top, 8)
                        .padding(.horizontal, 16)

                    tabBar
                        .padding(.top, 12)

                    tabContent
                }
            }
        }
        .modifier(DetailTopBar(onDismiss: { dismiss() }, shareItem: "Check out \"\(media.title)\" on Nook"))
        .background(Color.nook.detailBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .task(id: resolvedDbId) {
            await loadExistingTracking()
            await loadExistingReview()
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
        .sheet(isPresented: $showAddToNookSheet) {
            CreateNookSheet(initialMedia: media.asSearchResult.map { [$0] } ?? [])
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.nook.detailBackground)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showReviewSheet, onDismiss: {
            reviewsLoadToken = UUID()
        }) {
            ReviewSheetView(
                media: media,
                mediaDbId: dbId,
                rating: reviewRatingBinding,
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

    /// Games have a release date, not an "Aired" range.
    private var releaseLabel: String {
        media.category == .game ? "Released" : "Aired"
    }

    /// Short label used in the progress card counter (e.g. "Ep 1", "Pg 142", "42 hrs")
    private var progressCountLabel: String {
        switch media.category {
        case .book: "Pg \(currentEpisode)"
        case .manga: "Ch \(currentEpisode)"
        case .movie: currentEpisode > 0 ? "Watched" : "Not watched"
        case .game: hoursTrackedLabel(currentEpisode)
        default: "Ep \(currentEpisode)"
        }
    }

    private func loadExistingTracking() async {
        print("[MediaDetail] loadExistingTracking — dbId=\(String(describing: dbId)), resolvedDbId=\(String(describing: resolvedDbId)), media.dbId=\(String(describing: media.dbId))")
        guard let dbId = dbId,
              let userId = try? await supabase.auth.session.user.id else {
            print("[MediaDetail] loadExistingTracking — skipped (no dbId or userId)")
            return
        }
        let service = TrackingService()
        if let existing = try? await service.getTrackingForMedia(userId: userId, mediaItemId: dbId) {
            print("[MediaDetail] loadExistingTracking — found tracking: status=\(existing.status), progress=\(existing.progress), score=\(String(describing: existing.score))")
            selectedStatus = TrackingStatus.from(dbValue: existing.status)
            currentEpisode = existing.progress
            userScore = existing.score.map { Int($0) }
            isTracking = true
            isRated = existing.score != nil
        }
    }

    private func loadExistingReview() async {
        print("[MediaDetail] loadExistingReview — dbId=\(String(describing: dbId))")
        guard let dbId = dbId else {
            print("[MediaDetail] loadExistingReview — skipped (no dbId)")
            return
        }
        let service = ReviewService()
        do {
            if let existing = try await service.getUserReview(mediaItemId: dbId) {
                print("[MediaDetail] loadExistingReview — found review: rating=\(existing.rating), title=\(String(describing: existing.title))")
                // userScore is the single source of truth for rating — only set if tracking didn't already load one
                if userScore == nil && existing.rating > 0 {
                    userScore = Int(existing.rating)
                    isRated = true
                }
                reviewTitle = existing.title ?? ""
                reviewBody = existing.body
                containsSpoilers = existing.isSpoiler
                isReviewed = true
            } else {
                print("[MediaDetail] loadExistingReview — no existing review found")
            }
        } catch {
            print("[MediaDetail] loadExistingReview — ERROR: \(error)")
        }
    }

    private func persistTracking() {
        guard isTracking, let status = selectedStatus, let dbId = dbId else {
            print("[MediaDetail] persistTracking — skipped (isTracking=\(isTracking), status=\(String(describing: selectedStatus)), dbId=\(String(describing: dbId)))")
            return
        }
        print("[MediaDetail] persistTracking — saving status=\(status.dbValue), progress=\(currentEpisode), score=\(String(describing: userScore)), dbId=\(dbId)")
        onTracked?()
        Task {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            let service = TrackingService()
            do {
                try await service.track(
                    userId: userId,
                    mediaItemId: dbId,
                    status: status.dbValue,
                    progress: currentEpisode,
                    score: userScore.map { Double($0) }
                )
                print("[MediaDetail] persistTracking — saved successfully")
            } catch {
                print("[MediaDetail] persistTracking — ERROR: \(error)")
            }
        }
    }

}

// MARK: - Top Bar + Header Row

private extension MediaDetailView {
    var headerRow: some View {
        HStack(alignment: .top, spacing: 16) {
            // Poster
            Group {
                if let url = media.imageURL {
                    MediaPosterImage(url: url, width: 100, height: 150, cornerRadius: 10)
                } else if !media.imageName.isEmpty {
                    Image(media.imageName)
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Color.nook.searchShimmerBase
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                if isLoading {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: 60, height: 22)
                        .opacity(0.6)
                } else {
                    categoryBadge
                }

                Text(media.title)
                    .font(NookFont.headingSmall)
                    .foregroundStyle(Color.nook.detailTitle)
                    .fixedSize(horizontal: false, vertical: true)

                if isLoading {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: 140, height: 12)
                        .opacity(0.5)
                } else {
                    metadataRow

                    if media.rating > 0 {
                        ratingDisplay
                            .padding(.top, 2)
                    }

                    let genreList = media.genres.components(separatedBy: ", ").filter { !$0.isEmpty }
                    if !genreList.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(genreList, id: \.self) { genre in
                                genreBadge(genre)
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Loading Skeleton

private extension MediaDetailView {
    /// Shimmer placeholders shown while full detail is loading.
    var loadingContentSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress card shimmer
            RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                .fill(Color.nook.searchShimmerBase)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .opacity(0.4)
                .padding(.top, 20)
                .padding(.horizontal, 16)

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
            .padding(.horizontal, 16)

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
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Media Info components (badge, rating, metadata)

private extension MediaDetailView {
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
        // Year + episode count only — genres are shown as badges below
        let parts: [String] = {
            var p: [String] = []
            if !media.year.isEmpty { p.append(media.year) }
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

    func genreBadge(_ genre: String) -> some View {
        Text(genre)
            .font(NookFont.tabLabel)
            .tracking(0.3)
            .foregroundStyle(Color.nook.detailMeta)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.nook.detailProgressCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.nook.detailTabBorder, lineWidth: 1)
                    )
            )
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

            addToNookButton
        }
        .padding(.vertical, 8)
    }

    private var addToNookButton: some View {
        Button {
            showAddToNookSheet = true
        } label: {
            VStack(spacing: 6) {
                actionIcon(icon: "folders", isActive: false, fgColor: Color.nook.detailTitle)

                Text("Add to Nook")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                    .foregroundStyle(Color.nook.detailActionLabel)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
    var visibleTabs: [MediaDetailTab] {
        MediaDetailTab.allCases.filter { tab in
            if tab == .similar && media.category == .book { return false }
            return true
        }
    }

    var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(visibleTabs) { tab in
                    tabButton(tab)
                }
                Spacer()
            }
            .padding(.horizontal, 16)

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
                detailRow(label: releaseLabel, value: media.airedDates)
                detailRow(label: "Platforms", value: media.platforms.joined(separator: ", "))
                if media.category != .movie {
                    detailRow(label: progressLabel, value: media.episodeCount)
                }
                detailRow(label: "Genre", value: media.genresFull)
            }
        }
        .padding(16)
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
            } else if visibleReviews.isEmpty {
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
                ForEach(visibleReviews) { review in
                    NavigationLink(value: ReviewItem(from: review)) {
                        loadedReviewCard(review)
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(16)
        .padding(.bottom, 100)
        .task(id: reviewsLoadToken) {
            await loadReviews()
        }
    }

    private func loadReviews() async {
        guard let dbId = dbId else {
            print("[MediaDetail] loadReviews — skipped (no dbId)")
            return
        }
        isLoadingReviews = true
        let service = ReviewService()
        do {
            loadedReviews = try await service.getReviewsForMedia(mediaItemId: dbId)
            print("[MediaDetail] loadReviews — loaded \(loadedReviews.count) reviews")
        } catch {
            print("[MediaDetail] loadReviews — ERROR: \(error)")
            loadedReviews = []
        }
        isLoadingReviews = false
    }

    func loadedReviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    ReviewerAvatar(url: review.authorAvatarURL, size: 32, iconSize: 14)

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

                    Text(ProfileReviewCard.ratingLabel(for: review.rating))
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

            Text(markdownAttributed(review.body))
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

                    Text(ProfileReviewCard.ratingLabel(for: review.rating))
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

            // Review body (Markdown rendered)
            Text(markdownAttributed(review.body))
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
        Group {
            if media.recommendations.isEmpty {
                tabEmptyState(
                    title: "No recommendations yet",
                    subtitle: "Similar titles will appear here once available"
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ForEach(media.recommendations) { item in
                        NavigationLink(value: MediaDetailRoute(from: item)) {
                            similarCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
    }

    func similarCard(_ item: MediaSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                MediaPosterImage(
                    url: item.imageURL,
                    width: geo.size.width,
                    height: 220,
                    cornerRadius: 12
                )
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let year = item.year {
                        Text(year)
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.detailMeta)
                    }

                    if item.year != nil, item.score != nil {
                        Circle()
                            .fill(Color.nook.detailMeta)
                            .frame(width: 3, height: 3)
                    }

                    if let score = item.score {
                        HStack(spacing: 3) {
                            Image("star-fill")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 10, height: 10)
                                .foregroundStyle(Color.nook.reviewRating)

                            Text(String(format: "%.1f", score))
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.reviewRating)
                        }
                    }
                }
            }
        }
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
        .padding(.horizontal, 16)
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

    // Local copies so Cancel can discard changes
    @State private var localStatus: TrackingStatus?
    @State private var localEpisode: Int = 0
    @State private var localScore: Int?

    private let statuses: [TrackingStatus] = [
        .inProgress, .completed, .planned, .onHold, .dropped,
    ]

    private var progressCountLabel: String {
        switch category {
        case .book: "Pg \(localEpisode)"
        case .manga: "Ch \(localEpisode)"
        case .movie: localEpisode > 0 ? "Watched" : "Not watched"
        case .game: hoursTrackedLabel(localEpisode)
        default: "Ep \(localEpisode)"
        }
    }

    private var progressHeaderLabel: String {
        // Movies (watched/not) and games (hours played) have no "out of" total.
        if category == .movie || category == .game { return progressCountLabel }
        if totalEpisodes == 0 { return "\(progressCountLabel) / ?" }
        return "\(progressCountLabel) / \(totalEpisodes)"
    }

    private var progressNumberField: some View {
        HStack {
            Button {
                if localEpisode > 0 { localEpisode -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.nook.detailTitle)
            }
            .buttonStyle(.plain)

            Spacer()

            TextField("0", value: $localEpisode, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.detailTitle)
                .frame(width: 80)

            Spacer()

            Button {
                localEpisode += 1
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
            localStatus = selectedStatus ?? .planned
            localEpisode = currentEpisode
            localScore = userScore
        }
        .onChange(of: localEpisode) { _, newEpisode in
            withAnimation(.easeOut(duration: 0.2)) {
                if totalEpisodes > 0 && newEpisode >= totalEpisodes {
                    localStatus = .completed
                } else if newEpisode > 0 && (localStatus == .planned || localStatus == nil) {
                    localStatus = .inProgress
                } else if newEpisode == 0 && localStatus == .inProgress {
                    localStatus = .planned
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
                selectedStatus = localStatus
                currentEpisode = localEpisode
                userScore = localScore
                isTracking = localStatus != nil || localEpisode > 0
                isRated = localScore != nil
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

                if let status = localStatus {
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
        let isSelected = localStatus == status

        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                let newStatus = localStatus == status ? nil : status
                localStatus = newStatus

                if totalEpisodes > 0 {
                    if newStatus == .completed {
                        localEpisode = totalEpisodes
                    } else if newStatus == .planned || newStatus == nil {
                        localEpisode = 0
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
                Picker("Watched", selection: $localEpisode) {
                    Text("Not watched").tag(0)
                    Text("Watched").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            } else if totalEpisodes > 0 {
                Picker("Episode", selection: $localEpisode) {
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
        guard let score = localScore else { return "Not Yet Scored" }
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
            get: { localScore ?? 0 },
            set: { localScore = $0 == 0 ? nil : $0 }
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
    /// Resolved DB UUID — may differ from media.dbId if the API response arrived after MediaDetail was created.
    var mediaDbId: UUID?
    @Binding var rating: Int
    @Binding var title: String
    @Binding var reviewText: String
    @Binding var containsSpoilers: Bool
    @Binding var isReviewed: Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: ReviewField?
    @State private var showUpdateConfirmation = false
    @State private var moderationError: String?
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
            .alert("Update Review", isPresented: $showUpdateConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Replace", role: .destructive) {
                    publishReview()
                }
            } message: {
                Text("This will replace your previous review.")
            }
            .alert("Review not posted", isPresented: Binding(
                get: { moderationError != nil },
                set: { if !$0 { moderationError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(moderationError ?? "")
            }
        }
    }

    // MARK: - Publish

    private func publishReview() {
        Task {
            let resolvedId = mediaDbId ?? media.dbId
            let markdownBody = formatter.toMarkdown()
            if let dbId = resolvedId, (!markdownBody.isEmpty || rating > 0) {
                let service = ReviewService()
                do {
                    try await service.createReview(
                        mediaItemId: dbId,
                        title: title.isEmpty ? nil : title,
                        body: markdownBody.isEmpty ? "No text" : markdownBody,
                        rating: Double(rating),
                        isSpoiler: containsSpoilers
                    )
                } catch {
                    // Moderation rejection (or any failure): keep the sheet open
                    // with the draft intact and tell the user why.
                    moderationError = AppError(from: error).errorDescription
                    return
                }
            }
            reviewText = markdownBody
            isReviewed = !markdownBody.isEmpty || rating > 0
            dismiss()
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
                if isReviewed {
                    showUpdateConfirmation = true
                } else {
                    publishReview()
                }
            } label: {
                Text(isReviewed ? "Update" : "Publish")
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
    /// Serialize the current content to Markdown for storage.
    func toMarkdown() -> String
    /// Load Markdown content into the formatter.
    func loadMarkdown(_ markdown: String)
}

final class PlainTextFormatter: RichTextFormatterProtocol {
    var plainText: String = ""
    var isBold: Bool { false }
    var isItalic: Bool { false }
    var isQuote: Bool { false }
    func toggleBold() {}
    func toggleItalic() {}
    func toggleQuote() {}
    func insertLink() {}
    func toMarkdown() -> String { plainText }
    func loadMarkdown(_ markdown: String) { plainText = markdown }
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

    func toMarkdown() -> String {
        guard let ctx = fontContext else { return String(richText.characters) }
        var result = ""
        for run in richText.runs {
            var text = String(richText[run.range].characters)
            // Strip the visual quote prefix — we'll re-add it as Markdown
            let isQuoteLine = text.hasPrefix("▎ ")
            if isQuoteLine {
                text = String(text.dropFirst(2))
            }
            let resolved = (run.font ?? .default).resolve(in: ctx)
            let bold = resolved.isBold
            let italic = resolved.isItalic
            if bold && italic {
                text = "***\(text)***"
            } else if bold {
                text = "**\(text)**"
            } else if italic {
                text = "*\(text)*"
            }
            if isQuoteLine {
                text = "> \(text)"
            }
            result += text
        }
        return result
    }

    func loadMarkdown(_ markdown: String) {
        guard !markdown.isEmpty else {
            richText = ""
            return
        }
        // Use AttributedString's Markdown initializer
        if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            richText = attributed
        } else {
            richText = AttributedString(markdown)
        }
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
                    reviewText = formatter.toMarkdown()
                    formatter.handleTextChange(oldText: oldValue)
                }
                .onAppear {
                    formatter.fontContext = fontResolutionContext
                    // Load existing review body (Markdown) into the rich text formatter
                    if formatter.richText.characters.isEmpty && !reviewText.isEmpty {
                        formatter.loadMarkdown(reviewText)
                    }
                }
                .onChange(of: fontResolutionContext) {
                    formatter.fontContext = fontResolutionContext
                }
        }
    }
}

// MARK: - Detail Top Bar

private struct DetailTopBar: ViewModifier {
    let onDismiss: () -> Void
    var shareItem: String = "Check out this title on Nook"

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
                    .background(Color.nook.detailBackground)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var topBarContent: some View {
        HStack {
            if #available(iOS 26, *) {
                Button(action: onDismiss) {
                    Image("caret-left-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            } else {
                Button(action: onDismiss) {
                    Image("caret-left-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.nook.detailTitle)
                        .frame(width: 34, height: 34)
                        .background(Color.nook.headerIconBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.nook.headerIconBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if FeatureFlags.shareEnabled {
                if #available(iOS 26, *) {
                    ShareLink(item: shareItem) {
                        Image("export")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                } else {
                    ShareLink(item: shareItem) {
                        Image("export")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Color.nook.detailTitle)
                            .frame(width: 34, height: 34)
                            .background(Color.nook.headerIconBackground)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.nook.headerIconBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
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
