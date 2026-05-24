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

    // Category badge tokens from Figma
    let badgeAnimeBg = Color(hex: 0xF3EBF5, alpha: 0.9)
    let badgeAnimeText = Color(hex: 0xBA68C8)
    let badgeTvShowBg = Color(hex: 0xEEF2F5, alpha: 0.9)
    let badgeTvShowText = Color(hex: 0x64B5F6)
    let badgeBookBg = Color(hex: 0xF5F1EB, alpha: 0.9)
    let badgeBookText = Color(hex: 0xD4A373)

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
