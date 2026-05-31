import SwiftUI

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.nook.settingsDestructiveIcon)

            Text(message)
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.settingsDestructiveText)
                .lineLimit(2)

            Spacer(minLength: 0)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.nook.settingsDestructiveText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.nook.settingsDestructiveIconBg)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
    }
}
