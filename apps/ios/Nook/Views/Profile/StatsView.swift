import SwiftUI

// MARK: - Stats View

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trackedCount = 0
    @State private var completedCount = 0
    @State private var hoursSpent: String = "—"
    @State private var avgRating: String = "—"
    @State private var categoryStats: [CategoryStat] = []
    @State private var realRatingData: [RatingStat] = []
    @State private var realGenreData: [GenreStat] = []
    @State private var realMonthlyData: [MonthlyStat] = []
    @State private var streakDays = 0
    @State private var streakStartDate: String = ""
    @State private var realMilestones: [MilestoneStat] = []

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 32) {
                        overviewSection
                        streakCard
                        categoryBreakdownSection
                        ratingDistributionSection
                        topGenresSection
                        monthlyActivitySection
                        milestonesSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 72)
                    .padding(.bottom, 40)
                }

                statsHeader
            }
            .background(Color.nook.statsBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadStats() }
        }
    }

    private func loadStats() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        let trackingService = TrackingService()

        do {
            let items = try await trackingService.getLibrary(userId: userId)
            trackedCount = items.count
            completedCount = items.filter { $0.status == "completed" }.count

            // Build category breakdown
            var counts: [String: Int] = [:]
            for item in items {
                counts[item.mediaType, default: 0] += 1
            }

            let colorMap: [String: (Color, Color)] = [
                "anime": (Color.nook.statsAnime, Color.nook.statsAnimeBg),
                "tv": (Color.nook.statsTvShow, Color.nook.statsTvShowBg),
                "book": (Color.nook.statsBook, Color.nook.statsBookBg),
                "movie": (Color.nook.statsMovie, Color.nook.statsMovieBg),
                "manga": (Color.nook.statsManga, Color.nook.statsMangaBg),
                "game": (Color.nook.statsGame, Color.nook.statsGameBg),
            ]

            let labelMap: [String: String] = [
                "anime": "Anime", "tv": "TV", "book": "Books",
                "movie": "Movies", "manga": "Manga", "game": "Games",
            ]

            let maxCount = counts.values.max() ?? 1
            categoryStats = counts
                .sorted { $0.value > $1.value }
                .map { key, count in
                    let colors = colorMap[key] ?? (Color.gray, Color.gray.opacity(0.2))
                    return CategoryStat(
                        label: labelMap[key] ?? key.capitalized,
                        count: count,
                        fraction: CGFloat(count) / CGFloat(maxCount),
                        color: colors.0,
                        background: colors.1
                    )
                }
            // Build rating distribution from user scores
            var ratingCounts = [Int](repeating: 0, count: 10)
            var totalScore: Double = 0
            var scoredCount = 0
            for item in items {
                if let score = item.score {
                    let bucket = max(1, min(10, Int(score.rounded()))) - 1
                    ratingCounts[bucket] += 1
                    totalScore += score
                    scoredCount += 1
                }
            }
            realRatingData = (1...10).map { RatingStat(score: $0, count: ratingCounts[$0 - 1]) }

            // Average rating
            if scoredCount > 0 {
                avgRating = String(format: "%.1f", totalScore / Double(scoredCount))
            }

            // Top genres — aggregate from tracked media items' genres
            var genreCounts: [String: Int] = [:]
            for item in items {
                for genre in item.genres {
                    genreCounts[genre, default: 0] += 1
                }
            }
            realGenreData = genreCounts
                .sorted { $0.value > $1.value }
                .prefix(9)
                .map { GenreStat(name: $0.key, count: $0.value) }

            // Monthly activity — count tracked items by month (last 6 months)
            let calendar = Calendar.current
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            var monthlyCounts: [(String, Int)] = []
            for i in (0..<6).reversed() {
                guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
                let count = items.filter { $0.updatedAt >= monthStart && $0.updatedAt < monthEnd }.count
                monthlyCounts.append((formatter.string(from: monthDate), count))
            }
            realMonthlyData = monthlyCounts.map { MonthlyStat(month: $0.0, count: $0.1) }

            // Streak — consecutive days with tracking activity
            let sortedDates = Set(items.map { calendar.startOfDay(for: $0.updatedAt) }).sorted(by: >)
            var streak = 0
            let today = calendar.startOfDay(for: now)
            var checkDate = today
            for date in sortedDates {
                if date == checkDate {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                } else if date < checkDate {
                    break
                }
            }
            streakDays = streak
            if streak > 0, let startDate = calendar.date(byAdding: .day, value: -(streak - 1), to: today) {
                let df = DateFormatter()
                df.dateFormat = "MMM d"
                streakStartDate = df.string(from: startDate)
            }

            // Hours spent (movies, TV, anime only — no reliable data for books/manga/games)
            let profileService = ProfileService()
            let hours = (try? await profileService.getHoursSpent(userId: userId)) ?? 0
            if hours >= 1 {
                hoursSpent = String(format: "%.0f", hours)
            } else if hours > 0 {
                hoursSpent = "<1"
            }

            // Milestones
            let stats = try? await profileService.getStats(userId: userId)
            let reviewCount = stats?.reviewCount ?? 0
            let reviewLikesReceived = stats?.reviewLikesReceived ?? 0
            realMilestones = [
                MilestoneStat(title: "First Steps", description: "Track your first piece of media", achieved: trackedCount >= 1),
                MilestoneStat(title: "Dedicated Viewer", description: "Complete 50 titles", achieved: completedCount >= 50),
                MilestoneStat(title: "Century Club", description: "Complete 100 titles", achieved: completedCount >= 100),
                MilestoneStat(title: "Critic's Eye", description: "Write 25 reviews", achieved: reviewCount >= 25),
                MilestoneStat(title: "Bookworm", description: "Track 10 books", achieved: counts["book", default: 0] >= 10),
                MilestoneStat(title: "Tastemaker", description: "Have 10 reviews liked by others", achieved: reviewLikesReceived >= 10),
            ]
        } catch {
            // Keep defaults
        }
    }

    // MARK: - Header

    private var statsHeader: some View {
        HStack {
            navCircleButton(icon: "caret-left-bold") {
                dismiss()
            }

            Spacer()

            Text("Stats")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.statsTitle)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.nook.statsBackground, Color.nook.statsBackground.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func navCircleButton(icon: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        } else {
            Button(action: action) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.foreground)
                    .frame(width: 36, height: 36)
                    .background(Color.nook.segmentBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.statsSectionTitle)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                overviewCard(
                    value: "\(trackedCount)",
                    label: "Tracked",
                    icon: "bookmark-simple-fill",
                    color: Color.nook.profileStatTracked,
                    background: Color.nook.profileStatTrackedBg
                )
                overviewCard(
                    value: "\(completedCount)",
                    label: "Completed",
                    icon: "check-bold",
                    color: Color.nook.libraryStatusActive,
                    background: Color.nook.libraryStatusActive.opacity(0.12)
                )
                overviewCard(
                    value: hoursSpent,
                    label: "Hours spent",
                    icon: "clock-fill",
                    color: Color.nook.profileStatReviews,
                    background: Color.nook.profileStatReviewsBg
                )
                overviewCard(
                    value: avgRating,
                    label: "Avg. rating",
                    icon: "star-fill",
                    color: Color.nook.reviewRating,
                    background: Color.nook.reviewRating.opacity(0.12)
                )
            }
        }
    }

    private func overviewCard(
        value: String,
        label: String,
        icon: String,
        color: Color,
        background: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: NookRadii.xs)
                .fill(background)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(color)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(NookFont.statsCardValue)
                    .foregroundStyle(Color.nook.statsOverviewValue)

                Text(label)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.statsOverviewLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.nook.statsOverviewCard)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.sm)
                .stroke(Color.nook.statsOverviewCardBorder, lineWidth: 1)
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: NookRadii.xs + 2)
                .fill(Color.nook.statsStreakFireBg)
                .frame(width: 52, height: 52)
                .overlay {
                    Image("fire-fill")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .foregroundStyle(Color.nook.statsStreakFire)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streakDays)")
                        .font(NookFont.statsHeroValue)
                        .foregroundStyle(Color.nook.statsOverviewValue)

                    Text("day streak")
                        .font(NookFont.label)
                        .foregroundStyle(Color.nook.statsSubtitle)
                }

                Text(streakDays > 0 ? "You've tracked something every day since \(streakStartDate)" : "Track daily to build a streak!")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.statsSubtitle)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.nook.statsOverviewCard)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.sm)
                .stroke(Color.nook.statsOverviewCardBorder, lineWidth: 1)
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By category")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.statsSectionTitle)

            VStack(spacing: 10) {
                let data = categoryStats
                ForEach(data, id: \.label) { item in
                    categoryBar(item: item)
                }
            }
            .padding(20)
            .background(Color.nook.statsOverviewCard)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.sm)
                    .stroke(Color.nook.statsOverviewCardBorder, lineWidth: 1)
            }
        }
    }

    private func categoryBar(item: CategoryStat) -> some View {
        HStack(spacing: 12) {
            Text(item.label)
                .font(NookFont.statsBarLabel)
                .foregroundStyle(Color.nook.statsSubtitle)
                .frame(width: 52, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.background)
                        .frame(height: 24)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.color)
                        .frame(width: max(geo.size.width * item.fraction, 24), height: 24)
                }
            }
            .frame(height: 24)

            Text("\(item.count)")
                .font(NookFont.captionBold)
                .foregroundStyle(Color.nook.statsOverviewValue)
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Rating Distribution

    private var ratingDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your ratings")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.statsSectionTitle)

            VStack(spacing: 0) {
                let ratings = realRatingData
                let maxCount = ratings.map(\.count).max() ?? 1

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(ratings, id: \.score) { item in
                        ratingBarDynamic(item: item, maxCount: maxCount)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Color.nook.statsOverviewDivider
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    ForEach(ratings, id: \.score) { item in
                        Text("\(item.score)")
                            .font(NookFont.statsBarLabel)
                            .foregroundStyle(Color.nook.statsRatingLabel)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color.nook.statsOverviewCard)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.sm)
                    .stroke(Color.nook.statsOverviewCardBorder, lineWidth: 1)
            }
        }
    }

    private func ratingBarDynamic(item: RatingStat, maxCount: Int) -> some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)

            if item.count > 0 {
                Text("\(item.count)")
                    .font(NookFont.statsBarLabel)
                    .foregroundStyle(Color.nook.statsSubtitle)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(item.count > 0 ? Color.nook.statsRatingBarFill : Color.nook.statsRatingBar)
                .frame(maxWidth: .infinity)
                .frame(height: max(CGFloat(item.count) / CGFloat(max(maxCount, 1)) * 80, 4))
        }
    }

    // MARK: - Top Genres

    private var topGenresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top genres")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.statsSectionTitle)

            FlowLayout(spacing: 8) {
                ForEach(realGenreData, id: \.name) { genre in
                    genreTag(name: genre.name, count: genre.count)
                }
            }
            .padding(16)
            .background(Color.nook.statsOverviewCard)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.sm)
                    .stroke(Color.nook.statsOverviewCardBorder, lineWidth: 1)
            }
        }
    }

    private func genreTag(name: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.statsGenreTagText)

            Text("\(count)")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.statsSubtitle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.nook.statsGenreTag)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.nook.statsGenreTagBorder, lineWidth: 1)
        }
    }

    // MARK: - Monthly Activity

    private var monthlyActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity")
                    .font(NookFont.outfitHeadingSmall)
                    .foregroundStyle(Color.nook.statsSectionTitle)

                Spacer()

                Text("Last 6 months")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.statsSubtitle)
            }

            VStack(spacing: 0) {
                let monthlyItems = realMonthlyData
                let maxMonthly = monthlyItems.map(\.count).max() ?? 1

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(monthlyItems, id: \.month) { item in
                        VStack(spacing: 6) {
                            Spacer(minLength: 0)

                            Text("\(item.count)")
                                .font(NookFont.statsBarLabel)
                                .foregroundStyle(Color.nook.statsSubtitle)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.nook.statsProgressFill.opacity(
                                    item.count > 0 ? 0.15 + Double(item.count) / Double(max(maxMonthly, 1)) * 0.85 : 0.08
                                ))
                                .frame(maxWidth: .infinity)
                                .frame(height: max(CGFloat(item.count) / CGFloat(max(maxMonthly, 1)) * 80, 8))
                        }
                    }
                }
                .frame(height: 110)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                HStack(spacing: 8) {
                    ForEach(realMonthlyData, id: \.month) { item in
                        Text(item.month)
                            .font(NookFont.statsBarLabel)
                            .foregroundStyle(Color.nook.statsRatingLabel)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color.nook.statsOverviewCard)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.sm)
                    .stroke(Color.nook.statsOverviewCardBorder, lineWidth: 1)
            }
        }
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Milestones")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.statsSectionTitle)

            VStack(spacing: 0) {
                let milestones = realMilestones
                ForEach(Array(milestones.enumerated()), id: \.element.title) { index, milestone in
                    milestoneRow(milestone: milestone)

                    if index < milestones.count - 1 {
                        Color.nook.statsOverviewDivider
                            .frame(height: 1)
                            .padding(.leading, 66)
                            .padding(.trailing, 16)
                    }
                }
            }
            .background(Color.nook.statsOverviewCard)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.sm)
                    .stroke(Color.nook.statsOverviewCardBorder, lineWidth: 1)
            }
        }
    }

    private func milestoneRow(milestone: MilestoneStat) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: NookRadii.xs)
                .fill(milestone.achieved ? Color.nook.statsMilestoneGoldBg : Color.nook.statsGenreTag)
                .frame(width: 40, height: 40)
                .overlay {
                    Image("trophy-fill")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(milestone.achieved ? Color.nook.statsMilestoneGold : Color.nook.statsSubtitle.opacity(0.5))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(milestone.achieved ? Color.nook.statsOverviewValue : Color.nook.statsSubtitle)

                Text(milestone.description)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.statsSubtitle)
            }

            Spacer(minLength: 0)

            if milestone.achieved {
                Image("check-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.libraryStatusActive)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Data Models

struct CategoryStat {
    let label: String
    let count: Int
    let fraction: CGFloat
    let color: Color
    let background: Color
}

struct RatingStat {
    let score: Int
    let count: Int
}

struct GenreStat {
    let name: String
    let count: Int
}

struct MonthlyStat {
    let month: String
    let count: Int
}

struct MilestoneStat {
    let title: String
    let description: String
    let achieved: Bool
}

// MARK: - Mock Data

extension StatsView {
    fileprivate static let categoryData: [CategoryStat] = [
        CategoryStat(label: "Anime", count: 52, fraction: 0.72, color: Color.nook.statsAnime, background: Color.nook.statsAnimeBg),
        CategoryStat(label: "TV", count: 31, fraction: 0.43, color: Color.nook.statsTvShow, background: Color.nook.statsTvShowBg),
        CategoryStat(label: "Books", count: 24, fraction: 0.33, color: Color.nook.statsBook, background: Color.nook.statsBookBg),
        CategoryStat(label: "Games", count: 18, fraction: 0.25, color: Color.nook.statsGame, background: Color.nook.statsGameBg),
        CategoryStat(label: "Movies", count: 15, fraction: 0.21, color: Color.nook.statsMovie, background: Color.nook.statsMovieBg),
        CategoryStat(label: "Manga", count: 7, fraction: 0.10, color: Color.nook.statsManga, background: Color.nook.statsMangaBg),
    ]

    fileprivate static let ratingData: [RatingStat] = [
        RatingStat(score: 1, count: 1),
        RatingStat(score: 2, count: 2),
        RatingStat(score: 3, count: 3),
        RatingStat(score: 4, count: 5),
        RatingStat(score: 5, count: 8),
        RatingStat(score: 6, count: 12),
        RatingStat(score: 7, count: 22),
        RatingStat(score: 8, count: 28),
        RatingStat(score: 9, count: 14),
        RatingStat(score: 10, count: 6),
    ]

    fileprivate static let genreData: [GenreStat] = [
        GenreStat(name: "Sci-Fi", count: 34),
        GenreStat(name: "Fantasy", count: 28),
        GenreStat(name: "Thriller", count: 19),
        GenreStat(name: "Romance", count: 16),
        GenreStat(name: "Action", count: 14),
        GenreStat(name: "Horror", count: 11),
        GenreStat(name: "Drama", count: 9),
        GenreStat(name: "Comedy", count: 8),
        GenreStat(name: "Mystery", count: 5),
    ]

    fileprivate static let monthlyData: [MonthlyStat] = [
        MonthlyStat(month: "Dec", count: 8),
        MonthlyStat(month: "Jan", count: 14),
        MonthlyStat(month: "Feb", count: 11),
        MonthlyStat(month: "Mar", count: 22),
        MonthlyStat(month: "Apr", count: 18),
        MonthlyStat(month: "May", count: 26),
    ]

    fileprivate static let milestoneData: [MilestoneStat] = [
        MilestoneStat(title: "First Steps", description: "Track your first piece of media", achieved: true),
        MilestoneStat(title: "Dedicated Viewer", description: "Complete 50 titles", achieved: true),
        MilestoneStat(title: "Century Club", description: "Complete 100 titles", achieved: false),
        MilestoneStat(title: "Critic's Eye", description: "Write 25 reviews", achieved: true),
        MilestoneStat(title: "Tastemaker", description: "Have 10 reviews liked by others", achieved: false),
    ]
}

// MARK: - Preview

#Preview {
    StatsView()
}
