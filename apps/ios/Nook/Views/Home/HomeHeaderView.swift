import SwiftUI

struct HomeHeaderView: View {
    let userName: String
    let avatarURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            avatar
            greetingText
            Spacer()
            notificationButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 24)
        .background(.clear)
    }

    // MARK: - Avatar

    private var avatar: some View {
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
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.nook.headerAvatarBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 1, y: -0.5)
    }

    // MARK: - Greeting

    private var greetingText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(greeting.uppercased())
                .font(NookFont.tabLabel)
                .tracking(0.5)
                .foregroundStyle(Color.nook.headerGreeting)

            Text(userName)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.headerName)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    // MARK: - Notification Button

    private var notificationButton: some View {
        Button {
            // TODO: Notifications
        } label: {
            Circle()
                .fill(Color.nook.headerIconBackground)
                .frame(width: 40, height: 40)
                .overlay {
                    Circle()
                        .stroke(Color.nook.headerIconBorder, lineWidth: 1)
                }
                .overlay {
                    Image("bell-fill")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.nook.headerIconForeground)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        HomeHeaderView(
            userName: "humam",
            avatarURL: nil
        )
        Spacer()
    }
    .background(Color.nook.background)
}
