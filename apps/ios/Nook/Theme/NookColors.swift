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
    let clubDetailBannerGradient = Color(hex: 0x000000, alpha: 0.6)
    let clubDetailAvatarBorder = Color(hex: 0xFDFCF9)

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
