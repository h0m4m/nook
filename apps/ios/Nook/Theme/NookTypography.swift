import SwiftUI

enum NookFont {
    static let displayLarge = Font.custom("PlusJakartaSans-Bold", size: 36, relativeTo: .largeTitle)

    static let headingLarge = Font.custom("PlusJakartaSans-Bold", size: 34, relativeTo: .largeTitle)
    static let headingMedium = Font.custom("PlusJakartaSans-SemiBold", size: 28, relativeTo: .title)
    static let headingSmall = Font.custom("PlusJakartaSans-SemiBold", size: 22, relativeTo: .title2)

    static let bodyLarge = Font.custom("PlusJakartaSans-Regular", size: 18, relativeTo: .body)
    static let bodyMedium = Font.custom("PlusJakartaSans-Regular", size: 15, relativeTo: .subheadline)
    static let bodySmall = Font.custom("PlusJakartaSans-Regular", size: 13, relativeTo: .footnote)

    static let labelLarge = Font.custom("PlusJakartaSans-SemiBold", size: 18, relativeTo: .body)
    static let label = Font.custom("PlusJakartaSans-Medium", size: 16, relativeTo: .subheadline)
    static let labelSmall = Font.custom("PlusJakartaSans-SemiBold", size: 14, relativeTo: .footnote)
    static let caption = Font.custom("PlusJakartaSans-Regular", size: 12, relativeTo: .caption)
    static let captionBold = Font.custom("PlusJakartaSans-Bold", size: 12, relativeTo: .caption)
    static let captionSemiBold = Font.custom("PlusJakartaSans-SemiBold", size: 12, relativeTo: .caption)
}
