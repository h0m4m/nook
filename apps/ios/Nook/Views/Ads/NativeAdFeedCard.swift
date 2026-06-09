import GoogleMobileAds
import SwiftUI
import UIKit

// MARK: - Slot placement helper

/// Computes where native ads sit in a homogeneous feed: one slot after every
/// `interval` items. Keys are stable strings so `AdManager` can cache an ad per
/// slot across scrolls and re-renders.
enum AdSlot {
    static let interval = 6

    /// All slot keys for a feed of `count` items (used to kick off loads when the
    /// feed appears).
    static func keys(prefix: String, count: Int, interval: Int = interval) -> [String] {
        guard count >= interval else { return [] }
        return stride(from: interval, through: count, by: interval).map { "\(prefix)-ad-\($0)" }
    }

    /// Whether an ad slot follows the item at `index` (0-based).
    static func hasSlot(after index: Int, interval: Int = interval) -> Bool {
        (index + 1) % interval == 0
    }

    /// The slot key for the ad following the item at `index`.
    static func key(prefix: String, after index: Int) -> String { "\(prefix)-ad-\(index + 1)" }
}

// MARK: - Gated slot

/// Renders a native ad card for free users once one has loaded for `key`.
/// Plus subscribers — and slots with no ad yet — render nothing (no gap).
/// Loading is kicked off by the host feed (see `requestAd`), not here.
struct NativeAdFeedSlot: View {
    let key: String
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AdManager.self) private var ads

    var body: some View {
        if !subscriptions.isPlus, let ad = ads.ad(for: key) {
            NativeAdCardView(nativeAd: ad)
        }
    }
}

// MARK: - Card chrome

/// Feed-matched chrome around the native ad content (white card, soft border &
/// shadow, fixed height so the media view absorbs slack).
private struct NativeAdCardView: View {
    let nativeAd: NativeAd
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 6) {
            NativeAdContainer(nativeAd: nativeAd)
                .frame(height: 300)
                .background(Color.nook.card)
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                        .stroke(Color.nook.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)

            // Plus upsell — deliberately OUTSIDE the ad's tappable area so it can't
            // cause accidental ad clicks (and stays AdMob-policy clean).
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 4) {
                    Image("x-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 9, height: 9)
                    Text("Remove ads")
                        .font(NookFont.caption)
                }
                .foregroundStyle(Color.nook.mutedForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPaywall) {
            NookPlusPaywallView()
        }
    }
}

// MARK: - UIKit bridge

/// Wraps `NativeAdView` (UIKit) — required so taps on the registered asset views
/// (headline, icon, media, CTA) are handled by the SDK and counted as clicks.
private struct NativeAdContainer: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.backgroundColor = .clear

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFill
        icon.clipsToBounds = true
        icon.layer.cornerRadius = 8
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 40).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let headline = UILabel()
        headline.font = .systemFont(ofSize: 15, weight: .bold)
        headline.textColor = UIColor(Color.nook.foreground)
        headline.numberOfLines = 2

        let advertiser = UILabel()
        advertiser.font = .systemFont(ofSize: 12, weight: .regular)
        advertiser.textColor = UIColor(Color.nook.mutedForeground)
        advertiser.numberOfLines = 1

        let badge = PaddedLabel()
        badge.text = "Ad"
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = UIColor(Color.nook.accent)
        badge.backgroundColor = UIColor(Color.nook.accent.opacity(0.12))
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let titleStack = UIStackView(arrangedSubviews: [headline, advertiser])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let header = UIStackView(arrangedSubviews: [icon, titleStack, badge])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 10

        let body = UILabel()
        body.font = .systemFont(ofSize: 13)
        body.textColor = UIColor(Color.nook.mutedForeground)
        body.numberOfLines = 2

        let media = MediaView()
        media.clipsToBounds = true
        media.layer.cornerRadius = 12
        media.contentMode = .scaleAspectFill
        media.setContentHuggingPriority(.defaultLow, for: .vertical)
        media.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let cta = UIButton(type: .system)
        cta.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        cta.setTitleColor(UIColor(Color.nook.primaryForeground), for: .normal)
        cta.backgroundColor = UIColor(Color.nook.primary)
        cta.layer.cornerRadius = 14
        // The SDK handles CTA taps via callToActionView, so it must not capture
        // touches itself.
        cta.isUserInteractionEnabled = false
        cta.translatesAutoresizingMaskIntoConstraints = false
        cta.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let stack = UIStackView(arrangedSubviews: [header, body, media, cta])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -16),
        ])

        adView.headlineView = headline
        adView.advertiserView = advertiser
        adView.bodyView = body
        adView.iconView = icon
        adView.mediaView = media
        adView.callToActionView = cta
        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        (adView.headlineView as? UILabel)?.text = nativeAd.headline

        let secondary = nativeAd.advertiser ?? nativeAd.store
        (adView.advertiserView as? UILabel)?.text = secondary
        adView.advertiserView?.isHidden = secondary == nil

        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.bodyView?.isHidden = (nativeAd.body ?? "").isEmpty

        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.iconView?.isHidden = nativeAd.icon?.image == nil

        adView.mediaView?.mediaContent = nativeAd.mediaContent

        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionView?.isHidden = (nativeAd.callToAction ?? "").isEmpty

        // Required, and only after the asset views are populated.
        adView.nativeAd = nativeAd
    }
}

/// UILabel with small horizontal padding for the "Ad" badge.
private final class PaddedLabel: UILabel {
    private let inset = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right,
                      height: s.height + inset.top + inset.bottom)
    }
}
