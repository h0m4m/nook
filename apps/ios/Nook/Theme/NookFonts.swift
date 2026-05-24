import CoreGraphics
import CoreText
import SwiftUI

enum NookFonts {
    nonisolated(unsafe) private static var registered = false

    static func registerFonts() {
        guard !registered else { return }
        registered = true

        let fontNames = [
            "PlusJakartaSans-Regular",
            "PlusJakartaSans-Medium",
            "PlusJakartaSans-SemiBold",
            "PlusJakartaSans-Bold",
        ]

        for name in fontNames {
            // Try root bundle first, then Resources/Fonts subdirectory
            let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Resources/Fonts")

            guard let fontURL = url else {
                print("Nook: Font file \(name).ttf not found in bundle")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                // Already registered via Info.plist is fine
            }
        }
    }
}
