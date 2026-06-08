import AppTrackingTransparency
import Foundation
import GoogleMobileAds

/// Ad unit configuration.
///
/// **DEBUG always uses Google's TEST unit** — real ads only serve to an *approved*
/// AdMob account on a *published* app (an unapproved account returns "Account not
/// approved yet"), and test ads are always-fill + safe to tap. **RELEASE** uses the
/// real `ADMOB_NATIVE_UNIT_ID` (or no ads if it's unset). So real ads kick in
/// automatically once the app ships and the account is approved.
enum AdConfig {
    /// Google's official test native-advanced unit.
    private static let testNativeUnitID = "ca-app-pub-3940256099942544/3986624511"

    /// The native ad unit to request, or `nil` when ads should be disabled.
    static var nativeUnitID: String? {
        #if DEBUG
        return testNativeUnitID
        #else
        let id = Bundle.main.object(forInfoDictionaryKey: "ADMOB_NATIVE_UNIT_ID") as? String
        return (id?.isEmpty == false) ? id : nil
        #endif
    }

    /// Google's official test anchored-adaptive banner unit.
    private static let testBannerUnitID = "ca-app-pub-3940256099942544/2435281174"

    /// The anchored-adaptive banner unit, or `nil` when banners are disabled.
    /// DEBUG always uses the test unit (real ads need an approved account).
    static var bannerUnitID: String? {
        #if DEBUG
        return testBannerUnitID
        #else
        let id = Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_UNIT_ID") as? String
        return (id?.isEmpty == false) ? id : nil
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
    /// Observed so views (e.g. the bottom banner) can wait for ATT + SDK start.
    private(set) var isReady = false

    private override init() { super.init() }

    // MARK: - Lifecycle

    /// Requests ATT (once) then starts the SDK, flushing any queued slot loads.
    /// No-op if ads are disabled or already started.
    func startIfNeeded() {
        log("startIfNeeded — isEnabled=\(AdConfig.isEnabled) started=\(started) unit=\(AdConfig.nativeUnitID ?? "nil")")
        guard AdConfig.isEnabled, !started else { return }
        started = true
        Task { await requestATTThenStart() }
    }

    private func requestATTThenStart() async {
        if #available(iOS 14, *) {
            let status = await withCheckedContinuation { cont in
                ATTrackingManager.requestTrackingAuthorization { cont.resume(returning: $0) }
            }
            log("ATT status=\(status.rawValue)")
        }
        // Serve test ads to registered dev devices (safe to tap), even with the
        // real ad unit live. Must be set before the first ad request.
        let testIDs = AdConfig.testDeviceIDs
        if !testIDs.isEmpty {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testIDs
            log("test devices registered: \(testIDs)")
        }
        _ = await MobileAds.shared.start()
        isReady = true
        let queued = pending
        log("SDK started — flushing \(queued.count) queued slot(s): \(queued.sorted())")
        pending.removeAll()
        for key in queued { load(key) }
    }

    // MARK: - Slots

    /// The cached native ad for a slot, if one has loaded.
    func ad(for key: String) -> NativeAd? { loaded[key] }

    /// Ensures an ad is loading (or loaded) for a slot. Idempotent and cheap to
    /// call from `.task`. Queues until the SDK is ready.
    func requestAd(for key: String) {
        guard AdConfig.isEnabled else {
            log("requestAd(\(key)) IGNORED — ads disabled (no unit id)")
            return
        }
        if loaded[key] != nil || inFlight[key] != nil || failed.contains(key) {
            log("requestAd(\(key)) skipped — loaded=\(loaded[key] != nil) inFlight=\(inFlight[key] != nil) failed=\(failed.contains(key))")
            return
        }
        guard isReady else {
            log("requestAd(\(key)) queued — SDK not ready yet")
            pending.insert(key)
            return
        }
        load(key)
    }

    private func load(_ key: String) {
        guard let unit = AdConfig.nativeUnitID else { return }
        log("loading ad: slot=\(key) unit=\(unit)")
        let loader = AdLoader(adUnitID: unit, rootViewController: nil, adTypes: [.native], options: nil)
        loader.delegate = self
        inFlight[key] = loader
        keyByLoader[ObjectIdentifier(loader)] = key
        loader.load(Request())
    }

    private func log(_ message: String) {
        #if DEBUG
        print("🟡 [NookAds] \(message)")
        #endif
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
            log("✅ ad RECEIVED for slot \(key)")
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        let id = ObjectIdentifier(adLoader)
        let message = error.localizedDescription
        MainActor.assumeIsolated {
            guard let key = keyByLoader[id] else { return }
            failed.insert(key)
            clear(loaderID: id, key: key)
            log("❌ ad FAILED for slot \(key) — \(message)")
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
