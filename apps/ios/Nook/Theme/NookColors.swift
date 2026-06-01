import SwiftUI

extension Color {
    static let nook = NookColors()
}

struct NookColors {
    let background = Color(hex: 0xF7F5F2)
    let foreground = Color(hex: 0x2A2421)
    let primary = Color(hex: 0x45333A)
    let primaryForeground = Color.white
    let secondary = Color(hex: 0xF4F1EE)
    let secondaryForeground = Color(hex: 0x2A2421)
    let mutedForeground = Color(hex: 0x7A726E)
    let accent = Color(hex: 0xDF8E63)
    let card = Color.white
    let cardForeground = Color(hex: 0x2A2421)
    let border = Color(hex: 0xE6DFD8)
    let input = Color(hex: 0xF4F1EE)
    let segmentBackground = Color(hex: 0xEEEAE5)

    // Onboarding-specific tokens from Figma
    let onboardingBackground = Color(hex: 0xFAFAF9)
    let onboardingHeading = Color(hex: 0x2C282B)
    let onboardingSubtitle = Color(hex: 0x8A8387)
    let onboardingPrimary = Color(hex: 0x432C3A)

    // Header tokens from Figma
    let headerBackground = Color(hex: 0xFAF8F6, alpha: 0.8)
    let headerGreeting = Color(hex: 0x7C7176)
    let headerName = Color(hex: 0x2B2527)
    let headerIconBackground = Color.white
    let headerIconBorder = Color(hex: 0xE8E2DF)
    let headerIconForeground = Color(hex: 0x2B2527)
    let headerAvatarBorder = Color(hex: 0xE8E2DF)

    // Section tokens from Figma
    let sectionTitle = Color(hex: 0x2B2527)
    let sectionAction = Color(hex: 0x7C7176)
    let cardTitle = Color(hex: 0x2B2527)
    let cardSubtitle = Color(hex: 0x7C7176)

    // Category badge tokens
    let badgeAnimeBg = Color(hex: 0xF3EBF5, alpha: 0.9)
    let badgeAnimeText = Color(hex: 0xBA68C8)
    let badgeTvShowBg = Color(hex: 0xEEF2F5, alpha: 0.9)
    let badgeTvShowText = Color(hex: 0x64B5F6)
    let badgeBookBg = Color(hex: 0xF5F1EB, alpha: 0.9)
    let badgeBookText = Color(hex: 0xD4A373)
    let badgeMovieBg = Color(hex: 0xFDECEC, alpha: 0.9)
    let badgeMovieText = Color(hex: 0xE57373)
    let badgeMangaBg = Color(hex: 0xE8F5E9, alpha: 0.9)
    let badgeMangaText = Color(hex: 0x66BB6A)
    let badgeGameBg = Color(hex: 0xFFF3E0, alpha: 0.9)
    let badgeGameText = Color(hex: 0xFFA726)

    // Review tokens from Figma
    let reviewRating = Color(hex: 0xF59E0B)
    let reviewBody = Color(hex: 0x7C7176)
    let reviewBorder = Color(hex: 0xE8E2DF)

    // Search tokens from Figma
    let searchBackground = Color(hex: 0xFAF8F6)
    let searchBarBackground = Color(hex: 0xF0EBE8)
    let searchBarText = Color(hex: 0x2B2527)
    let searchBarPlaceholder = Color(hex: 0x7C7176)
    let searchFilterSelected = Color(hex: 0x4A3243)
    let searchFilterBorder = Color(hex: 0xE8E2DF)
    let searchFilterText = Color(hex: 0x2B2527)
    let searchSectionLabel = Color(hex: 0x7C7176)
    let searchAddButton = Color(hex: 0xF0EBE8)
    let searchAddedButton = Color(hex: 0x4A3243)
    let searchEmptyIcon = Color(hex: 0xD5CFC9)
    let searchEmptyText = Color(hex: 0x7C7176)
    let searchShimmerBase = Color(hex: 0xEDE8E4)
    let searchShimmerHighlight = Color(hex: 0xF7F5F2)
    let searchResultCount = Color(hex: 0x7C7176)

    // Library tokens from Figma
    let libraryStatusActive = Color(hex: 0x00C950)
    let libraryStatusReading = Color(hex: 0x2B7FFF)
    let libraryCompletedTrack = Color(hex: 0x00C950, alpha: 0.2)

    // Media detail tokens from Figma
    let detailBackground = Color(hex: 0xFDFBF9)
    let detailTitle = Color(hex: 0x2C2826)
    let detailMeta = Color(hex: 0x827C77)
    let detailMetaDot = Color(hex: 0x827C77, alpha: 0.4)
    let detailProgressBackground = Color(hex: 0xF4F1EE)
    let detailProgressCard = Color(hex: 0xF4F1EE, alpha: 0.5)
    let detailProgressCardBorder = Color(hex: 0xE8E5E1, alpha: 0.5)
    let detailActionBackground = Color(hex: 0xF4F1EE)
    let detailActionActive = Color(hex: 0x462D3E, alpha: 0.1)
    let detailActionLabel = Color(hex: 0x827C77)
    let detailActionActiveLabel = Color(hex: 0x462D3E)
    let detailTabActive = Color(hex: 0x462D3E)
    let detailTabInactive = Color(hex: 0x827C77)
    let detailTabBorder = Color(hex: 0xE8E5E1)
    let detailReviewCard = Color.white
    let detailReviewCardBorder = Color(hex: 0xE8E5E1, alpha: 0.6)
    let detailReviewTitle = Color(hex: 0x2C2826)
    let detailReviewBody = Color(hex: 0x827C77)
    let detailRatingBadge = Color(hex: 0xDF8E63, alpha: 0.1)
    let detailRatingText = Color(hex: 0xDF8E63)
    let detailViewAllButton = Color(hex: 0x462D3E, alpha: 0.05)
    let detailViewAllText = Color(hex: 0x462D3E)
    let detailCategoryBadge = Color(hex: 0xC56E5A)
    let detailOverlayButton = Color(hex: 0x000000, alpha: 0.2)
    let detailHeroGradient = Color(hex: 0x000000, alpha: 0.5)

    // Review detail tokens
    let reviewDetailBackground = Color(hex: 0xFDFBF9)
    let reviewDetailTitle = Color(hex: 0x2C2826)
    let reviewDetailMeta = Color(hex: 0x827C77)
    let reviewDetailBody = Color(hex: 0x3D3835)
    let reviewDetailQuote = Color(hex: 0x6B6460)
    let reviewDetailDivider = Color(hex: 0xE8E5E1)
    let reviewDetailLikeActive = Color(hex: 0xE5484D)
    let reviewDetailMediaCard = Color(hex: 0xF4F1EE, alpha: 0.7)
    let reviewDetailMediaCardBorder = Color(hex: 0xE8E5E1, alpha: 0.5)
    let reviewDetailSpoilerBg = Color(hex: 0x462D3E, alpha: 0.06)
    let reviewDetailSpoilerText = Color(hex: 0x462D3E)

    // Club detail tokens
    let clubDetailBackground = Color(hex: 0xFDFCF9)
    let clubDetailTitle = Color(hex: 0x1C1917)
    let clubDetailMeta = Color(hex: 0x78716C)
    let clubDetailPinned = Color(hex: 0x8B5CF6)
    let clubDetailPostCard = Color.white
    let clubDetailPostCardBorder = Color(hex: 0xE8E5E1, alpha: 0.5)
    let clubDetailComposeCard = Color.white
    let clubDetailComposeBorder = Color(hex: 0xE8E5E1, alpha: 0.5)
    let clubDetailJoinedButton = Color(hex: 0x362A31)
    let clubDetailAvatarBorder = Color(hex: 0xFDFCF9)
    let clubDetailLikeActive = Color(hex: 0xE5484D)
    let clubDetailPollBar = Color(hex: 0xF4F1EE)
    let clubDetailPollBarFill = Color(hex: 0x362A31, alpha: 0.15)

    // Create club tokens
    let createClubBackground = Color(hex: 0xFDFBF9)
    let createClubTitle = Color(hex: 0x1C1918)
    let createClubMeta = Color(hex: 0x78716C)
    let createClubButton = Color(hex: 0x43313D)
    let createClubBorder = Color(hex: 0xE6E2E0)
    let createClubFieldBackground = Color(hex: 0xF2EFEE)
    let createClubWarningBackground = Color(hex: 0xFFFBEB)
    let createClubWarningBorder = Color(hex: 0xFDE68A)
    let createClubWarningIcon = Color(hex: 0xD97706)
    let createClubWarningText = Color(hex: 0x92400E)

    // Notification tokens
    let notificationBackground = Color(hex: 0xFDFBF9)
    let notificationTitle = Color(hex: 0x2C2826)
    let notificationBody = Color(hex: 0x827C77)
    let notificationTimestamp = Color(hex: 0xB0A9A3)
    let notificationSectionHeader = Color(hex: 0x7C7176)
    let notificationDivider = Color(hex: 0xE8E5E1)

    // Activity feed tokens
    let activityCardBorder = Color(hex: 0xE8E5E1, alpha: 0.5)
    let activityClubName = Color(hex: 0x462D3E)

    // Profile menu tokens
    let profileMenuBackground = Color(hex: 0xFDFBF9)
    let profileMenuSectionBackground = Color.white
    let profileMenuSectionBorder = Color(hex: 0xE8E5E1, alpha: 0.6)
    let profileMenuName = Color(hex: 0x2C2826)
    let profileMenuEmail = Color(hex: 0x827C77)
    let profileMenuRowLabel = Color(hex: 0x2C2826)
    let profileMenuRowIcon = Color(hex: 0x462D3E)
    let profileMenuRowIconBackground = Color(hex: 0x462D3E, alpha: 0.08)
    let profileMenuDivider = Color(hex: 0xE8E5E1)
    let profileMenuChevron = Color(hex: 0xB0A9A3)
    let profileMenuLogoutText = Color(hex: 0xE5484D)
    let profileMenuLogoutIcon = Color(hex: 0xE5484D)
    let profileMenuLogoutIconBackground = Color(hex: 0xE5484D, alpha: 0.08)

    // Profile screen tokens
    let profileBackground = Color(hex: 0xFAFAF9)
    let profileHeaderBackground = Color(hex: 0xFAFAF9, alpha: 0.8)
    let profileName = Color(hex: 0x2C282B)
    let profileUsername = Color(hex: 0x8A8387)
    let profileBio = Color(hex: 0x2C282B)
    let profileStatValue = Color(hex: 0x2C282B)
    let profileStatLabel = Color(hex: 0x8A8387)
    let profileStatDivider = Color(hex: 0xE8E3E1)
    let profileSectionTitle = Color(hex: 0x2C282B)
    let profileViewAll = Color(hex: 0x432C3A)

    // Profile stat card tokens
    let profileStatCardBackground = Color.white
    let profileStatCardBorder = Color(hex: 0xE8E3E1)

    // Stat card category colors
    let profileStatTracked = Color(hex: 0x7896B2)
    let profileStatTrackedBg = Color(hex: 0xD4DFE8, alpha: 0.3)
    let profileStatReviews = Color(hex: 0xB58572)
    let profileStatReviewsBg = Color(hex: 0xE4C7BA, alpha: 0.3)
    let profileStatNooks = Color(hex: 0xB68B9F)
    let profileStatNooksBg = Color(hex: 0xEAD6DF, alpha: 0.3)
    let profileStatCommunities = Color(hex: 0x7C9E7B)
    let profileStatCommunitiesBg = Color(hex: 0xD3E1D2, alpha: 0.3)

    // Taste identity tag colors
    let profileTagSciFi = Color(hex: 0x7896B2)
    let profileTagSciFiBg = Color(hex: 0xD4DFE8, alpha: 0.3)
    let profileTagSciFiBorder = Color(hex: 0xD4DFE8)
    let profileTagRPGs = Color(hex: 0xB58572)
    let profileTagRPGsBg = Color(hex: 0xE4C7BA, alpha: 0.3)
    let profileTagRPGsBorder = Color(hex: 0xE4C7BA)
    let profileTagFantasy = Color(hex: 0x7C9E7B)
    let profileTagFantasyBg = Color(hex: 0xD3E1D2, alpha: 0.3)
    let profileTagFantasyBorder = Color(hex: 0xD3E1D2)
    let profileTagHorror = Color(hex: 0xB68B9F)
    let profileTagHorrorBg = Color(hex: 0xEAD6DF, alpha: 0.3)
    let profileTagHorrorBorder = Color(hex: 0xEAD6DF)
    let profileTagCinema = Color(hex: 0x968A79)
    let profileTagCinemaBg = Color(hex: 0xE8E2D9, alpha: 0.4)
    let profileTagCinemaBorder = Color(hex: 0xE8E2D9)

    // Profile segment control
    let profileSegmentBackground = Color(hex: 0xF5F3F1)
    let profileSegmentActive = Color(hex: 0xFAFAF9)
    let profileSegmentActiveText = Color(hex: 0x2C282B)
    let profileSegmentInactiveText = Color(hex: 0x8A8387)

    // Recently active card tokens
    let profileActivityCard = Color.white
    let profileActivityCardBorder = Color(hex: 0xE8E3E1)
    let profileActivityLabel = Color(hex: 0x8A8387)
    let profileActivityTitle = Color(hex: 0x2C282B)
    let profileActivityTagBg = Color(hex: 0xF5F3F1)
    let profileActivityTagText = Color(hex: 0x2C282B)

    // Profile avatar
    let profileAvatarBorder = Color(hex: 0xFAFAF9)
    let profileAvatarEditBg = Color(hex: 0x432C3A)

    // Follow button
    let profileFollowButton = Color(hex: 0x432C3A)
    let profileFollowingButton = Color(hex: 0xF5F3F1)
    let profileFollowingText = Color(hex: 0x2C282B)

    // Settings tokens
    let settingsBackground = Color(hex: 0xFDFBF9)
    let settingsSectionBackground = Color.white
    let settingsSectionBorder = Color(hex: 0xE8E5E1, alpha: 0.6)
    let settingsRowLabel = Color(hex: 0x2C2826)
    let settingsRowSubtitle = Color(hex: 0x827C77)
    let settingsRowIcon = Color(hex: 0x462D3E)
    let settingsRowIconBackground = Color(hex: 0x462D3E, alpha: 0.08)
    let settingsDivider = Color(hex: 0xE8E5E1)
    let settingsChevron = Color(hex: 0xB0A9A3)
    let settingsHeaderLabel = Color(hex: 0x827C77)
    let settingsDestructiveText = Color(hex: 0xE5484D)
    let settingsDestructiveIcon = Color(hex: 0xE5484D)
    let settingsDestructiveIconBg = Color(hex: 0xE5484D, alpha: 0.08)
    let settingsToggleOn = Color(hex: 0x462D3E)

    // Edit profile tokens
    let editProfileFieldBackground = Color(hex: 0xF4F1EE)
    let editProfileFieldBorder = Color(hex: 0xE8E5E1)
    let editProfileFieldLabel = Color(hex: 0x827C77)
    let editProfileFieldText = Color(hex: 0x2C2826)
    let editProfileAvatarOverlay = Color(hex: 0x000000, alpha: 0.5)

    // Stats page tokens
    let statsBackground = Color(hex: 0xFAFAF9)
    let statsHeaderBackground = Color(hex: 0xFAFAF9, alpha: 0.8)
    let statsTitle = Color(hex: 0x2C282B)
    let statsSubtitle = Color(hex: 0x8A8387)
    let statsSectionTitle = Color(hex: 0x2C282B)

    // Stats overview card
    let statsOverviewCard = Color.white
    let statsOverviewCardBorder = Color(hex: 0xE8E3E1)
    let statsOverviewValue = Color(hex: 0x2C282B)
    let statsOverviewLabel = Color(hex: 0x8A8387)
    let statsOverviewDivider = Color(hex: 0xE8E3E1)

    // Stats category breakdown
    let statsAnime = Color(hex: 0xBA68C8)
    let statsAnimeBg = Color(hex: 0xF3EBF5, alpha: 0.5)
    let statsTvShow = Color(hex: 0x64B5F6)
    let statsTvShowBg = Color(hex: 0xEEF2F5, alpha: 0.5)
    let statsBook = Color(hex: 0xD4A373)
    let statsBookBg = Color(hex: 0xF5F1EB, alpha: 0.5)
    let statsGame = Color(hex: 0xFFA726)
    let statsGameBg = Color(hex: 0xFFF3E0, alpha: 0.5)
    let statsMovie = Color(hex: 0xE57373)
    let statsMovieBg = Color(hex: 0xFDECEC, alpha: 0.5)
    let statsManga = Color(hex: 0x66BB6A)
    let statsMangaBg = Color(hex: 0xE8F5E9, alpha: 0.5)

    // Stats streak & milestone
    let statsStreakFire = Color(hex: 0xE8712A)
    let statsStreakFireBg = Color(hex: 0xFDECE1, alpha: 0.6)
    let statsMilestoneGold = Color(hex: 0xD4A029)
    let statsMilestoneGoldBg = Color(hex: 0xFDF5E1, alpha: 0.5)

    // Stats progress bar
    let statsProgressTrack = Color(hex: 0xF0EBE8)
    let statsProgressFill = Color(hex: 0x462D3E)

    // Stats rating distribution
    let statsRatingBar = Color(hex: 0xDF8E63, alpha: 0.25)
    let statsRatingBarFill = Color(hex: 0xDF8E63)
    let statsRatingLabel = Color(hex: 0x8A8387)

    // Stats genre tag
    let statsGenreTag = Color(hex: 0xF5F3F1)
    let statsGenreTagText = Color(hex: 0x2C282B)
    let statsGenreTagBorder = Color(hex: 0xE8E3E1)

    // Tab bar tokens from Figma
    let tabBarBackground = Color(hex: 0xFAF8F6)
    let tabBarBorder = Color(hex: 0xE8E2DF)
    let tabBarInactive = Color(hex: 0x7C7176)
    let tabBarActive = Color(hex: 0x4A3243)
    let tabBarFab = Color(hex: 0x462D3E)
    let tabBarFabBorder = Color(hex: 0xFDFBF9)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
