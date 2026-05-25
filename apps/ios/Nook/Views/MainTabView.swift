import SwiftUI

enum Tab: CaseIterable {
    case home
    case search
    case library
    case groups

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .library: "Library"
        case .groups: "Groups"
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

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .search:
                    SearchView()
                case .library:
                    LibraryView()
                case .groups:
                    GroupsTabPlaceholder()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            NookTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Tab Bar

private struct NookTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.search)
            fabButton
            tabButton(.library)
            tabButton(.groups)
        }
        .padding(.horizontal, 16)
        .padding(.top, 7)
        .padding(.bottom, 0)
        .background {
            Color.nook.background
                .overlay(alignment: .top) {
                    Color.nook.tabBarBorder
                        .frame(height: 1)
                }
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(isActive ? tab.fillIcon : tab.boldIcon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)

                Text(tab.title)
                    .font(NookFont.tabLabel)
                    .textCase(.uppercase)
            }
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
        Button {
            // TODO: Create action
        } label: {
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
}

// MARK: - Placeholder Tabs


private struct GroupsTabPlaceholder: View {
    var body: some View {
        VStack {
            Text("Groups")
                .font(NookFont.headingMedium)
                .foregroundStyle(Color.nook.foreground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nook.background)
    }
}

#Preview {
    MainTabView(router: AppRouter())
}
