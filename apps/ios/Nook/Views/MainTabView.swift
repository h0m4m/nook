import SwiftUI

enum Tab: CaseIterable {
    case home
    case search
    case library
    case groups

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Discover"
        case .library: "Library"
        case .groups: "Clubs"
        }
    }

    var boldIcon: String {
        switch self {
        case .home: "house-bold"
        case .search: "magnifying-glass-bold"
        case .library: "books-bold"
        case .groups: "users-three-bold"
        }
    }

    var fillIcon: String {
        switch self {
        case .home: "house-fill"
        case .search: "magnifying-glass-fill"
        case .library: "books-fill"
        case .groups: "users-three-fill"
        }
    }
}

struct MainTabView: View {
    var router: AppRouter

    @State private var selectedTab: Tab = .home
    @State private var navPath = NavigationPath()
    @State private var isFabMenuOpen = false
    @State private var showTrackMediaSheet = false
    @State private var showCreateNookSheet = false
    @State private var showProfileMenu = false
    @State private var pushRouter = PushRouter.shared
    // Feed stores live here, above the per-tab views, so switching tabs keeps
    // their data in memory and renders instantly instead of refetching.
    @State private var homeStore = HomeStore()
    @State private var libraryVM = LibraryViewModel()
    @State private var clubsVM = CommunitiesViewModel()
    @State private var searchVM = SearchViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $navPath) {
                Group {
                    switch selectedTab {
                    case .home:
                        HomeView(
                            router: router,
                            store: homeStore,
                            onAvatarTapped: {
                                showProfileMenu = true
                            },
                            onNotificationsTapped: {
                                navPath.append(NotificationsRoute())
                            },
                            onStartTracking: {
                                selectedTab = .search
                            },
                            onSeeAllTracking: {
                                selectedTab = .library
                            }
                        )
                    case .search:
                        SearchView(viewModel: searchVM)
                    case .library:
                        LibraryView(viewModel: libraryVM)
                    case .groups:
                        ClubsView(viewModel: clubsVM)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationDestination(for: ClubItem.self) { club in
                    ClubDetailView(club: club)
                }
                .navigationDestination(for: MediaDetail.self) { media in
                    MediaDetailView(media: media)
                }
                .navigationDestination(for: MediaDetailRoute.self) { route in
                    MediaDetailLoadingView(route: route)
                }
                .navigationDestination(for: ClubPost.self) { post in
                    PostDetailView(post: post)
                }
                .navigationDestination(for: ReviewItem.self) { review in
                    ReviewDetailView(review: review)
                }
                .navigationDestination(for: NookItem.self) { nook in
                    NookDetailView(nook: nook)
                }
                .navigationDestination(for: DiscoverNooksRoute.self) { _ in
                    DiscoverNooksView()
                }
                .navigationDestination(for: UserProfile.self) { user in
                    if user.isCurrentUser {
                        MyProfileView(router: router)
                    } else {
                        OtherProfileView(profile: user)
                    }
                }
                .navigationDestination(for: NotificationsRoute.self) { _ in
                    NotificationsView()
                }
            }

            if navPath.isEmpty {
                if isFabMenuOpen {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { closeFabMenu() }
                        .transition(.opacity)
                }

                NookBottomBar(
                    selectedTab: $selectedTab,
                    isFabMenuOpen: $isFabMenuOpen,
                    onCreateNook: {
                        showCreateNookSheet = true
                    },
                    onTrackMedia: {
                        showTrackMediaSheet = true
                    }
                )
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showCreateNookSheet) {
            CreateNookSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.nook.detailBackground)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showTrackMediaSheet) {
            TrackMediaSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.nook.searchBackground)
        }
        .sheet(isPresented: $showProfileMenu) {
            ProfileMenuView(router: router)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.nook.profileMenuBackground)
        }
        // A tapped push notification routes here (set by AppDelegate via PushRouter).
        .onChange(of: pushRouter.pendingRoute) { _, _ in applyPendingPushRoute() }
        .task {
            applyPendingPushRoute()  // handle a tap that cold-launched the app
            // Warm every tab up front so the first visit is already populated
            // instead of showing a loading state.
            homeStore.loadIfNeeded()
            await libraryVM.loadIfNeeded()
            await clubsVM.loadIfNeeded()
        }
    }

    /// Navigate to whatever a tapped notification pointed at, then clear it.
    private func applyPendingPushRoute() {
        guard let route = pushRouter.pendingRoute else { return }
        selectedTab = .home
        switch route {
        case .club(let id):
            navPath.append(ClubItem(navigationId: id))
        case .profile(let id, let name, let avatarURL):
            navPath.append(UserProfile.reference(id: id, displayName: name, avatarURL: avatarURL))
        case .notifications:
            navPath.append(NotificationsRoute())
        }
        pushRouter.pendingRoute = nil
    }

    private func closeFabMenu() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isFabMenuOpen = false
        }
    }
}

// MARK: - Bottom Bar

private struct NookBottomBar: View {
    @Binding var selectedTab: Tab
    @Binding var isFabMenuOpen: Bool
    var onCreateNook: () -> Void
    var onTrackMedia: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            LiquidGlassBottomBar(
                selectedTab: $selectedTab,
                isFabMenuOpen: $isFabMenuOpen,
                onCreateNook: onCreateNook,
                onTrackMedia: onTrackMedia
            )
        } else {
            ClassicBottomBar(
                selectedTab: $selectedTab,
                isFabMenuOpen: $isFabMenuOpen,
                onCreateNook: onCreateNook,
                onTrackMedia: onTrackMedia
            )
        }
    }
}

// MARK: - Liquid Glass Bottom Bar (iOS 26+)

@available(iOS 26, *)
private struct LiquidGlassBottomBar: View {
    @Binding var selectedTab: Tab
    @Binding var isFabMenuOpen: Bool
    var onCreateNook: () -> Void
    var onTrackMedia: () -> Void
    @Namespace private var tabHighlight

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            if isFabMenuOpen {
                fabMenuContent
                    .transition(.blurReplace)
            } else {
                tabBarContent
                    .transition(.blurReplace)
            }
        }
    }

    private var tabBarContent: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .capsule)

            fabButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, -8)
    }

    private var fabMenuContent: some View {
        HStack(spacing: 10) {
            fabMenuItem(icon: "grid-four-bold", label: "Create Nook") {
                closeFabMenu()
                onCreateNook()
            }

            fabMenuItem(icon: "bookmark-simple-bold", label: "Track Media") {
                closeFabMenu()
                onTrackMedia()
            }

            Button { closeFabMenu() } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, -8)
    }

    private func fabMenuItem(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)

                Text(label)
                    .font(NookFont.labelSmall)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            withAnimation(.smooth(duration: 0.3)) {
                selectedTab = tab
            }
        } label: {
            Image(isActive ? tab.fillIcon : tab.boldIcon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            .background {
                if isActive {
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .matchedGeometryEffect(id: "tabHighlight", in: tabHighlight)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var fabButton: some View {
        Button { openFabMenu() } label: {
            Image("plus-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }

    private func openFabMenu() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isFabMenuOpen = true
        }
    }

    private func closeFabMenu() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isFabMenuOpen = false
        }
    }
}

// MARK: - Classic Bottom Bar (iOS < 26)

private struct ClassicBottomBar: View {
    @Binding var selectedTab: Tab
    @Binding var isFabMenuOpen: Bool
    var onCreateNook: () -> Void
    var onTrackMedia: () -> Void

    var body: some View {
        Group {
            if isFabMenuOpen {
                fabMenuContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                tabBarContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var tabBarContent: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.search)
            fabButton
            tabButton(.library)
            tabButton(.groups)
        }
        .padding(.horizontal, 16)
        .padding(.top, 7)
        .padding(.bottom, -14)
        .background {
            Color.nook.background
                .overlay(alignment: .top) {
                    Color.nook.tabBarBorder
                        .frame(height: 1)
                }
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private var fabMenuContent: some View {
        HStack(spacing: 10) {
            fabMenuItem(icon: "grid-four-bold", label: "Create Nook") {
                closeFabMenu()
                onCreateNook()
            }

            fabMenuItem(icon: "bookmark-simple-bold", label: "Track Media") {
                closeFabMenu()
                onTrackMedia()
            }

            Button { closeFabMenu() } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.tabBarInactive)
                    .frame(width: 44, height: 44)
                    .background(Color.nook.segmentBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, -8)
        .background {
            Color.nook.background
                .overlay(alignment: .top) {
                    Color.nook.tabBarBorder
                        .frame(height: 1)
                }
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private func fabMenuItem(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)

                Text(label)
                    .font(NookFont.labelSmall)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.nook.tabBarFab)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            Image(isActive ? tab.fillIcon : tab.boldIcon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundStyle(
                isActive
                    ? Color.nook.tabBarActive
                    : Color.nook.tabBarInactive
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fabButton: some View {
        Button { openFabMenu() } label: {
            Circle()
                .fill(Color.nook.tabBarFab)
                .frame(width: 56, height: 56)
                .overlay {
                    Circle()
                        .stroke(Color.nook.tabBarFabBorder, lineWidth: 4)
                }
                .shadow(color: .black.opacity(0.1), radius: 7.5, y: 5)
                .shadow(color: .black.opacity(0.1), radius: 3, y: -2)
                .overlay {
                    Image("plus-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .offset(y: -14)
        .frame(maxWidth: .infinity)
    }

    private func openFabMenu() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isFabMenuOpen = true
        }
    }

    private func closeFabMenu() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isFabMenuOpen = false
        }
    }
}


#Preview {
    MainTabView(router: AppRouter())
        .environment(SubscriptionManager.shared)
}
