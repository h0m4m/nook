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

// MARK: - Club Post Images (natural aspect, no hard crop)

/// Identifies which images (and where to start) a fullscreen viewer should show.
struct PostImageViewerState: Identifiable, Equatable {
    let id = UUID()
    let urls: [URL]
    let index: Int
}

/// A remote image that lays out at its *natural* aspect ratio instead of being
/// cropped into a fixed-height box. The ratio is clamped to a sane range so an
/// extreme panorama or very tall image can't blow out the surrounding layout.
///
/// - `fixedHeight == nil`: fills the available width; height follows the ratio
///   (used for a single full-width post image).
/// - `fixedHeight != nil`: lays out at that height with width following the ratio
///   (used for the horizontally-scrolling multi-image strip).
struct AspectRatioRemoteImage: View {
    let url: URL
    var cornerRadius: CGFloat = NookRadii.sm
    var fixedHeight: CGFloat? = nil
    /// Tallest (portrait) and widest (landscape) ratios we allow on a card.
    var minRatio: CGFloat = 0.75
    var maxRatio: CGFloat = 1.91

    @State private var ratio: CGFloat?

    private var displayRatio: CGFloat {
        min(max(ratio ?? (4.0 / 3.0), minRatio), maxRatio)
    }

    var body: some View {
        Group {
            if let fixedHeight {
                imageContent
                    .frame(width: fixedHeight * displayRatio, height: fixedHeight)
            } else {
                imageContent
                    .aspectRatio(displayRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: url) { await loadRatio() }
    }

    private var imageContent: some View {
        Color.nook.secondary
            .overlay {
                CachedRemoteImage(url: url, contentMode: .fill) { Color.nook.secondary }
            }
    }

    private func loadRatio() async {
        var image = ImageMemoryCache.shared.image(for: url)
        if image == nil {
            image = await ImageCacheStore.shared.image(for: url)
        }
        guard let image, image.size.height > 0 else { return }
        let r = image.size.width / image.size.height
        if abs((ratio ?? -1) - r) > 0.001 {
            withAnimation(.easeOut(duration: 0.2)) { ratio = r }
        }
    }
}

/// Renders a club post's image(s): a single image at natural aspect, or a
/// horizontally-scrolling strip for multiple. Tapping invokes `onTap(index)` so
/// the host can present a fullscreen viewer. Never crops to a hard ratio and
/// never overflows its container width.
struct ClubPostImageGallery: View {
    let urls: [URL]
    var cornerRadius: CGFloat = NookRadii.sm
    var rowHeight: CGFloat = 200
    var onTap: (Int) -> Void = { _ in }

    var body: some View {
        if urls.count == 1 {
            AspectRatioRemoteImage(url: urls[0], cornerRadius: cornerRadius)
                .contentShape(Rectangle())
                .onTapGesture { onTap(0) }
        } else if !urls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        AspectRatioRemoteImage(
                            url: url,
                            cornerRadius: cornerRadius,
                            fixedHeight: rowHeight
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onTap(index) }
                    }
                }
            }
        }
    }
}

// MARK: - Fullscreen Image Viewer

/// A pinch-to-zoom image for the fullscreen viewer. Fits the full image (no
/// crop), supports double-tap and pinch zoom, and panning while zoomed.
struct ZoomableImageView: View {
    let url: URL

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        CachedRemoteImage(url: url, contentMode: .fit) {
            ProgressView().tint(.white)
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(magnification)
        // Only claim drags while zoomed in — otherwise the recognizer eats the
        // TabView's horizontal swipe and you can't page between images at 1×.
        .simultaneousGesture(scale > 1 ? pan : nil)
        .onTapGesture(count: 2) { toggleZoom() }
        .onDisappear { reset() }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation(.easeOut(duration: 0.2)) { reset() }
                }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1 else { return }
                lastOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if scale > 1 {
                reset()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

/// Fullscreen, swipeable gallery for a post's images. Present via
/// `.fullScreenCover(item:)` with a `PostImageViewerState`.
struct FullscreenImageViewer: View {
    let urls: [URL]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(urls: [URL], startIndex: Int) {
        self.urls = urls
        _index = State(initialValue: max(0, min(startIndex, urls.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { i, url in
                    ZoomableImageView(url: url)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .statusBarHidden(true)
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
