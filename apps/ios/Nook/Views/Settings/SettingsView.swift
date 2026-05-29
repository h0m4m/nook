import MessageUI
import Supabase
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var router: AppRouter

    // MARK: - Notification Preferences

    @State private var pushNotificationsEnabled = true
    @State private var activityNotifications = true
    @State private var communityNotifications = true
    @State private var reviewNotifications = true

    // MARK: - Appearance

    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system

    // MARK: - Interests

    @State private var showEditInterests = false

    // MARK: - Sheets

    @State private var showNotificationsSheet = false
    @State private var showAppearanceSheet = false
    @State private var showAboutSheet = false
    @State private var showMailCompose = false

    // MARK: - Destructive Alerts

    @State private var showClearCacheAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showLogoutConfirmation = false

    // MARK: - Feedback fallback

    @State private var showFeedbackCopiedAlert = false

    // MARK: - App Info

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    private let feedbackEmail = "claudevfz@gmail.com"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 20) {
                        accountSection
                        preferencesSection
                        contentSection
                        supportSection
                        dangerZoneSection
                        versionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 72)
                    .padding(.bottom, 40)
                }

                header
            }
            .background(Color.nook.settingsBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .alert("Clear Cache?", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    // TODO: Clear cached data
                }
            } message: {
                Text("This will clear all cached images and data. Your account and tracked media won't be affected.")
            }
            .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    // TODO: Delete account flow
                }
            } message: {
                Text("This will permanently delete your account, all tracked media, reviews, nooks, and community memberships. This cannot be undone.")
            }
            .alert("Log out?", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Log out", role: .destructive) {
                    Task {
                        try? await router.signOut()
                    }
                }
            } message: {
                Text("You'll need to sign in again to access your account.")
            }
            .alert("Email Copied", isPresented: $showFeedbackCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Our email address has been copied to your clipboard. Send us your feedback at \(feedbackEmail).")
            }
        }
        .sheet(isPresented: $showNotificationsSheet) {
            NotificationPreferencesSheet(
                pushEnabled: $pushNotificationsEnabled,
                activityEnabled: $activityNotifications,
                communityEnabled: $communityNotifications,
                reviewEnabled: $reviewNotifications
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.nook.settingsBackground)
        }
        .sheet(isPresented: $showAppearanceSheet) {
            AppearancePreferencesSheet(colorScheme: $appColorScheme)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.nook.settingsBackground)
        }
        .sheet(isPresented: $showEditInterests) {
            EditInterestsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.nook.settingsBackground)
        }
        .sheet(isPresented: $showAboutSheet) {
            AboutSheet(appVersion: appVersion, buildNumber: buildNumber)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.nook.settingsBackground)
        }
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(
                recipient: feedbackEmail,
                subject: "Nook Feedback (v\(appVersion))",
                body: "\n\n---\nApp Version: \(appVersion) (\(buildNumber))\niOS: \(UIDevice.current.systemVersion)\nDevice: \(UIDevice.current.model)"
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            navCircleButton(icon: "caret-left-bold") {
                dismiss()
            }

            Spacer()

            Text("Settings")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.settingsRowLabel)

            Spacer()

            // Invisible spacer to balance the back button
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
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

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ACCOUNT")

            settingsCard {
                settingsRow(
                    icon: "bell",
                    label: "Notifications",
                    subtitle: pushNotificationsEnabled ? "On" : "Off"
                ) {
                    showNotificationsSheet = true
                }
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PREFERENCES")

            settingsCard {
                settingsRow(
                    icon: "paint-brush-household",
                    label: "Appearance",
                    subtitle: appColorScheme.label
                ) {
                    showAppearanceSheet = true
                }

                settingsDivider

                settingsRow(
                    icon: "sparkle",
                    label: "Interests",
                    subtitle: "Manage your media interests"
                ) {
                    showEditInterests = true
                }
            }
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DATA")

            settingsCard {
                settingsRow(
                    icon: "export",
                    label: "Export Data",
                    subtitle: "Download your Nook data"
                ) {
                    // TODO: Export data
                }

                settingsDivider

                Button {
                    showClearCacheAlert = true
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: NookRadii.xs)
                            .fill(Color.nook.settingsRowIconBackground)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image("trash")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(Color.nook.settingsRowIcon)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Cache")
                                .font(NookFont.label)
                                .foregroundStyle(Color.nook.settingsRowLabel)

                            Text("Free up storage space")
                                .font(NookFont.caption)
                                .foregroundStyle(Color.nook.settingsRowSubtitle)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SUPPORT")

            settingsCard {
                settingsRow(
                    icon: "chat-dots",
                    label: "Send Feedback",
                    subtitle: "Help us improve Nook"
                ) {
                    sendFeedback()
                }

                settingsDivider

                settingsRow(
                    icon: "info",
                    label: "About",
                    subtitle: "Version \(appVersion)"
                ) {
                    showAboutSheet = true
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsCard {
                Button {
                    showLogoutConfirmation = true
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: NookRadii.xs)
                            .fill(Color.nook.settingsDestructiveIconBg)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image("sign-out")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(Color.nook.settingsDestructiveIcon)
                            }

                        Text("Log out")
                            .font(NookFont.label)
                            .foregroundStyle(Color.nook.settingsDestructiveText)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                settingsDivider

                Button {
                    showDeleteAccountAlert = true
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: NookRadii.xs)
                            .fill(Color.nook.settingsDestructiveIconBg)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image("trash")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(Color.nook.settingsDestructiveIcon)
                            }

                        Text("Delete Account")
                            .font(NookFont.label)
                            .foregroundStyle(Color.nook.settingsDestructiveText)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Version Footer

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Nook v\(appVersion) (\(buildNumber))")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.settingsRowSubtitle)

            Text("Made with love for media lovers")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.settingsChevron)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Feedback

    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showMailCompose = true
        } else {
            UIPasteboard.general.string = feedbackEmail
            showFeedbackCopiedAlert = true
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(NookFont.tabLabel)
            .tracking(1)
            .foregroundStyle(Color.nook.settingsHeaderLabel)
            .padding(.leading, 4)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.nook.settingsSectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.sm)
                .stroke(Color.nook.settingsSectionBorder, lineWidth: 1)
        }
    }

    private var settingsDivider: some View {
        Color.nook.settingsDivider
            .frame(height: 1)
            .padding(.leading, 66)
            .padding(.trailing, 16)
    }

    private func settingsRow(
        icon: String,
        label: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: NookRadii.xs)
                    .fill(Color.nook.settingsRowIconBackground)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Color.nook.settingsRowIcon)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(NookFont.label)
                        .foregroundStyle(Color.nook.settingsRowLabel)

                    Text(subtitle)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.settingsRowSubtitle)
                }

                Spacer()

                Image("caret-left-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.nook.settingsChevron)
                    .rotationEffect(.degrees(180))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Color Scheme

enum AppColorScheme: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .system: "Follow device settings"
        case .light: "Always use light mode"
        case .dark: "Always use dark mode"
        }
    }

    var icon: String {
        switch self {
        case .system: "gear"
        case .light: "sparkle"
        case .dark: "eye-slash-bold"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Notification Preferences Sheet

private struct NotificationPreferencesSheet: View {
    @Binding var pushEnabled: Bool
    @Binding var activityEnabled: Bool
    @Binding var communityEnabled: Bool
    @Binding var reviewEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Notifications")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.settingsRowLabel)
                .padding(.top, 20)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                toggleRow(
                    icon: "bell",
                    label: "Push Notifications",
                    subtitle: "Enable all notifications",
                    isOn: $pushEnabled
                )

                divider

                toggleRow(
                    icon: "heart",
                    label: "Activity",
                    subtitle: "Likes, follows, and mentions",
                    isOn: $activityEnabled
                )

                divider

                toggleRow(
                    icon: "users-three-bold",
                    label: "Communities",
                    subtitle: "New posts and replies",
                    isOn: $communityEnabled
                )

                divider

                toggleRow(
                    icon: "star",
                    label: "Reviews",
                    subtitle: "Reactions to your reviews",
                    isOn: $reviewEnabled
                )
            }
            .background(Color.nook.settingsSectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.sm)
                    .stroke(Color.nook.settingsSectionBorder, lineWidth: 1)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func toggleRow(
        icon: String,
        label: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: NookRadii.xs)
                .fill(Color.nook.settingsRowIconBackground)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.nook.settingsRowIcon)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.settingsRowLabel)

                Text(subtitle)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.settingsRowSubtitle)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.nook.settingsToggleOn)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Color.nook.settingsDivider
            .frame(height: 1)
            .padding(.leading, 66)
            .padding(.trailing, 16)
    }
}

// MARK: - Appearance Preferences Sheet

private struct AppearancePreferencesSheet: View {
    @Binding var colorScheme: AppColorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Appearance")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.settingsRowLabel)
                .padding(.top, 20)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                ForEach(Array(AppColorScheme.allCases.enumerated()), id: \.offset) { index, option in
                    Button {
                        colorScheme = option
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(option.icon)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color.nook.settingsRowIcon)
                                .frame(width: 36, height: 36)
                                .background(
                                    Color.nook.settingsRowIconBackground,
                                    in: RoundedRectangle(cornerRadius: NookRadii.xs)
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.label)
                                    .font(NookFont.labelBoldSmall)
                                    .foregroundStyle(Color.nook.settingsRowLabel)

                                Text(option.subtitle)
                                    .font(NookFont.caption)
                                    .foregroundStyle(Color.nook.settingsRowSubtitle)
                            }

                            Spacer()

                            if option == colorScheme {
                                Image("check-bold")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(Color.nook.settingsRowIcon)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < AppColorScheme.allCases.count - 1 {
                        Color.nook.settingsDivider.opacity(0.5)
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(Color.nook.settingsSectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.nook.settingsSectionBorder, lineWidth: 1)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - About Sheet

private struct AboutSheet: View {
    let appVersion: String
    let buildNumber: String

    var body: some View {
        VStack(spacing: 0) {
            Text("About")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.settingsRowLabel)
                .padding(.top, 20)
                .padding(.bottom, 24)

            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.nook.onboardingPrimary)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Text("N")
                            .font(.custom("Outfit-Bold", size: 32))
                            .foregroundStyle(.white)
                    }

                VStack(spacing: 4) {
                    Text("Nook")
                        .font(NookFont.outfitHeadingSmall)
                        .foregroundStyle(Color.nook.settingsRowLabel)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.settingsRowSubtitle)
                }

                Text("Your personal corner of the internet for collecting, reviewing, and sharing everything you love across movies, shows, books, games, anime, and manga.")
                    .font(NookFont.bodySmall)
                    .foregroundStyle(Color.nook.settingsRowSubtitle)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    @MainActor
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        nonisolated func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            Task { @MainActor in
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(router: AppRouter())
}
