import Foundation
import RevenueCat
import Supabase

/// Outcome of a purchase/restore attempt, so the paywall can react without
/// treating a user-initiated cancellation as an error.
enum PurchaseOutcome: Equatable {
    case success
    case cancelled
    case failed(String)
}

/// App-wide entitlement state for **Nook Plus**, backed by RevenueCat.
///
/// RevenueCat is the source of truth for whether the *current* user is Plus
/// (`isPlus`). The server-side webhook mirrors the same state onto
/// `user_profiles.is_plus` so *other* users can see a member's badge — see
/// `supabase/functions/revenuecat-webhook`.
///
/// Lifecycle:
/// 1. `configure()` once at launch (AppDelegate), before anything else.
/// 2. `startAuthSync()` once from the root view — keeps the RevenueCat
///    app-user-id pinned to the Supabase user id so purchases (and the webhook)
///    map back to the right account.
@MainActor
@Observable
final class SubscriptionManager: NSObject, PurchasesDelegate {
    static let shared = SubscriptionManager()

    /// Entitlement identifier configured in the RevenueCat dashboard.
    static let entitlementID = "plus"

    /// Whether the signed-in user currently has an active Nook Plus entitlement.
    private(set) var isPlus = false

    /// Offerings fetched from RevenueCat (products + pricing).
    private(set) var offerings: Offerings?
    private(set) var isLoadingOfferings = false
    private(set) var purchaseInProgress = false

    private var configured = false
    private var authTask: Task<Void, Never>?

    private override init() { super.init() }

    // MARK: - Convenience package accessors

    /// The monthly package from the current offering, if present.
    var monthlyPackage: Package? {
        offerings?.current?.monthly
            ?? offerings?.current?.availablePackages.first { $0.packageType == .monthly }
    }

    /// The annual package from the current offering, if present.
    var annualPackage: Package? {
        offerings?.current?.annual
            ?? offerings?.current?.availablePackages.first { $0.packageType == .annual }
    }

    // MARK: - Setup

    /// Configures the RevenueCat SDK. Safe to call multiple times. The API key
    /// is read from `Info.plist` (`RevenueCatAPIKey`) so it isn't hard-coded.
    func configure() {
        guard !configured else { return }
        configured = true

        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String) ?? ""
        guard !apiKey.isEmpty else {
            // No key configured (e.g. local dev before REVENUECAT_API_KEY is set).
            // Skip configuration so the SDK is never used uninitialised; Nook Plus
            // simply stays unavailable (isPlus == false).
            configured = false
            #if DEBUG
            print("⚠️ RevenueCatAPIKey is empty — set REVENUECAT_API_KEY. Nook Plus disabled.")
            #endif
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
    }

    /// Mirrors Supabase auth into RevenueCat: logs in with the Supabase user id
    /// (so `app_user_id` == our user id) and clears state on sign-out.
    func startAuthSync() {
        guard authTask == nil else { return }
        authTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .initialSession, .signedIn:
                    if let uid = session?.user.id.uuidString {
                        await self.login(userId: uid)
                    }
                case .signedOut:
                    await self.logout()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Auth handoff

    private func login(userId: String) async {
        guard Purchases.isConfigured else { return }
        do {
            let result = try await Purchases.shared.logIn(userId)
            update(with: result.customerInfo)
        } catch {
            #if DEBUG
            print("RevenueCat logIn failed: \(error.localizedDescription)")
            #endif
        }
        await loadOfferings()
    }

    private func logout() async {
        isPlus = false
        guard Purchases.isConfigured else { return }
        _ = try? await Purchases.shared.logOut()
    }

    // MARK: - Offerings / purchase / restore

    func loadOfferings() async {
        guard Purchases.isConfigured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        offerings = try? await Purchases.shared.offerings()
    }

    /// Refreshes entitlement state from RevenueCat (e.g. on app foreground or
    /// when opening the paywall) to catch renewals/expirations.
    func refresh() async {
        guard Purchases.isConfigured else { return }
        if let info = try? await Purchases.shared.customerInfo() {
            update(with: info)
        }
        if offerings == nil { await loadOfferings() }
    }

    @discardableResult
    func purchase(_ package: Package) async -> PurchaseOutcome {
        guard Purchases.isConfigured else { return .failed("Subscriptions are unavailable right now.") }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        log("purchase started: product=\(package.storeProduct.productIdentifier) offering=\(package.offeringIdentifier)")
        do {
            let result = try await Purchases.shared.purchase(package: package)
            update(with: result.customerInfo)
            logCustomerInfo(result.customerInfo, context: "after purchase (userCancelled=\(result.userCancelled))")
            if result.userCancelled {
                log("purchase cancelled by user")
                return .cancelled
            }
            if isPlus { return .success }
            // Purchase went through but the `plus` entitlement isn't active —
            // almost always a RevenueCat dashboard mapping issue (the products
            // aren't attached to an entitlement whose id matches `entitlementID`).
            log("⚠️ purchase COMPLETED but entitlement '\(Self.entitlementID)' is NOT active — check RevenueCat → Entitlements (id + attached products)")
            return .failed("Your purchase didn't complete. Please try again.")
        } catch {
            log("❌ purchase error: \(String(describing: error))")
            return .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func restore() async -> PurchaseOutcome {
        guard Purchases.isConfigured else { return .failed("Subscriptions are unavailable right now.") }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        log("restore started")
        do {
            let info = try await Purchases.shared.restorePurchases()
            update(with: info)
            logCustomerInfo(info, context: "after restore")
            if isPlus { return .success }
            log("⚠️ restore found no active '\(Self.entitlementID)' entitlement")
            return .failed("No active Nook Plus subscription found to restore.")
        } catch {
            log("❌ restore error: \(String(describing: error))")
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - PurchasesDelegate

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in self.update(with: customerInfo) }
    }

    // MARK: - Internal

    private func update(with info: CustomerInfo) {
        isPlus = info.entitlements[Self.entitlementID]?.isActive == true
    }

    // MARK: - Diagnostics (DEBUG only)

    /// Greppable one-liner — filter the Xcode console for "[NookPlus]".
    private func log(_ message: String) {
        #if DEBUG
        print("💳 [NookPlus] \(message)")
        #endif
    }

    /// Dumps the entitlement/subscription state from a CustomerInfo — the key
    /// signal for "purchase succeeded but didn't unlock" (entitlement mapping).
    private func logCustomerInfo(_ info: CustomerInfo, context: String) {
        #if DEBUG
        let ents = info.entitlements.all
            .map { "\($0.key)=\($0.value.isActive ? "active" : "inactive")" }
            .sorted()
            .joined(separator: ", ")
        let subs = info.activeSubscriptions.sorted().joined(separator: ", ")
        log("\(context) → isPlus=\(isPlus); looking for entitlement '\(Self.entitlementID)'; "
            + "entitlements=[\(ents.isEmpty ? "none" : ents)]; "
            + "activeSubscriptions=[\(subs.isEmpty ? "none" : subs)]; "
            + "appUserID=\(Purchases.shared.appUserID)")
        #endif
    }
}
