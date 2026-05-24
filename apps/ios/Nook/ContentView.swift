import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Nook")
                .font(NookFont.headingLarge)
                .foregroundStyle(Color.nook.foreground)
            Text("Your personal space, reimagined.")
                .font(NookFont.bodyMedium)
                .foregroundStyle(Color.nook.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nook.background)
    }
}

#Preview {
    ContentView()
}
