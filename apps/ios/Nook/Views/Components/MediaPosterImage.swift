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

// MARK: - Synchronous in-memory image cache

/// A thread-safe in-memory image cache that can be read *synchronously* from the
/// main actor. This is what lets an already-loaded poster paint on the very first
/// frame instead of flashing a shimmer while an async cache lookup hops actors.
/// `NSCache` is internally thread-safe, so `@unchecked Sendable` is sound here.
final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 500
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

// MARK: - Image Cache (memory → disk → network)

private actor ImageCacheStore {
    static let shared = ImageCacheStore()

    private let memory = ImageMemoryCache.shared
    private let urlCache: URLCache

    init() {
        // 50 MB memory, 200 MB disk
        urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
    }

    func image(for url: URL) async -> UIImage? {
        // 1. Check in-memory cache (also reachable synchronously from views)
        if let cached = memory.image(for: url) {
            return cached
        }

        // 2. Check disk cache
        let request = URLRequest(url: url)
        if let data = urlCache.cachedResponse(for: request)?.data,
           let image = UIImage(data: data) {
            memory.insert(image, for: url)
            return image
        }

        // 3. Download
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let image = UIImage(data: data) else { return nil }

            // Store in both caches
            let cachedResponse = CachedURLResponse(response: response, data: data)
            urlCache.storeCachedResponse(cachedResponse, for: request)
            memory.insert(image, for: url)

            return image
        } catch {
            return nil
        }
    }

    /// Warm the cache for a batch of URLs concurrently, skipping ones already
    /// in memory. Used to fetch posters before a list scrolls into view.
    func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls where memory.image(for: url) == nil {
                group.addTask { _ = await self.image(for: url) }
            }
        }
    }
}

// MARK: - Image Prefetcher (fire-and-forget)

/// Kick off background downloads for a set of poster URLs so they're warm by the
/// time the user scrolls to them. Stores call this right after a feed loads.
enum ImagePrefetcher {
    static func prefetch(_ urls: [URL?]) {
        let unique = Array(Set(urls.compactMap { $0 }))
        guard !unique.isEmpty else { return }
        Task.detached(priority: .utility) {
            await ImageCacheStore.shared.prefetch(unique)
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

    @State private var phase: CachedImagePhase

    init(url: URL?, @ViewBuilder content: @escaping (CachedImagePhase) -> Content) {
        self.url = url
        self.content = content
        // Paint already-cached images on the first frame — no shimmer flash.
        if let url, let cached = ImageMemoryCache.shared.image(for: url) {
            _phase = State(initialValue: .success(Image(uiImage: cached)))
        } else {
            _phase = State(initialValue: .empty)
        }
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else {
                    phase = .failure
                    return
                }
                // Fast path: synchronous warm-cache hit, no flicker.
                if let cached = ImageMemoryCache.shared.image(for: url) {
                    phase = .success(Image(uiImage: cached))
                    return
                }
                // Reused cell now showing a different (uncached) URL — drop the
                // stale image so we shimmer instead of showing the wrong poster.
                if case .success = phase { phase = .empty }
                if let uiImage = await ImageCacheStore.shared.image(for: url) {
                    phase = .success(Image(uiImage: uiImage))
                } else {
                    phase = .failure
                }
            }
    }
}

// MARK: - Cached Remote Image (banners, avatars, non-poster imagery)

/// A remote image backed by the shared memory→disk→network cache, painting an
/// already-cached image on the first frame (no late load / pop-in). Shows
/// `placeholder` until the image resolves. Use for club banners, avatars, etc.
struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .empty, .failure:
                placeholder()
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
