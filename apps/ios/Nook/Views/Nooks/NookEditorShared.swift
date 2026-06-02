import SwiftUI

// MARK: - Change Notification

extension Notification.Name {
    /// Posted whenever a nook is created, edited, or deleted so list surfaces
    /// (Library, Profile) can refresh.
    static let nooksDidChange = Notification.Name("nooksDidChange")
}

// MARK: - Settings Picker Sheet (shared by Create + Edit)

struct NookSettingsPickerSheet<T: Equatable>: View {
    let title: String
    let options: [(value: T, icon: String, label: String, subtitle: String)]
    let selected: T
    var onSelect: (T) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(title)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color(hex: 0x1C1918))
                .padding(.top, 20)
                .padding(.bottom, 20)

            // Options
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button {
                        onSelect(option.value)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(option.icon)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color(hex: 0x43313D))
                                .frame(width: 36, height: 36)
                                .background(
                                    Color(hex: 0xF2EFEE),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.label)
                                    .font(NookFont.labelBoldSmall)
                                    .foregroundStyle(Color(hex: 0x1C1918))

                                Text(option.subtitle)
                                    .font(NookFont.caption)
                                    .foregroundStyle(Color(hex: 0x78716C))
                            }

                            Spacer()

                            if option.value == selected {
                                Image("check-bold")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(Color(hex: 0x43313D))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < options.count - 1 {
                        Rectangle()
                            .fill(Color(hex: 0xE6E2E0).opacity(0.5))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
