import Supabase
import SwiftUI

struct HomeView: View {
    @State private var userName = ""
    @State private var avatarURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HomeHeaderView(userName: userName, avatarURL: avatarURL)

            ScrollView {
                VStack(spacing: 0) {
                    ContinueTrackingSection(items: ContinueTrackingSection.mockItems)
                        .padding(.top, 8)

                    TrendingReviewsSection(items: TrendingReviewsSection.mockItems)
                        .padding(.top, 32)

                    PopularNooksSection(items: PopularNooksSection.mockItems)
                        .padding(.top, 32)
                }
                .padding(.bottom, 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nook.background)
        .task {
            await loadUserProfile()
        }
    }

    private func loadUserProfile() async {
        guard let user = try? await supabase.auth.session.user else { return }

        if let fullName = user.userMetadata["full_name"]?.stringValue {
            userName = fullName.components(separatedBy: " ").first ?? fullName
        } else if let email = user.email {
            userName = email.components(separatedBy: "@").first ?? email
        }

        if let urlString = user.userMetadata["avatar_url"]?.stringValue {
            avatarURL = URL(string: urlString)
        }
    }
}

// MARK: - JSON value helper

private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value): return value
        default: return nil
        }
    }
}

#Preview {
    HomeView()
}
