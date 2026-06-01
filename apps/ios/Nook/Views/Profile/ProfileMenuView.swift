import Supabase
import SwiftUI

struct ProfileMenuView: View {
    @Environment(\.dismiss) private var dismiss
    var router: AppRouter

    @State private var showLogoutConfirmation = false
    @State private var showStats = false
    @State private var showMyProfile = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showCreateClub = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
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

                closeButton
                    .padding(.top, 12)
                    .padding(.leading, 16)
            }
            .background(Color.nook.profileMenuBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
    }

    // MARK: - Close Button

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26, *) {
            Button { dismiss() } label: {
                Image("x-bold")
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
            Button { dismiss() } label: {
                Image("x-bold")
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

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            AsyncImage(url: router.currentUserAvatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Circle()
                        .fill(Color.nook.accent)
                        .overlay {
                            Text(String(router.currentUserDisplayName.prefix(1)).uppercased())
                                .font(NookFont.labelLarge)
                                .foregroundStyle(.white)
                        }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.nook.headerAvatarBorder, lineWidth: 1.5)
            }

            VStack(spacing: 4) {
                Text(router.currentUserDisplayName.isEmpty ? "Nook User" : router.currentUserDisplayName)
                    .font(NookFont.labelLarge)
                    .foregroundStyle(Color.nook.profileMenuName)

                if !router.currentUserUsername.isEmpty {
                    Text(router.currentUserUsername)
                        .font(NookFont.bodySmall)
                        .foregroundStyle(Color.nook.profileMenuEmail)
                }
            }

            Button {
                showEditProfile = true
            } label: {
                HStack(spacing: 6) {
                    Image("pencil-simple-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)

                    Text("Edit Profile")
                        .font(NookFont.captionSemiBold)
                }
                .foregroundStyle(Color.nook.profileMenuRowIcon)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(Color.nook.profileMenuRowIconBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
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
            ) {
                showMyProfile = true
            }

            rowDivider

            menuRow(
                icon: "gear",
                label: "Settings",
                iconColor: Color.nook.profileMenuRowIcon,
                iconBackground: Color.nook.profileMenuRowIconBackground
            ) {
                showSettings = true
            }

            rowDivider

            menuRow(
                icon: "chart-line",
                label: "Stats",
                iconColor: Color.nook.profileMenuRowIcon,
                iconBackground: Color.nook.profileMenuRowIconBackground
            ) {
                showStats = true
            }

            rowDivider

            menuRow(
                icon: "users-three-bold",
                label: "Create Club",
                iconColor: Color.nook.profileMenuRowIcon,
                iconBackground: Color.nook.profileMenuRowIconBackground
            ) {
                showCreateClub = true
            }
        }
        .background(Color.nook.profileMenuSectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.sm)
                .stroke(Color.nook.profileMenuSectionBorder, lineWidth: 1)
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .fullScreenCover(isPresented: $showMyProfile) {
            NavigationStack {
                MyProfileView(router: router)
                    .navigationDestination(for: ReviewItem.self) { review in
                        ReviewDetailView(review: review)
                    }
                    .navigationDestination(for: MediaDetailRoute.self) { route in
                        MediaDetailLoadingView(route: route)
                    }
                    .navigationDestination(for: UserProfile.self) { user in
                        OtherProfileView(profile: user)
                    }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(router: router)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.nook.settingsBackground)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(onSaved: {
                await router.refreshProfile()
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.nook.settingsBackground)
        }
        .sheet(isPresented: $showCreateClub) {
            CreateClubSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.nook.createClubBackground)
                .interactiveDismissDisabled()
        }
    }

    private func menuRow(
        icon: String,
        label: String,
        iconColor: Color,
        iconBackground: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            action?()
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

}

#Preview {
    ProfileMenuView(router: AppRouter())
}
