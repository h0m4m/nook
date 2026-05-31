# Nook Implementation Plan 2.0

> From functional prototype to TestFlight-ready. Fixes remaining gaps, removes all mock data, and polishes the experience.

**Date**: 2026-05-30
**Current state**: All 12 build prompts complete. Auth, search, detail, tracking, library, profiles, reviews, nooks, clubs, follows, activity feed, notifications, and settings are all wired to real Supabase data. Media catalog caching (DB-first search, staleness re-fetch) is deployed.

---

## Gap 1 — Home Sections: Remove Mock Fallbacks

**Problem**: ContinueTracking, ActivityFeed, TrendingReviews, and PopularNooks on Home fall back to mock data when DB is empty. New users see fake data.

**Fix**:

- Replace `mockItems` fallbacks with empty states ("Start tracking media to see your progress here", "Follow people to see their activity", etc.)
- Keep the section headers but show an empty card or a CTA when no real data exists
- Remove all `static let mockItems` from ContinueTrackingSection, ActivityFeedSection, TrendingReviewsSection, PopularNooksSection

**Files**: HomeView.swift, ContinueTrackingSection.swift, ActivityFeedSection.swift, TrendingReviewsSection.swift, PopularNooksSection.swift

---

## Gap 2 — StatsView: Wire Remaining Sections

**Problem**: Streak, top genres, monthly activity, and milestones in StatsView are still hardcoded mock data.

**Fix**:

- **Top genres**: Aggregate genres from `tracked_media` joined with `media_items.genres`. Count occurrences across all tracked items.
- **Monthly activity**: Count `tracked_media` rows by month (last 6 months) using `created_at`.
- **Streak**: Calculate consecutive days with a `tracked_media` entry (query `created_at` dates, find longest consecutive run ending today).
- **Milestones**: Check real counts against thresholds (First Steps: tracked ≥ 1, Dedicated Viewer: completed ≥ 50, Century Club: completed ≥ 100, Critic's Eye: reviews ≥ 25, Tastemaker: total review likes ≥ 10).
- **Avg rating**: Compute from `tracked_media.score` where score is not null.
- **Hours spent**: Skip for now (we don't track watch time).

**Files**: StatsView.swift, possibly a new RPC function for complex aggregations

---

## Gap 3 — CreateNookSheet: Persist Media Items

**Problem**: When creating a nook, the "Add Media" search works (real API), but selected media items don't get persisted as `nook_items` rows because `MediaSearchResult` doesn't carry `dbId` at that point.

**Fix**:

- When user taps "Add" on a search result in the nook creator, call `media-detail` Edge Function to ensure the item exists in `media_items` and get the `db_id`.
- Store the `db_id` alongside each added item.
- On publish, call `NookService.addItems()` with the collected `db_id`s and notes.
- This means the "Add" button should trigger a quick background detail fetch (or at minimum, since search results already auto-upsert to `media_items`, query `media_items` by source+source_id to get the UUID).

**Files**: CreateNookSheet.swift, NookService.swift

---

## Gap 4 — Club & Post Comments: Wire to DB

**Problem**: PostDetailView and NookDetailView comments sections use mock data. The service methods exist but the UI doesn't call them.

**Fix**:

- **PostDetailView**: Load comments from `ClubService.getComments(postId:)` on appear. Wire `sendComment()` to call `ClubService.addComment()`. Wire like button to call `ClubService.likePost()`/`unlikePost()`.
- **NookDetailView**: Comments are a future feature (nooks don't have a comments table in the schema). Remove mock comments or show "Comments coming soon".

**Files**: PostDetailView.swift, NookDetailView.swift

---

## Gap 5 — CommunitiesView: Real Club Cards with Banner Images

**Problem**: Club cards use `bannerColor` from the mock `ClubItem` type. Real clubs from DB have `banner_url` for uploaded images, but the card UI doesn't render them.

**Fix**:

- Update `ClubCard` in CommunitiesView to use `AsyncImage` for `club.bannerURL` when available, falling back to the category-based color.
- `ClubItem` already has the data (`init(from: ClubRow)` sets `bannerColor` from category). Add `bannerURL` to `ClubItem` from `ClubRow.bannerUrl`.

**Files**: CommunitiesView.swift

---

## Gap 6 — Realtime Updates

**Problem**: Activity feed, notifications, and club posts only update on view appear or pull-to-refresh. No live updates.

**Fix** (scope: basic, not full websocket):

- Add a timer-based refresh (every 60s) for notification badge count on Home
- Activity feed and club posts: rely on pull-to-refresh (acceptable for v1)
- Full Supabase Realtime (websocket subscriptions) is a post-v1 enhancement

**Files**: HomeView.swift

---

## Gap 7 — Error Toasts/Banners

**Problem**: Errors are captured in ViewModel `error` properties but most views don't display them visually. Users see silent failures.

**Fix**:

- Create a reusable `ErrorBanner` component (red-tinted banner at top of scroll content, with dismiss button)
- Add it to: LibraryView, CommunitiesView, MediaDetailView, ClubDetailView
- SearchView already shows errors inline

**Files**: New ErrorBanner component, LibraryView.swift, CommunitiesView.swift, MediaDetailView.swift, ClubDetailView.swift

---

## Implementation Order

| #   | Gap                                | Effort | Priority |
| --- | ---------------------------------- | ------ | -------- |
| 1   | Home mock fallbacks → empty states | Small  | High     |
| 3   | Nook items persistence             | Medium | High     |
| 4   | Post/Nook comments wiring          | Small  | High     |
| 5   | Club card banner images            | Small  | Medium   |
| 7   | Error toasts/banners               | Small  | Medium   |
| 2   | StatsView remaining sections       | Medium | Medium   |
| 6   | Realtime badge refresh             | Small  | Low      |

---

## Media Catalog Caching Status

| Step                                                    | Status      |
| ------------------------------------------------------- | ----------- |
| Search results auto-upsert to `media_items`             | ✅ Deployed |
| Detail view upserts full detail to `media_items`        | ✅ Deployed |
| DB-first search (skip provider if ≥10 cached matches)   | ✅ Deployed |
| Staleness re-fetch (re-fetch if `updated_at` > 30 days) | ✅ Deployed |
| Cron resync of popular+stale items                      | Post-launch |

The caching system is complete for v1. The DB grows as users search and view media. Over time, most searches will be served from cache without hitting providers.
