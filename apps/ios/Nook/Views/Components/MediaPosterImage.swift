import SwiftUI

struct MediaPosterImage: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 17.78
    var fallbackColor: Color = Color.nook.searchShimmerBase

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                fallbackPlaceholder
            case .empty:
                shimmerPlaceholder
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

// MARK: - Image Cache

private actor ImageCacheStore {
    static let shared = ImageCacheStore()

    private let cache = NSCache<NSURL, UIImage>()
    private let urlCache: URLCache

    init() {
        // 50 MB memory, 200 MB disk
        urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
        cache.countLimit = 300
    }

    func image(for url: URL) async -> UIImage? {
        let nsURL = url as NSURL

        // 1. Check in-memory cache
        if let cached = cache.object(forKey: nsURL) {
            return cached
        }

        // 2. Check disk cache
        let request = URLRequest(url: url)
        if let data = urlCache.cachedResponse(for: request)?.data,
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: nsURL)
            return image
        }

        // 3. Download
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let image = UIImage(data: data) else { return nil }

            // Store in both caches
            let cachedResponse = CachedURLResponse(response: response, data: data)
            urlCache.storeCachedResponse(cachedResponse, for: request)
            cache.setObject(image, forKey: nsURL)

            return image
        } catch {
            return nil
        }
    }
}

// MARK: - Cached Async Image

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

private struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else {
                    phase = .failure
                    return
                }
                if let uiImage = await ImageCacheStore.shared.image(for: url) {
                    phase = .success(Image(uiImage: uiImage))
                } else {
                    phase = .failure
                }
            }
    }
}

// MARK: - Shimmer

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
