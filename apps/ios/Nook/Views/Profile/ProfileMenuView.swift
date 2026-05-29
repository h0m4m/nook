import Supabase
import SwiftUI

struct ProfileMenuView: View {
    @Environment(\.dismiss) private var dismiss
    var router: AppRouter

    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var avatarURL: URL?
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    menuSections
                    logoutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.nook.profileMenuBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    closeButton
                }
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
        }
        .task {
            await loadUserInfo()
        }
    }

    // MARK: - Close Button

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26, *) {
            glassCloseButton
        } else {
            classicCloseButton
        }
    }

    @available(iOS 26, *)
    private var glassCloseButton: some View {
        Button { dismiss() } label: {
            Image("x-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var classicCloseButton: some View {
        Button { dismiss() } label: {
            Circle()
                .fill(Color.nook.segmentBackground)
                .frame(width: 30, height: 30)
                .overlay {
                    Image("x-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.nook.foreground)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.nook.secondary
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.nook.headerAvatarBorder, lineWidth: 1.5)
            }

            VStack(spacing: 4) {
                Text(displayName.isEmpty ? "Nook User" : displayName)
                    .font(NookFont.labelLarge)
                    .foregroundStyle(Color.nook.profileMenuName)

                if !email.isEmpty {
                    Text(email)
                        .font(NookFont.bodySmall)
                        .foregroundStyle(Color.nook.profileMenuEmail)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Menu Sections

    private var menuSections: some View {
        VStack(spacing: 0) {
            menuRow(
                icon: "user-circle",
                label: "Profile",
                iconColor: Color.nook.profileMenuRowIcon,
                iconBackground: Color.nook.profileMenuRowIconBackground
            )

            rowDivider

            menuRow(
                icon: "gear",
                label: "Settings",
                iconColor: Color.nook.profileMenuRowIcon,
                iconBackground: Color.nook.profileMenuRowIconBackground
            )

            rowDivider

            menuRow(
                icon: "chart-line",
                label: "Stats",
                iconColor: Color.nook.profileMenuRowIcon,
                iconBackground: Color.nook.profileMenuRowIconBackground
            )
        }
        .background(Color.nook.profileMenuSectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.sm)
                .stroke(Color.nook.profileMenuSectionBorder, lineWidth: 1)
        }
    }

    private func menuRow(
        icon: String,
        label: String,
        iconColor: Color,
        iconBackground: Color
    ) -> some View {
        Button {
            // TODO: Navigate to respective screens
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: NookRadii.xs)
                    .fill(iconBackground)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(iconColor)
                    }

                Text(label)
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.profileMenuRowLabel)

                Spacer()

                Image("caret-left-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.nook.profileMenuChevron)
                    .rotationEffect(.degrees(180))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Color.nook.profileMenuDivider
            .frame(height: 1)
            .padding(.leading, 66)
            .padding(.trailing, 16)
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: NookRadii.xs)
                    .fill(Color.nook.profileMenuLogoutIconBackground)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image("sign-out")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Color.nook.profileMenuLogoutIcon)
                    }

                Text("Log out")
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.profileMenuLogoutText)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.nook.profileMenuSectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.sm)
                .stroke(Color.nook.profileMenuSectionBorder, lineWidth: 1)
        }
    }

    // MARK: - Data Loading

    private func loadUserInfo() async {
        guard let user = try? await supabase.auth.session.user else { return }

        email = user.email ?? ""

        if let name = user.userMetadata["full_name"]?.value as? String {
            displayName = name
        }

        if let urlString = user.userMetadata["avatar_url"]?.value as? String {
            avatarURL = URL(string: urlString)
        }
    }
}

#Preview {
    ProfileMenuView(router: AppRouter())
}
