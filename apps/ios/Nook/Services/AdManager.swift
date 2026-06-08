import AppTrackingTransparency
import Foundation
import GoogleMobileAds

/// Ad unit configuration. Real IDs come from build settings (Info.plist); in
/// DEBUG we fall back to Google's official test units so ads render before the
/// AdMob account is wired up. In RELEASE, an unconfigured unit means **no ads**
/// (we never ship test ads).
enum AdConfig {
    /// Google's official test native-advanced unit.
    private static let testNativeUnitID = "ca-app-pub-3940256099942544/3986624511"

    /// The native ad unit to request, or `nil` when ads should be disabled.
    static var nativeUnitID: String? {
        if let id = Bundle.main.object(forInfoDictionaryKey: "ADMOB_NATIVE_UNIT_ID") as? String,
           !id.isEmpty {
            return id
        }
        #if DEBUG
        return testNativeUnitID
        #else
        return nil
        #endif
    }

    /// Whether ads are configured at all (gates SDK start + ATT).
    static var isEnabled: Bool { nativeUnitID != nil }

    /// AdMob test-device hashes (from `ADMOB_TEST_DEVICE_IDS`, comma-separated).
    /// Devices listed here are served **test** ads — safe to tap during dev —
    /// even with the real ad unit configured. The SDK prints a device's hash on
    /// its first ad request; add it here to click-test without risking the
    /// account for invalid traffic. Simulators are always test devices.
    static var testDeviceIDs: [String] {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ADMOB_TEST_DEVICE_IDS") as? String,
              !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

/// App-wide native-ad provider for the free tier.
///
/// Responsibilities:
/// - Start the Google Mobile Ads SDK once (after an ATT prompt), lazily — only
///   when a non-Plus user actually reaches an ad-bearing screen.
/// - Load and **cache native ads by a stable string key** (one per feed slot),
///   so scrolling a slot off/on screen reuses the same ad instead of
///   re-requesting. Views observe `ads` and re-render when one arrives.
///
/// Gating is the caller's job: Plus users' slots never call `requestAd`, and
/// `startIfNeeded()` is only invoked for non-subscribers. See `NativeAdFeedSlot`.
@MainActor
@Observable
final class AdManager: NSObject, NativeAdLoaderDelegate {
    static let shared = AdManager()

    /// Loaded native ads, keyed by slot. Observed — drives slot rendering.
    private var loaded: [String: NativeAd] = [:]

    @ObservationIgnored private var inFlight: [String: AdLoader] = [:]
    @ObservationIgnored private var keyByLoader: [ObjectIdentifier: String] = [:]
    @ObservationIgnored private var failed: Set<String> = []
    @ObservationIgnored private var pending: Set<String> = []
    @ObservationIgnored private var started = false
    @ObservationIgnored private var ready = false

    private override init() { super.init() }

    // MARK: - Lifecycle

    /// Requests ATT (once) then starts the SDK, flushing any queued slot loads.
    /// No-op if ads are disabled or already started.
    func startIfNeeded() {
        guard AdConfig.isEnabled, !started else { return }
        started = true
        Task { await requestATTThenStart() }
    }

    private func requestATTThenStart() async {
        if #available(iOS 14, *) {
            await withCheckedContinuation { cont in
                ATTrackingManager.requestTrackingAuthorization { _ in cont.resume() }
            }
        }
        // Serve test ads to registered dev devices (safe to tap), even with the
        // real ad unit live. Must be set before the first ad request.
        let testIDs = AdConfig.testDeviceIDs
        if !testIDs.isEmpty {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testIDs
        }
        _ = await MobileAds.shared.start()
        ready = true
        let queued = pending
        pending.removeAll()
        for key in queued { load(key) }
    }

    // MARK: - Slots

    /// The cached native ad for a slot, if one has loaded.
    func ad(for key: String) -> NativeAd? { loaded[key] }

    /// Ensures an ad is loading (or loaded) for a slot. Idempotent and cheap to
    /// call from `.task`. Queues until the SDK is ready.
    func requestAd(for key: String) {
        guard AdConfig.isEnabled else { return }
        if loaded[key] != nil || inFlight[key] != nil || failed.contains(key) { return }
        guard ready else { pending.insert(key); return }
        load(key)
    }

    private func load(_ key: String) {
        guard let unit = AdConfig.nativeUnitID else { return }
        let loader = AdLoader(adUnitID: unit, rootViewController: nil, adTypes: [.native], options: nil)
        loader.delegate = self
        inFlight[key] = loader
        keyByLoader[ObjectIdentifier(loader)] = key
        loader.load(Request())
    }

    // MARK: - NativeAdLoaderDelegate
    // The SDK invokes these on the main thread, so `assumeIsolated` is safe. We
    // pass only Sendable values across the isolation boundary (the loader's
    // ObjectIdentifier + an unchecked box for the non-Sendable NativeAd).

    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        let id = ObjectIdentifier(adLoader)
        let box = UncheckedSendableBox(nativeAd)
        MainActor.assumeIsolated {
            guard let key = keyByLoader[id] else { return }
            loaded[key] = box.value
            clear(loaderID: id, key: key)
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        let id = ObjectIdentifier(adLoader)
        let message = error.localizedDescription
        MainActor.assumeIsolated {
            guard let key = keyByLoader[id] else { return }
            failed.insert(key)
            clear(loaderID: id, key: key)
            #if DEBUG
            print("AdManager: slot \(key) failed — \(message)")
            #endif
        }
    }

    private func clear(loaderID: ObjectIdentifier, key: String) {
        inFlight[key] = nil
        keyByLoader[loaderID] = nil
    }
}

/// Carries a non-Sendable value across an isolation boundary that we know is
/// safe (the SDK delivers ad callbacks on the main thread).
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
