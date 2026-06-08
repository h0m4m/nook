import RevenueCat
import SwiftUI

/// The Nook Plus upsell. Presented as a sheet from the Stats teaser (and any
/// other "go Plus" entry point). Reads pricing live from RevenueCat and falls
/// back gracefully while offerings load.
struct NookPlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptions

    /// Which package the CTA will purchase. Defaults to annual (the hero plan).
    @State private var selection: PlanSelection = .annual
    @State private var errorMessage: String?
    @State private var showError = false

    enum PlanSelection { case annual, monthly }

    private var selectedPackage: Package? {
        switch selection {
        case .annual: subscriptions.annualPackage ?? subscriptions.monthlyPackage
        case .monthly: subscriptions.monthlyPackage ?? subscriptions.annualPackage
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.nook.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    hero
                    featureList
                    planOptions
                    ctaSection
                    legalLinks
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 32)
            }

            closeBar
        }
        .task { await subscriptions.refresh() }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Close bar

    private var closeBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.nook.mutedForeground)
                    .frame(width: 36, height: 36)
                    .background(Color.nook.secondary, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.nook.accent.opacity(0.15))
                    .frame(width: 76, height: 76)
                Image("sparkle")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)
                    .foregroundStyle(Color.nook.accent)
            }

            Text("Nook Plus")
                .font(NookFont.outfitHeadingMedium)
                .foregroundStyle(Color.nook.foreground)

            Text("Go ad-free, unlock your full Stats, and stand out with a Plus badge.")
                .font(NookFont.bodyMedium)
                .foregroundStyle(Color.nook.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 14) {
            featureRow(icon: "eye-slash", title: "No ads", subtitle: "An uninterrupted, clean feed.")
            featureRow(icon: "chart-line", title: "Full Stats", subtitle: "Streaks, ratings, genres & milestones.")
            featureRow(icon: "seal-check", title: "Plus badge", subtitle: "A badge + accent on your profile.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nook.card, in: RoundedRectangle(cornerRadius: NookRadii.sm))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.sm)
                .stroke(Color.nook.border, lineWidth: 1)
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: NookRadii.xs)
                .fill(Color.nook.accent.opacity(0.12))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.nook.accent)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.foreground)
                Text(subtitle)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.mutedForeground)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Plan options

    private var planOptions: some View {
        VStack(spacing: 12) {
            if let annual = subscriptions.annualPackage {
                planCard(
                    package: annual,
                    isSelected: selection == .annual,
                    title: "Annual",
                    badge: "BEST VALUE",
                    trailing: perMonthString(for: annual).map { "\($0)/mo" },
                    trialNote: trialNote(for: annual)
                ) { selection = .annual }
            }
            if let monthly = subscriptions.monthlyPackage {
                planCard(
                    package: monthly,
                    isSelected: selection == .monthly,
                    title: "Monthly",
                    badge: nil,
                    trailing: nil,
                    trialNote: trialNote(for: monthly)
                ) { selection = .monthly }
            }

            if subscriptions.offerings == nil && subscriptions.isLoadingOfferings {
                ProgressView().tint(Color.nook.primary).padding(.vertical, 24)
            }
        }
    }

    private func planCard(
        package: Package,
        isSelected: Bool,
        title: String,
        badge: String?,
        trailing: String?,
        trialNote: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.nook.accent : Color.nook.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.nook.accent).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(NookFont.labelBold)
                            .foregroundStyle(Color.nook.foreground)
                        if let badge {
                            Text(badge)
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.primaryForeground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.nook.accent, in: Capsule())
                        }
                    }
                    if let trialNote {
                        Text(trialNote)
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.accent)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.foreground)
                    if let trailing {
                        Text(trailing)
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.mutedForeground)
                    }
                }
            }
            .padding(16)
            .background(Color.nook.card, in: RoundedRectangle(cornerRadius: NookRadii.sm))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.sm)
                    .stroke(isSelected ? Color.nook.accent : Color.nook.border, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await buy() }
            } label: {
                ZStack {
                    if subscriptions.purchaseInProgress {
                        ProgressView().tint(Color.nook.primaryForeground)
                    } else {
                        Text(ctaTitle)
                            .font(NookFont.labelBold)
                            .foregroundStyle(Color.nook.primaryForeground)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.nook.primary, in: RoundedRectangle(cornerRadius: NookRadii.sm))
            }
            .buttonStyle(.plain)
            .disabled(selectedPackage == nil || subscriptions.purchaseInProgress)
            .opacity(selectedPackage == nil ? 0.5 : 1)

            Text(ctaSubtitle)
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.mutedForeground)
                .multilineTextAlignment(.center)
        }
    }

    private var ctaTitle: String {
        if let pkg = selectedPackage, trialNote(for: pkg) != nil { return "Start Free Trial" }
        return "Subscribe"
    }

    private var ctaSubtitle: String {
        guard let pkg = selectedPackage else { return "Cancel anytime in Settings." }
        if let note = trialNote(for: pkg) {
            return "\(note), then \(pkg.storeProduct.localizedPriceString). Cancel anytime."
        }
        return "Auto-renews at \(pkg.storeProduct.localizedPriceString). Cancel anytime."
    }

    // MARK: - Legal

    private var legalLinks: some View {
        HStack(spacing: 18) {
            Button("Restore") { Task { await restore() } }
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.mutedForeground)

            Link("Terms", destination: URL(string: "https://getnook.app/terms")!)
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.mutedForeground)

            Link("Privacy", destination: URL(string: "https://getnook.app/privacy")!)
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.mutedForeground)
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func buy() async {
        guard let package = selectedPackage else { return }
        let outcome = await subscriptions.purchase(package)
        handle(outcome)
    }

    private func restore() async {
        let outcome = await subscriptions.restore()
        handle(outcome)
    }

    private func handle(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .success:
            dismiss()
        case .cancelled:
            break
        case .failed(let message):
            errorMessage = message
            showError = true
        }
    }

    // MARK: - Pricing helpers

    /// "7-day free trial" (or similar) if the package has an introductory offer.
    private func trialNote(for package: Package) -> String? {
        guard let intro = package.storeProduct.introductoryDiscount, intro.price == 0 else { return nil }
        let count = intro.subscriptionPeriod.value
        let unit: String
        switch intro.subscriptionPeriod.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "day"
        }
        let plural = count == 1 ? "" : "s"
        return "\(count)-\(unit)\(plural) free trial"
    }

    /// Per-month equivalent for an annual plan, using the product's own currency
    /// formatter so it matches the App Store locale.
    private func perMonthString(for package: Package) -> String? {
        guard package.packageType == .annual else { return nil }
        let monthly = package.storeProduct.price / 12
        guard let formatter = package.storeProduct.priceFormatter else { return nil }
        return formatter.string(from: monthly as NSDecimalNumber)
    }
}

// MARK: - Plus badge

/// Small "PLUS" chip shown next to a member's name on their profile.
struct PlusBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image("sparkle")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 9, height: 9)
            Text("PLUS")
                .font(NookFont.captionBold)
        }
        .foregroundStyle(Color.nook.accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.nook.accent.opacity(0.12), in: Capsule())
    }
}

#Preview {
    NookPlusPaywallView()
        .environment(SubscriptionManager.shared)
}
