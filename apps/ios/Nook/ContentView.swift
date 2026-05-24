import SwiftUI

struct ContentView: View {
    var router: AppRouter

    @State private var isSigningOut = false

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Text("Nook")
                .font(NookFont.headingLarge)
                .foregroundStyle(Color.nook.foreground)
            Text("Your personal space, reimagined.")
                .font(NookFont.bodyMedium)
                .foregroundStyle(Color.nook.mutedForeground)

            Spacer()

            Button {
                isSigningOut = true
                Task {
                    try? await router.signOut()
                    isSigningOut = false
                }
            } label: {
                if isSigningOut {
                    ProgressView()
                        .tint(Color.nook.mutedForeground)
                } else {
                    Text("Sign Out")
                        .font(NookFont.labelSmall)
                        .foregroundStyle(Color.nook.mutedForeground)
                }
            }
            .disabled(isSigningOut)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nook.background)
    }
}

#Preview {
    ContentView(router: AppRouter())
}
