import SwiftUI

struct MediaPosterImage: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 17.78
    var fallbackColor: Color = Color.nook.searchShimmerBase

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                fallbackPlaceholder
            case .empty:
                shimmerPlaceholder
            @unknown default:
                fallbackPlaceholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var fallbackPlaceholder: some View {
        fallbackColor
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: min(width, height) * 0.3))
                    .foregroundStyle(.white.opacity(0.4))
            }
    }

    private var shimmerPlaceholder: some View {
        ShimmerView()
    }
}

struct ShimmerView: View {
    @State private var isAnimating = false

    var body: some View {
        Color.nook.searchShimmerBase
            .opacity(isAnimating ? 0.4 : 0.8)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}
