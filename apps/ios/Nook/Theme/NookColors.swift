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
