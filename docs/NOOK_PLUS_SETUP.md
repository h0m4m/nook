# Nook Plus — Subscription Setup

Nook Plus is the paid tier. Free stays generous (ads only, unlimited tracking,
full social). Plus removes ads, unlocks the full **Stats** page, and adds a
profile **PLUS** badge + accent.

Billing runs through **RevenueCat** on top of StoreKit. This doc is the
end-to-end checklist to take it live.

---

## Pricing

| Plan    | Price         | Product ID                 | Notes                           |
| ------- | ------------- | -------------------------- | ------------------------------- |
| Monthly | **$3.99/mo**  | `app.getnook.plus.monthly` | Impulse tier                    |
| Annual  | **$24.99/yr** | `app.getnook.plus.annual`  | Hero plan; **7-day free trial** |

No lifetime tier. (You can tune prices/IDs later — the client reads everything
from RevenueCat, so only the dashboard config needs to change.)

> Enroll in Apple's **Small Business Program** before launch → 15% commission
> instead of 30% (under $1M/yr).

---

## 1. App Store Connect

1. **Agreements** → accept _Paid Apps_; complete banking/tax. (Subscriptions
   won't load until this is done.)
2. **Apps → Nook → Subscriptions** → create a subscription group, e.g. `Nook Plus`.
3. Add two auto-renewable subscriptions:
   - `app.getnook.plus.monthly` — 1 month — $3.99
   - `app.getnook.plus.annual` — 1 year — $24.99
4. On the **annual** subscription add an **Introductory Offer → Free trial → 7 days**.
5. Fill in localized display name, description, and a review screenshot for each.
6. (Recommended) Enroll in **Apple Small Business Program**.

> Sandbox testing works as soon as the products are in "Ready to Submit" — you
> don't need full review to test purchases with a sandbox Apple ID.

## 2. RevenueCat dashboard

1. Create a project, add an **App** (platform iOS, bundle id `app.getnook`,
   upload the App Store Connect **In-App Purchase Key** / shared secret).
2. **Entitlements** → create one with identifier **`plus`**.
3. **Products** → import/add `app.getnook.plus.monthly` and
   `app.getnook.plus.annual`; attach both to the `plus` entitlement.
4. **Offerings** → use the `default` offering; add packages:
   - **Monthly** package → `app.getnook.plus.monthly`
   - **Annual** package → `app.getnook.plus.annual`
5. Copy the **public Apple API key** (`appl_…`) from Project → API Keys.

> The client keys off entitlement `plus` and offering `default` (and the
> `.monthly` / `.annual` package slots). Keep these identifiers as-is or update
> `SubscriptionManager.entitlementID` / the paywall accordingly.

## 3. iOS app key

Set the RevenueCat **public** key (safe to embed) as the `REVENUECAT_API_KEY`
build setting. It flows into `Info.plist` → read at launch by
`SubscriptionManager.configure()`.

- Quick: set it in the target build settings (Debug + Release), or
- Cleaner: put it in a `Secrets.xcconfig` (git-ignored) and reference
  `REVENUECAT_API_KEY = $(REVENUECAT_API_KEY)`.

If the key is empty the app simply runs with Nook Plus disabled (no crash).

## 4. Supabase — schema + webhook

The webhook mirrors entitlements onto `user_profiles.is_plus` so **other** users
can see a member's badge (the current user reads their own status from the SDK).

```bash
# Schema (adds is_plus / plus_expires_at; not user-writable)
supabase db push --project-ref wzakmmuxsosfybqufdsn

# Shared secret for the webhook (pick a strong random string)
supabase secrets set REVENUECAT_WEBHOOK_SECRET='<random-secret>' \
  --project-ref wzakmmuxsosfybqufdsn

# Deploy the function (JWT verification off — config.toml sets verify_jwt=false,
# pass the flag too in case the CLI ignores per-function config)
supabase functions deploy revenuecat-webhook --no-verify-jwt \
  --project-ref wzakmmuxsosfybqufdsn
```

Then in **RevenueCat → Integrations → Webhooks**:

- **URL**: `https://wzakmmuxsosfybqufdsn.supabase.co/functions/v1/revenuecat-webhook`
- **Authorization header value**: the same `<random-secret>` you set above.
- Send a **test event** → expect `200 { ok: true, test: true }`.

## 5. Verify the entitlement id (critical)

The app grants access off entitlement **`plus`** (`SubscriptionManager.entitlementID`).
In RevenueCat → **Entitlements**, confirm there's one with identifier **`plus`**
and that **both** `app.getnook.plus.monthly` / `app.getnook.plus.annual` are
attached. If it's named anything else, a purchase succeeds but `isPlus` never
flips (Stats stays locked, no badge) — update `entitlementID` to match.

> **Gotcha we hit (Jun 2026):** the `plus` entitlement showed "2 products," but
> they were the **Test Store** sample products (`yearly`/`monthly` under a default
> "Test Store" app), not the real App Store products. Symptom: every purchase came
> back `entitlements=[none]` while `activeSubscriptions` listed
> `app.getnook.plus.*`. Fix: attach the **real App Store** products
> (`app.getnook.plus.monthly` / `.annual`, under the "Nook" app) to `plus` and
> detach the Test Store ones. Verify in RevenueCat → Entitlements → `plus` that the
> attached products belong to your **App Store** app, not "Test Store."

## 6. Test the purchase — local (fast, no sandbox account)

A StoreKit configuration file (`apps/ios/Configuration.storekit`) is wired into
the **Nook** scheme, so buying in the simulator is instant and free:

1. **Run from Xcode** (▶) on a simulator, sign in normally.
2. **Profile → Stats → Get Nook Plus** → the paywall shows both plans + the
   7-day trial on annual.
3. Tap **Start Free Trial / Subscribe** → StoreKit's test sheet confirms instantly
   → the sheet dismisses, **full Stats unlock**, and the **PLUS** badge appears.
4. **Restore** works after deleting/reinstalling.

> The local config returns RevenueCat's `plus` entitlement via the dashboard
> product→entitlement mapping, so this exercises the whole client path. It does
> **not** fire the RevenueCat → Supabase webhook (do the sandbox test for that).

## 7. Test the purchase — sandbox (authoritative, tests the webhook)

1. In the **Nook** scheme → Run → Options, set **StoreKit Configuration = None**
   (so it uses the real sandbox instead of the local file).
2. Run on a **device** signed into a **sandbox** Apple ID (Settings → App Store →
   Sandbox Account) and buy through the paywall.
3. Confirm the webhook fired: `user_profiles.is_plus = true` for your user, and
   the **PLUS** badge shows on your profile **from another account**.

---

## What's gated (today)

| Area           | Free            | Nook Plus      |
| -------------- | --------------- | -------------- |
| Tracking       | Unlimited       | Unlimited      |
| Social / clubs | Full            | Full           |
| Ads            | Native in feeds | **None**       |
| Stats page     | Overview only   | **Full**       |
| Profile badge  | —               | **PLUS** badge |

---

# Ads (AdMob) — Setup

Free users see **native ads** spliced into vertical feeds (club post feeds and
the Library list, every 8 items) plus one card on Home between sections. Plus
subscribers see none — slots check `SubscriptionManager.isPlus` and render
nothing. Ads run on the **Google Mobile Ads SDK v12** (native advanced format).

**DEBUG always shows Google's test ads** (always fill, safe to tap); **RELEASE**
uses your real `ADMOB_NATIVE_UNIT_ID` — see `AdConfig`. This is deliberate: real
ads only serve to an **approved** AdMob account on a **published** app, so a dev
build requesting the real unit just gets `Account not approved yet`. Real ads
turn on automatically once the app ships and AdMob approves the account.

## 1. AdMob account

1. Create an app in [AdMob](https://apps.admob.com) (link it to the same Apple
   app). Copy the **App ID** — `ca-app-pub-XXXX~YYYY`.
2. Create a **Native** ad unit. Copy its **unit ID** — `ca-app-pub-XXXX/ZZZZ`.

## 2. iOS app IDs

Set in build settings (Debug + Release), or via a git-ignored `Secrets.xcconfig`:

- `ADMOB_APP_ID` → real App ID `ca-app-pub-5609964541403026~8159388740`. Flows to
  `Info.plist` → `GADApplicationIdentifier` (used in both configs).
- `ADMOB_NATIVE_UNIT_ID` → real native unit `ca-app-pub-5609964541403026/6818917145`.
  Only used in **RELEASE**; DEBUG always uses the test unit (see `AdConfig`).
- `ADMOB_TEST_DEVICE_IDS` → optional comma-separated device hashes to force test
  ads on a physical device when running a **release**-style build.

`Info.plist` already includes `NSUserTrackingUsageDescription` (the ATT prompt
copy) and Google's `SKAdNetworkItems` list.

## 3. How it behaves

- On a free user reaching **Home**, after a ~2s delay (lets the Plus entitlement
  resolve), the app shows the **ATT prompt**, starts the SDK, and begins loading
  ads. Plus users are never prompted and never load ads.
- Ads are cached per slot (`AdManager`), so scrolling reuses them.
- ATT "denied" still serves **non-personalized** ads (lower eCPM) — expected.

## 4. Test & verify

1. Run a **DEBUG** build as a **free** user → Home shows a native "Ad" card
   (test ad), plus every 8th item in a club feed (8+ posts) or Library (8+ items).
   Tap is safe — they're test ads.
2. Subscribe to Plus → ad cards disappear on next render.
3. Real ads only appear in a **release**/TestFlight build _after_ AdMob approves
   the account (see checklist) — a DEBUG build always shows test ads.

## 5. Before launch — checklist

Code-side ads (placement, Plus-gating, ATT prompt, test ads) are **done**, and the
real AdMob ids are wired. What's left is Google/store approval + privacy/consent:

- [x] **Real AdMob IDs** wired (`ADMOB_APP_ID` + `ADMOB_NATIVE_UNIT_ID`).
- [ ] **AdMob account approval** — new accounts return `Account not approved yet`
      until Google reviews them. Complete the AdMob account (payment/address) and
      link the **published** app; approval typically requires the app to be live on
      the App Store. Real ads won't serve until this clears.
      <https://support.google.com/admob/answer/9905175>
- [ ] **App Store privacy label** — in App Store Connect → App Privacy, declare
      what AdMob collects (Device ID / Identifiers + Usage Data, used for
      Third‑Party Advertising / Analytics). Must match the ATT prompt.
- [ ] **GDPR / consent (UMP)** — if you serve EEA/UK users, AdMob policy requires
      a consent form. Set up a message in AdMob → **Privacy & messaging**, then add
      Google's **UMP** SDK call on launch (small code add — not yet wired). ATT
      covers Apple's requirement; UMP covers Google's GDPR requirement.
- [ ] **SKAdNetworkItems** — `Info.plist` ships Google's current list for ad
      attribution. Refresh it from Google when you update the SDK (the AdMob SDK
      logs a runtime warning naming any missing networks).
- [ ] _(optional)_ **app-ads.txt** — host one on `getnook.app` and add it in AdMob
      to authorize your inventory (helps fill/eCPM, prevents spoofing).

> **Mediation later:** when volume justifies it, add AppLovin MAX (or AdMob
> mediation) to auction more demand for higher eCPM. Not needed at launch.

## Code map

- `Services/SubscriptionManager.swift` — RevenueCat wrapper, `isPlus`, offerings,
  purchase/restore, auth↔RevenueCat login sync.
- `Views/Profile/NookPlusPaywallView.swift` — paywall + `PlusBadge`.
- `Views/Profile/StatsView.swift` — teaser/gating.
- `Views/Profile/{My,Other}ProfileView.swift` — badge rendering.
- `supabase/functions/revenuecat-webhook/` — entitlement → `is_plus`.
- `supabase/migrations/20260606020000_nook_plus_subscription.sql` — columns.
- `Services/AdManager.swift` — Google Mobile Ads SDK start, ATT, native-ad cache
  (`AdConfig` holds the unit ids / test fallback).
- `Views/Ads/NativeAdFeedCard.swift` — `NativeAdFeedSlot` (gated) + the native ad
  card (`NativeAdView` bridge) + `AdSlot` placement helper.
- Feed injection: `Views/Communities/ClubDetailView.swift`,
  `Views/Library/LibraryView.swift`, `Views/Home/HomeView.swift`.
