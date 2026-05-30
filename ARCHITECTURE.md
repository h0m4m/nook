# Nook Architecture & System Design

> Detailed technical architecture for how every system works under the hood. This is the engineering companion to `IMPLEMENTATION_PLAN.md` — that doc says _what_ to build in what order, this doc says _how_ each system is designed.

**Date**: 2026-05-29

---

## Table of Contents

1. [Current Architecture Assessment](#1-current-architecture-assessment)
2. [Target Architecture Overview](#2-target-architecture-overview)
3. [Media Fetching System](#3-media-fetching-system)
4. [Data Storage Strategy](#4-data-storage-strategy)
5. [Caching Architecture](#5-caching-architecture)
6. [Image Loading Pipeline](#6-image-loading-pipeline)
7. [State Management & Data Flow](#7-state-management--data-flow)
8. [Service Layer Design](#8-service-layer-design)
9. [Edge Function Design](#9-edge-function-design)
10. [Realtime & Notifications](#10-realtime--notifications)
11. [Error Handling Strategy](#11-error-handling-strategy)
12. [Offline & Degradation](#12-offline--degradation)
13. [Security Architecture](#13-security-architecture)
14. [Performance Budget](#14-performance-budget)

---

## 1. Current Architecture Assessment

### What Exists Today

The app uses a **flat architecture** — no service layer, no view models, no caching:

```
View (@State mock data) → UI
View (.task) → supabase.auth.session (inline) → UI
```

**Patterns currently in use:**

- `@Observable` only on `AppRouter` (auth routing)
- `@State` for all view-local data (mock arrays, selection state, sheet booleans)
- `@Binding` for prop-drilling between parent/child (tracking sheet ↔ library item)
- Global `supabase` singleton called directly from views
- `try?` with silent failures everywhere — no error surfaces
- `Task.sleep(for: .milliseconds(400))` debounce pattern in search (correct approach, keep it)
- `NavigationStack` with typed `navigationDestination(for:)` using `Hashable` models
- No `@Environment` objects beyond system ones
- No image caching — `Image(assetName)` for mock, `AsyncImage(url:)` for avatar only
- Only dependency: Supabase Swift SDK v2.46.0

### What We Keep

- **Navigation structure** — `NavigationStack` with `NavigationPath` and typed destinations. Works well, don't change it.
- **Debounce pattern** — `searchTask?.cancel()` → `Task.sleep` → `Task.isCancelled` check. Correct Swift concurrency approach.
- **Sheet presentation patterns** — `Binding(get:set:)` for syncing state on sheet dismiss. Clever, keep it.
- **Design token system** — `Color.nook.*`, `NookFont.*`, `NookRadii.*`. Complete. Never duplicate.
- **iOS 26+ conditional patterns** — `#available(iOS 26, *)` with fallbacks. Already done right everywhere.

### What We Change

- **Add service layer** — views should not call Supabase or APIs directly
- **Add `@Observable` view models** for screens with complex data loading
- **Add typed error handling** — no more `try?` swallowing errors
- **Add image caching** — can't rely on `AsyncImage` default behavior for hundreds of media posters
- **Add a local cache** (UserDefaults/SwiftData) for offline-first patterns
- **Add environment injection** for services instead of global singletons

---

## 2. Target Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                        VIEWS                             │
│  (SwiftUI — @State for local, @Bindable for VM)         │
│  HomeView, SearchView, LibraryView, MediaDetailView...  │
└────────────────────────┬────────────────────────────────┘
                         │ owns / observes
┌────────────────────────▼────────────────────────────────┐
│                    VIEW MODELS                           │
│  (@Observable classes — one per complex screen)          │
│  SearchViewModel, LibraryViewModel, MediaDetailVM...    │
│  Simple screens (Settings, Profile) stay @State-only    │
└────────────────────────┬────────────────────────────────┘
                         │ calls
┌────────────────────────▼────────────────────────────────┐
│                   SERVICE LAYER                          │
│  (Protocol-based, injected via @Environment)             │
│  MediaAPIService, TrackingService, ReviewService...     │
│  Each service owns its caching logic                    │
└───────┬────────────────┬─────────────────┬──────────────┘
        │                │                 │
   Supabase SDK    Edge Functions     Local Cache
   (DB + Auth +    (API Proxy)       (UserDefaults
    Storage +                        + URLCache +
    Realtime)                        in-memory)
```

### Key Principles

1. **Views are dumb** — they render state and dispatch user intents. No networking in views.
2. **View models are screen-scoped** — they hold screen state and orchestrate service calls. One VM per screen that has async loading.
3. **Services are domain-scoped** — one per business domain. They own caching, error mapping, and data transformation. They are `@Observable` singletons injected via environment.
4. **Edge Functions are the API firewall** — all third-party API keys live server-side. The iOS app never sees a TheTVDB key.
5. **Supabase is the single source of truth** for user data. Local cache is a read optimization, not a write-through layer.

---

## 3. Media Fetching System

This is the core technical challenge — routing search/detail requests to 3 different APIs with different auth methods, response shapes, rate limits, and image URL patterns.

### Architecture Decision: Edge Functions as Proxy

**Why not call APIs directly from iOS?**

- API keys (TheTVDB) would be in the app binary — extractable via reverse engineering
- TheTVDB requires Bearer token auth — the API key used to obtain it cannot live on-device
- Rate limiting is easier to enforce server-side (one point of control)
- Response normalization happens once in TypeScript, not duplicated per-platform later (Android, web)

**Why not a full backend server?**

- Supabase Edge Functions are free-tier compatible, deploy instantly, scale automatically
- No server to maintain — it's just a function
- Latency is acceptable (Edge Functions run on Deno Deploy, globally distributed)

### Media Search Flow

```
┌──────────┐    POST /search-media     ┌────────────────────┐
│  iOS App  │ ─────────────────────── → │  Edge Function     │
│ (SearchVM)│   { query, type, page }   │  search-media/     │
└──────────┘                            └────────┬───────────┘
                                                 │ routes by media_type
                    ┌────────────────────────────┼──────────────────┐
                    ▼                            ▼                  ▼
            ┌──────────────┐          ┌──────────────┐    ┌──────────────┐
            │   TheTVDB    │          │    Kitsu     │    │ Open Library │
            │ movies / tv  │          │ anime / manga│    │    books     │
            └──────┬───────┘          └──────┬───────┘    └──────┬───────┘
                   │                         │                   │
                   └─────────────────────────┼───────────────────┘
                                             ▼
                                   ┌──────────────────┐
                                   │ Normalize to      │
                                   │ SearchResult[]    │
                                   └────────┬─────────┘
                                            ▼
                                   ┌──────────────────┐
                                   │  Return to iOS    │
                                   │  { results, page, │
                                   │    total_pages }  │
                                   └──────────────────┘

For books (Open Library): No auth needed, could call directly from iOS.
But we route through Edge Functions anyway for consistency and to keep
the normalization layer in one place.
```

### Media Detail Flow

```
┌──────────┐    POST /media-detail         ┌────────────────────┐
│  iOS App  │ ───────────────────────── → │  Edge Function      │
│(DetailVM) │  { source, source_id, type } │  media-detail/      │
└──────────┘                               └────────┬────────────┘
                                                    │
                                        ┌───────────┼───────────┐
                                        ▼           ▼           ▼
                                    fetch from   fetch from  fetch from
                                    provider     provider    provider
                                        │           │           │
                                        └───────────┼───────────┘
                                                    ▼
                                        ┌───────────────────────┐
                                        │  Normalize to          │
                                        │  MediaDetail object    │
                                        │  + upsert media_items  │
                                        │    in Supabase DB      │
                                        └────────────┬──────────┘
                                                     ▼
                                              Return to iOS
```

**Critical detail**: The Edge Function upserts the media item into the `media_items` table as a side effect. This means by the time the iOS app receives the detail response, the media_item row already exists in Supabase — so tracking, reviewing, and adding to nooks can reference it immediately via foreign key.

### Normalized Response Shapes

**Search result item** (light — for list display):

```typescript
interface SearchResult {
  media_id: string; // provider's ID (e.g., "movie-550" for TheTVDB)
  source: string; // "thetvdb" | "kitsu" | "openlibrary"
  media_type: string; // "movie" | "tv" | "anime" | "manga" | "book"
  title: string;
  image_url: string | null;
  year: string | null; // extracted from release_date/start_date
  score: number | null; // normalized to 0-10 scale
}
```

**Media detail** (full — for detail view):

```typescript
interface MediaDetail {
  // Identity
  media_id: string;
  source: string;
  media_type: string;
  source_url: string; // link to TheTVDB/Kitsu/Open Library page

  // Display
  title: string;
  image_url: string | null;
  synopsis: string; // plain text, HTML already stripped
  genres: string[];

  // Scores (all normalized to 0-10)
  score: number | null;
  score_count: number | null;

  // Progress tracking
  max_progress: number | null; // episodes, chapters, pages, or null (movies)

  // Type-specific metadata
  details: {
    format: string; // "Movie", "TV", "OVA", "Manga", "Hardcover", etc.
    status: string; // "Released", "Airing", "Publishing", "Upcoming", etc.
    release_date: string | null; // YYYY-MM-DD
    end_date: string | null;

    // Movies/TV/Anime
    runtime: string | null; // "1h 45m" or "24 min per ep"
    studios: string[] | null;
    director: string | null; // movies only

    // Anime
    season: string | null; // "Winter 2024"
    broadcast: string | null; // "Friday 20:00"
    source_material: string | null; // "Manga", "Light Novel", etc.

    // Books
    authors: string[] | null;
    pages: number | null;
    publisher: string | null;
    isbn: string | null;
  };

  // Related content
  related: {
    recommendations: SearchResult[];
    // + type-specific: seasons (TV), other_editions (books)
  } | null;
}
```

### Score Normalization Rules

Every API uses a different rating scale. We normalize everything to 0-10:

| Provider     | Raw Scale            | Conversion                     | Example    |
| ------------ | -------------------- | ------------------------------ | ---------- |
| TheTVDB      | N/A (no user rating) | `null`                         | —          |
| Kitsu        | 0-100 (float)        | `round(averageRating / 10, 1)` | 82.5 → 8.3 |
| Open Library | 0-5 (float)          | `round(average * 2, 1)`        | 3.8 → 7.6  |

### Image URL Construction Rules

Each provider has a different image URL scheme. The Edge Function constructs the full URL so the iOS app just gets a ready-to-use HTTPS URL:

| Provider     | Pattern                                                | Size Used |
| ------------ | ------------------------------------------------------ | --------- |
| TheTVDB      | Direct URL from `image_url` field                      | Full size |
| Kitsu        | Direct URL from `posterImage.large`                    | Large     |
| Open Library | `https://covers.openlibrary.org/b/id/{cover_id}-L.jpg` | Large     |

### Rate Limit Strategy

Rate limits are enforced in the Edge Function, not the iOS app:

| Provider     | Limit               | Strategy                                                 |
| ------------ | ------------------- | -------------------------------------------------------- |
| TheTVDB      | Generous            | No concern — generous limit. No throttling needed.       |
| Kitsu        | No documented limit | No throttling needed. Be respectful with request volume. |
| Open Library | ~3 req/sec          | In-memory counter. Must send `User-Agent` header.        |

iOS-side: If Edge Function returns 429, show "Too many searches, try again in a moment" — not a retry loop.

### Pagination

| Provider     | Style        | Page Size | How It Works                                           |
| ------------ | ------------ | --------- | ------------------------------------------------------ |
| TheTVDB      | Offset-based | 24        | `?offset=N&limit=24` — offset/limit params             |
| Kitsu        | Offset-based | 20 (max)  | `?page[offset]=N&page[limit]=20` — JSON:API pagination |
| Open Library | Page-based   | 24        | `?page=N&limit=24` — returns `numFound`                |

The Edge Function normalizes all of these to a consistent response:

```typescript
interface SearchResponse {
  results: SearchResult[];
  page: number; // current page (1-indexed)
  total_pages: number; // total available pages
  per_page: number; // items per page (20 for Kitsu, 24 for others)
}
```

iOS calls `searchMedia(query, type, page: 1)`, then `page: 2` on scroll, etc.

---

## 4. Data Storage Strategy

### What Lives Where

There are three storage layers. Every piece of data lives in exactly one authoritative location:

```
┌───────────────────────────────────────────────────────────────┐
│                    SUPABASE POSTGRES                          │
│  (Source of truth for ALL user data)                          │
│                                                               │
│  user_profiles     — profile info, interests, avatar_url      │
│  user_follows      — social graph                             │
│  tracked_media     — what users are tracking + status/progress│
│  reviews           — user reviews + ratings                   │
│  review_likes      — who liked what review                    │
│  review_comments   — threaded comments on reviews             │
│  clubs             — community metadata                       │
│  club_members      — membership + roles                       │
│  club_posts        — posts in clubs                           │
│  club_post_likes   — post likes                               │
│  club_post_comments— comments on posts                        │
│  nooks             — collection metadata                      │
│  nook_items        — media in collections + notes             │
│  notifications     — notification queue                       │
│  activity_feed     — denormalized feed entries                │
│  media_items       — cached catalog (see below)               │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│              SUPABASE STORAGE (S3-compatible)                  │
│  (Source of truth for user-uploaded binary assets)             │
│                                                               │
│  avatars/          — profile photos                           │
│  nook-covers/      — nook cover images                        │
│  club-assets/      — club banners and icons                   │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│                   EXTERNAL APIs                               │
│  (Source of truth for media metadata)                         │
│                                                               │
│  TheTVDB           — movie/TV metadata, posters, cast         │
│  Kitsu             — anime/manga metadata, images             │
│  Open Library      — book metadata, covers                    │
└───────────────────────────────────────────────────────────────┘
```

### The `media_items` Table — Design Rationale

This table is a **local catalog cache**, not a source of truth. Here's why it exists and how it works:

**Problem**: User tracks an anime. Later, they view their library. We need to show the anime's title, image, and genre. Do we call the Kitsu API every time they open their library? No — that's slow, wastes API quota, and fails offline.

**Solution**: When a user interacts with a media item (views details, tracks it, reviews it), we upsert a row into `media_items` with the essential display data. All user tables (`tracked_media`, `reviews`, `nook_items`) reference `media_items` via foreign key.

**What's stored** (stable reference data):

```
media_items
├── source + source_id  (unique identifier for the external item)
├── title, image_url    (for display in lists without re-fetching)
├── media_type, year, genres  (for filtering/sorting)
├── score, score_count  (snapshot — acceptable to be slightly stale)
├── synopsis            (for preview — rarely changes)
├── details (JSONB)     (format-specific extras — episodes, pages, studios)
```

**What's NOT stored** (fetch fresh from API):

- Cast/crew lists
- Related/recommended items
- Watch providers
- Full season/episode breakdowns
- External links

**Staleness policy**: Media metadata is upserted on every detail view. If a user viewed it 3 months ago and opens it again, the Edge Function re-fetches from the API and updates the row. The `media_items` data is "fresh enough" for list display but the detail view always fetches the latest.

### Write Patterns

All writes go through the service layer → Supabase SDK. No direct writes from views.

**Optimistic updates**: For high-frequency interactions (like/unlike, track status change), we update local state immediately and fire the Supabase mutation in the background. If it fails, we roll back the local state and show an error toast.

```
User taps "Like" → local state flips to liked → UI updates → Supabase insert runs async
                                                              ├── Success: done
                                                              └── Failure: local state rolls back + error toast
```

**Pessimistic updates**: For important mutations (create review, create nook, delete account), we show a loading state, wait for Supabase confirmation, then update the UI.

---

## 5. Caching Architecture

### Three Cache Layers

```
┌─────────────────────────────────────────────────┐
│  Layer 1: IN-MEMORY (Swift Dictionary)           │
│  Lifetime: current app session                   │
│  Eviction: on memory warning + app background    │
│  Contents:                                       │
│    - Search results (keyed by query+type+page)   │
│    - Media details (keyed by source+sourceId)    │
│    - Profile data for users seen this session    │
│    - Library items (full loaded set)             │
│  Purpose: instant tab switching, back navigation │
└─────────────────────┬───────────────────────────┘
                      │ miss
┌─────────────────────▼───────────────────────────┐
│  Layer 2: URL CACHE (URLCache — disk-backed)     │
│  Lifetime: configurable TTL per response type    │
│  Size: 100MB disk, 50MB memory                   │
│  Contents:                                       │
│    - Edge Function responses (search + detail)   │
│    - Image data (posters, avatars, covers)       │
│  Purpose: survive app restart, reduce API calls  │
│  Strategy: HTTP cache headers from Edge Functions│
└─────────────────────┬───────────────────────────┘
                      │ miss
┌─────────────────────▼───────────────────────────┐
│  Layer 3: NETWORK (Supabase + Edge Functions)    │
│  Always authoritative for user data              │
│  Edge Functions set Cache-Control headers:       │
│    - Search: max-age=300 (5 min)                 │
│    - Detail: max-age=3600 (1 hour)               │
│    - User data: no-cache (always fresh)          │
└─────────────────────────────────────────────────┘
```

### Cache Key Design

```swift
// In-memory cache keys (service-internal, never exposed to views)
"search:{type}:{query}:{page}"       // e.g., "search:anime:naruto:1"
"detail:{source}:{sourceId}"         // e.g., "detail:thetvdb:550"
"library:{userId}"                   // full library for a user
"profile:{userId}"                   // profile data
"stats:{userId}"                     // profile stats
"club:{clubId}:posts:{page}"         // club post page
"feed:{userId}:{page}"              // activity feed page
```

### Cache Invalidation Rules

| Cache Entry    | Invalidated When                                     |
| -------------- | ---------------------------------------------------- |
| Search results | After 5 minutes (TTL) or new search with same params |
| Media detail   | After 1 hour (TTL) or user opens detail view again   |
| Library items  | After any tracking mutation (add/update/delete)      |
| Profile data   | After profile edit, follow/unfollow                  |
| Profile stats  | After any tracking/review/nook/club mutation         |
| Club posts     | After new post or like mutation                      |
| Activity feed  | Pull-to-refresh or after 5 minutes                   |
| Notifications  | After marking as read, pull-to-refresh               |

### Implementation: CacheManager

```swift
// Not a generic catch-all — each service manages its own in-memory cache.
// But they share a common pattern:

actor InMemoryCache<Key: Hashable, Value> {
    private var storage: [Key: CacheEntry<Value>] = [:]
    private let ttl: TimeInterval

    func get(_ key: Key) -> Value? {
        guard let entry = storage[key],
              Date().timeIntervalSince(entry.timestamp) < ttl else {
            storage[key] = nil
            return nil
        }
        return entry.value
    }

    func set(_ key: Key, value: Value) {
        storage[key] = CacheEntry(value: value, timestamp: Date())
    }

    func invalidate(_ key: Key) { storage[key] = nil }
    func invalidateAll() { storage.removeAll() }
}
```

Using `actor` ensures thread safety without locks. Each service has its own cache instance with an appropriate TTL.

### URLCache Configuration

```swift
// Configured once at app startup in NookApp.swift
let cache = URLCache(
    memoryCapacity: 50 * 1024 * 1024,   // 50 MB memory
    diskCapacity: 100 * 1024 * 1024,     // 100 MB disk
    diskPath: "nook_url_cache"
)
URLCache.shared = cache
```

Edge Functions set `Cache-Control` headers so URLSession respects them automatically:

```typescript
// In Edge Function response:
return new Response(JSON.stringify(data), {
  headers: {
    'Content-Type': 'application/json',
    'Cache-Control': 'public, max-age=300', // search: 5 min
    // or "public, max-age=3600" for detail: 1 hour
  },
});
```

This means `URLSession` (which the Supabase SDK and our APIClient use) will automatically serve cached responses for repeat requests within the TTL window — no custom logic needed for HTTP-level caching.

---

## 6. Image Loading Pipeline

### Problem

The app will display hundreds of media posters (search results, library, feeds, nooks). `AsyncImage` is SwiftUI's built-in solution but it has limitations:

- No disk caching across launches (only in-memory within a view lifecycle)
- No prefetching
- No placeholder → loading → loaded transition control beyond basic
- No progressive loading or downsampling

### Decision: Use AsyncImage + URLCache (No Third-Party Library)

**Rationale**: Adding Kingfisher or Nuke means a new dependency to maintain. With our URLCache configured at 100MB disk, `AsyncImage` will actually cache effectively because it uses `URLSession.shared` under the hood, which respects `URLCache.shared`. The Edge Functions return image URLs with long-lived Cache-Control headers from the provider CDNs.

**If performance proves insufficient after Phase 1**, we add Nuke (lighter than Kingfisher, better SwiftUI integration). But we start without it.

### Image Component Pattern

```swift
// Reusable component used everywhere media images appear
struct MediaPosterImage: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = NookRadii.xs

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                fallbackPlaceholder
            case .empty:
                shimmerPlaceholder  // Animated loading skeleton
            @unknown default:
                fallbackPlaceholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
```

### Dominant Color Extraction

The current `MediaDetailView` extracts a dominant color from the poster for the header gradient. With remote images, this needs to change:

```
Current:  UIImage(named: assetName) → downsample → average RGB → Color
Target:   AsyncImage loads → onSuccess, get UIImage → downsample → average RGB → Color
```

We'll keep the existing algorithm (downsample to 4×4, average top 25%) but trigger it from the image load completion rather than from an asset name.

---

## 7. State Management & Data Flow

### When to Use What

| Pattern                 | When                                                             | Example                                                 |
| ----------------------- | ---------------------------------------------------------------- | ------------------------------------------------------- |
| `@State`                | Simple local state, no async loading                             | Sheet isPresented, selected tab, text field value       |
| `@State` + `.task`      | One-shot async load on appear                                    | Profile view loading user data                          |
| `@Observable` ViewModel | Complex screen with multiple data sources, pagination, mutations | SearchViewModel, LibraryViewModel, MediaDetailViewModel |
| `@Environment` service  | Shared domain logic injected from above                          | MediaAPIService, TrackingService                        |
| `@Binding`              | Parent passes mutable state to child                             | Tracking sheet getting/setting status                   |

### Screens That Get ViewModels vs Screens That Stay @State

**Get ViewModels** (complex async, multiple data sources, pagination):

- `SearchView` → `SearchViewModel` (search API, debounce, pagination, filter state)
- `LibraryView` → `LibraryViewModel` (Supabase query, filter, sort, pagination)
- `MediaDetailView` → `MediaDetailViewModel` (API detail fetch, tracking state, reviews)
- `HomeView` → `HomeViewModel` (multiple feed queries in parallel)
- `ClubDetailView` → `ClubDetailViewModel` (club data, posts, members, pagination)
- `CommunitiesView` → `CommunitiesViewModel` (my clubs + discover, category filter)

**Stay @State** (simple data, single source, no pagination):

- `SettingsView` — reads config, triggers simple actions
- `EditProfileSheet` — form state → single Supabase write
- `CreateNookSheet` — form state → single Supabase write
- `CreateClubSheet` — form state → single Supabase write
- `ComposePostView` — text state → single Supabase write
- `OnboardingInterestsView` — selection → single Supabase write
- `StatsView` — single Supabase query on appear
- `NotificationsView` — single Supabase query (could upgrade to VM if pagination needed)

### ViewModel Pattern

```swift
@Observable
final class SearchViewModel {
    // Published state (views observe these)
    var results: [MediaSearchResult] = []
    var searchState: SearchState = .idle
    var selectedFilter: SearchMediaCategory?
    var searchText: String = ""
    var currentPage: Int = 1
    var hasMorePages: Bool = false
    var error: AppError?

    // Dependencies (injected)
    private let mediaAPI: MediaAPIService

    // Internal
    private var searchTask: Task<Void, Never>?

    init(mediaAPI: MediaAPIService) {
        self.mediaAPI = mediaAPI
    }

    func search() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchState = .idle
            results = []
            return
        }

        searchState = .loading
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            do {
                let response = try await mediaAPI.search(
                    query: query,
                    mediaType: selectedFilter?.apiValue,
                    page: 1
                )
                guard !Task.isCancelled else { return }
                results = response.results
                currentPage = 1
                hasMorePages = response.page < response.totalPages
                searchState = results.isEmpty ? .noResults : .results
                error = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.error = AppError(from: error)
                searchState = .noResults
            }
        }
    }

    func loadNextPage() {
        guard hasMorePages, searchTask == nil || searchTask!.isCancelled else { return }
        let nextPage = currentPage + 1
        searchTask = Task {
            do {
                let response = try await mediaAPI.search(
                    query: searchText,
                    mediaType: selectedFilter?.apiValue,
                    page: nextPage
                )
                guard !Task.isCancelled else { return }
                results.append(contentsOf: response.results)
                currentPage = nextPage
                hasMorePages = response.page < response.totalPages
            } catch {
                self.error = AppError(from: error)
            }
        }
    }
}
```

### View ↔ ViewModel Binding

```swift
struct SearchView: View {
    @State private var viewModel: SearchViewModel

    init(mediaAPI: MediaAPIService) {
        _viewModel = State(initialValue: SearchViewModel(mediaAPI: mediaAPI))
    }

    var body: some View {
        // ...
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.search()
        }
        .onChange(of: viewModel.selectedFilter) { _, _ in
            viewModel.search()
        }
    }
}
```

### Data Flow for a Tracking Mutation

```
User taps "Track" on MediaDetailView
    │
    ▼
MediaDetailViewModel.trackMedia(status: .inProgress)
    │
    ├── 1. Optimistic: self.trackingStatus = .inProgress (UI updates instantly)
    │
    ├── 2. TrackingService.track(mediaItem, status, progress, score)
    │       │
    │       ├── a. Upsert media_items if not exists (Edge Function already did this on detail load)
    │       ├── b. Upsert tracked_media row
    │       ├── c. Insert activity_feed entry
    │       └── d. Invalidate library cache
    │
    ├── 3. On success: done (UI already reflects change)
    │
    └── 4. On failure: self.trackingStatus = previousStatus (rollback) + show error toast
```

---

## 8. Service Layer Design

### Dependency Injection via Environment

```swift
// Define environment key
struct MediaAPIServiceKey: EnvironmentKey {
    static let defaultValue: MediaAPIService = MediaAPIService()
}

extension EnvironmentValues {
    var mediaAPI: MediaAPIService {
        get { self[MediaAPIServiceKey.self] }
        set { self[MediaAPIServiceKey.self] = newValue }
    }
}

// Inject at app root
@main
struct NookApp: App {
    @State private var mediaAPI = MediaAPIService()
    @State private var trackingService = TrackingService()
    // ...

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.mediaAPI, mediaAPI)
                .environment(\.trackingService, trackingService)
        }
    }
}

// Consume in view
struct SearchView: View {
    @Environment(\.mediaAPI) private var mediaAPI
    // ...
}
```

### Service Inventory

| Service               | Responsibility                     | Talks To               | Cache TTL                 |
| --------------------- | ---------------------------------- | ---------------------- | ------------------------- |
| `MediaAPIService`     | Search + detail via Edge Functions | Edge Functions         | 5 min search, 1 hr detail |
| `TrackingService`     | CRUD on tracked_media              | Supabase DB            | Invalidate on mutation    |
| `ReviewService`       | CRUD on reviews, likes, comments   | Supabase DB            | Invalidate on mutation    |
| `ClubService`         | CRUD on clubs, posts, members      | Supabase DB            | Invalidate on mutation    |
| `NookService`         | CRUD on nooks + items              | Supabase DB            | Invalidate on mutation    |
| `ProfileService`      | Profiles, follows, stats           | Supabase DB            | 5 min                     |
| `NotificationService` | Fetch + mark read                  | Supabase DB + Realtime | No cache (always fresh)   |
| `StorageService`      | Upload/download images             | Supabase Storage       | URLCache handles it       |
| `ActivityFeedService` | Home feed queries                  | Supabase DB            | 5 min                     |

### Service ↔ Supabase Query Pattern

```swift
@Observable
final class TrackingService {
    private let cache = InMemoryCache<String, [TrackedMediaItem]>(ttl: 0) // manual invalidation

    func getLibrary(userId: UUID, filter: TrackingStatus?, sort: LibrarySortOption) async throws -> [TrackedMediaItem] {
        // Check cache
        let cacheKey = "library:\(userId)"
        if filter == nil, sort == .lastUpdated, let cached = await cache.get(cacheKey) {
            return cached
        }

        // Build query
        var query = supabase
            .from("tracked_media")
            .select("*, media_item:media_items(*)")
            .eq("user_id", value: userId.uuidString)

        if let filter {
            query = query.eq("status", value: filter.rawValue)
        }

        switch sort {
        case .alphabetical:
            query = query.order("media_item(title)", ascending: true)
        case .score:
            query = query.order("score", ascending: false)
        case .lastUpdated:
            query = query.order("updated_at", ascending: false)
        // ... etc
        }

        let items: [TrackedMediaRow] = try await query.execute().value
        let mapped = items.map { TrackedMediaItem(from: $0) }

        // Cache unfiltered full library
        if filter == nil, sort == .lastUpdated {
            await cache.set(cacheKey, value: mapped)
        }

        return mapped
    }

    func track(mediaItemId: UUID, status: TrackingStatus, progress: Int, score: Double?) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("tracked_media")
            .upsert(TrackedMediaUpsert(
                user_id: userId,
                media_item_id: mediaItemId,
                status: status.rawValue,
                progress: progress,
                score: score
            ))
            .execute()

        // Invalidate cache
        await cache.invalidate("library:\(userId)")

        // Insert activity feed entry
        try? await supabase
            .from("activity_feed")
            .insert(ActivityFeedInsert(
                user_id: userId,
                action_type: "tracked",
                media_item_id: mediaItemId
            ))
            .execute()
    }
}
```

---

## 9. Edge Function Design

### Shared Utilities

```typescript
// supabase/functions/_shared/providers.ts

// Provider routing
export function getProvider(mediaType: string) {
  switch (mediaType) {
    case 'movie':
    case 'tv':
      return thetvdbProvider;
    case 'anime':
    case 'manga':
      return kitsuProvider;
    case 'book':
      return openLibraryProvider;
    default:
      throw new Error(`Unknown media type: ${mediaType}`);
  }
}

// Standardized error response
export function errorResponse(status: number, message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
```

### TheTVDB Token Management

TheTVDB requires a Bearer token obtained by POSTing the API key to `/login`. The token is valid for ~1 month:

```typescript
// supabase/functions/_shared/thetvdb-auth.ts

let cachedToken: { token: string; expiresAt: number } | null = null;

export async function getTheTVDBToken(): Promise<string> {
  // Check if cached token is still valid (with 1-day buffer)
  if (cachedToken && Date.now() < cachedToken.expiresAt - 86400000) {
    return cachedToken.token;
  }

  // Fetch new token from TheTVDB
  const response = await fetch('https://api4.thetvdb.com/v4/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      apikey: Deno.env.get('THETVDB_API_KEY')!,
    }),
  });

  const data = await response.json();
  cachedToken = {
    token: data.data.token,
    // TheTVDB tokens last ~1 month; refresh after 25 days
    expiresAt: Date.now() + 25 * 24 * 60 * 60 * 1000,
  };

  return cachedToken.token;
}
```

**Note**: Edge Functions are stateless — `cachedToken` is in-memory per cold start. In practice, Deno Deploy keeps instances warm for minutes, so the token usually survives multiple requests. If the instance cold-starts, it just fetches a new token (takes ~200ms, happens rarely). Kitsu and Open Library require no auth tokens.

### search-media Edge Function

```typescript
// supabase/functions/search-media/index.ts

import { getProvider, errorResponse } from '../_shared/providers.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed');
  }

  const { query, media_type, page = 1 } = await req.json();

  if (!query || !media_type) {
    return errorResponse(400, 'query and media_type are required');
  }

  try {
    const provider = getProvider(media_type);
    const results = await provider.search(query, media_type, page);

    return new Response(JSON.stringify(results), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300', // 5 min
      },
    });
  } catch (error) {
    console.error(`Search error [${media_type}]:`, error);
    return errorResponse(502, 'Failed to search media provider');
  }
});
```

### media-detail Edge Function

```typescript
// supabase/functions/media-detail/index.ts

Deno.serve(async (req) => {
  const { source, source_id, media_type } = await req.json();

  try {
    const provider = getProvider(media_type);
    const detail = await provider.detail(source_id, media_type);

    // Side effect: upsert into media_items table
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, // service role for server-side writes
    );

    await supabase.from('media_items').upsert(
      {
        source: detail.source,
        source_id: detail.media_id,
        media_type: detail.media_type,
        title: detail.title,
        image_url: detail.image_url,
        year: detail.details?.release_date?.substring(0, 4) ?? null,
        genres: detail.genres,
        score: detail.score,
        score_count: detail.score_count,
        synopsis: detail.synopsis,
        details: detail.details,
      },
      { onConflict: 'source,source_id' },
    );

    // Return the media_items row ID so iOS can reference it for tracking
    const { data: mediaItem } = await supabase
      .from('media_items')
      .select('id')
      .eq('source', detail.source)
      .eq('source_id', detail.media_id)
      .single();

    return new Response(
      JSON.stringify({
        ...detail,
        db_id: mediaItem?.id, // UUID for foreign key references
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=3600', // 1 hour
        },
      },
    );
  } catch (error) {
    console.error(`Detail error [${source}/${source_id}]:`, error);
    return errorResponse(502, 'Failed to fetch media details');
  }
});
```

### iOS APIClient

```swift
final class APIClient {
    private let baseURL: URL
    private let session: URLSession

    init() {
        self.baseURL = URL(string: "\(supabase.supabaseURL)/functions/v1")!

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable>(_ endpoint: String, body: Encodable) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth: pass the user's JWT so Edge Functions can identify the caller
        if let token = try? await supabase.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)
        case 429:
            throw AppError.rateLimited
        case 400...499:
            let errorBody = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw AppError.clientError(errorBody?.error ?? "Bad request")
        default:
            throw AppError.serverError(httpResponse.statusCode)
        }
    }
}
```

---

## 10. Realtime & Notifications

### Push-Like Experience Without Push Notifications (Phase 7)

For the MVP, we don't need APNs setup. Instead, we use **Supabase Realtime** to stream notifications while the app is open:

```swift
// In NotificationService
func startListening() {
    let channel = supabase.realtime.channel("notifications:\(userId)")

    channel.onPostgresChange(
        InsertAction.self,
        schema: "public",
        table: "notifications",
        filter: "user_id=eq.\(userId)"
    ) { [weak self] insert in
        Task { @MainActor in
            self?.unreadCount += 1
            self?.notifications.insert(insert.record, at: 0)
        }
    }

    Task { await channel.subscribe() }
}
```

**When to subscribe:**

- On app launch (after auth confirmed)
- Unsubscribe on sign out

**What triggers notifications (server-side — via Postgres triggers or Edge Functions):**

- Someone follows you → insert notification
- Someone likes your review → insert notification
- Someone comments on your review → insert notification
- Someone likes/comments on your club post → insert notification
- Club invite → insert notification

### Activity Feed Architecture

The `activity_feed` table is **denormalized by design**. When a user tracks media, writes a review, creates a nook, or joins a club, we insert a row into `activity_feed`. The home feed queries this table for followed users.

**Why denormalized instead of joining across tables?**

- A "feed" query joining `tracked_media UNION reviews UNION nooks UNION club_members` with ordering and pagination is expensive and hard to index
- A single denormalized table with `(user_id, action_type, created_at)` is trivially indexable and paginates cleanly
- The cost is slightly more storage and an extra insert on each action — acceptable trade-off

**Feed query:**

```sql
SELECT af.*,
       up.full_name, up.username, up.avatar_url,
       mi.title as media_title, mi.image_url as media_image, mi.media_type
FROM activity_feed af
JOIN user_profiles up ON af.user_id = up.id
LEFT JOIN media_items mi ON af.media_item_id = mi.id
WHERE af.user_id IN (
    SELECT following_id FROM user_follows WHERE follower_id = $current_user
)
ORDER BY af.created_at DESC
LIMIT 20 OFFSET $offset
```

---

## 11. Error Handling Strategy

### Typed Error Enum

```swift
enum AppError: LocalizedError {
    case networkError
    case rateLimited
    case unauthorized
    case notFound
    case clientError(String)
    case serverError(Int)
    case supabaseError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkError: return "No internet connection"
        case .rateLimited: return "Too many requests. Try again in a moment."
        case .unauthorized: return "Session expired. Please sign in again."
        case .notFound: return "Content not found"
        case .clientError(let msg): return msg
        case .serverError(let code): return "Server error (\(code))"
        case .supabaseError(let msg): return msg
        case .unknown: return "Something went wrong"
        }
    }
}
```

### Error Surfacing Rules

| Error Type              | User-Facing Behavior                                              |
| ----------------------- | ----------------------------------------------------------------- |
| Network error (offline) | Banner at top of screen: "No connection — showing cached data"    |
| Rate limited (429)      | Toast: "Too many requests. Try again in a moment."                |
| Auth expired (401)      | Redirect to IntroView, show "Session expired"                     |
| Not found (404)         | Empty state in detail view: "This content is no longer available" |
| Server error (5xx)      | Toast: "Something went wrong. Try again." + retry button          |
| Supabase write failure  | Rollback optimistic update + toast with specific message          |

### No Silent Failures

The current codebase uses `try?` everywhere. We replace every `try?` with proper do/catch blocks that either handle the error (show UI feedback) or propagate it to the view model's `error` property.

```swift
// BEFORE (current)
guard let user = try? await supabase.auth.session.user else { return }

// AFTER
do {
    let user = try await supabase.auth.session.user
    // proceed
} catch {
    self.error = AppError(from: error)
}
```

---

## 12. Offline & Degradation

### Strategy: Online-First with Graceful Degradation

Nook is a social media tracking app — most actions require network. We don't build a full offline-first architecture (that's overkill for an MVP). Instead:

1. **Library** — cached in memory. If the app has loaded the library this session, tab-switching is instant. If the app cold-starts offline, show "Connect to load your library."

2. **Search** — requires network. If offline, show "Connect to the internet to search."

3. **Media Detail** — if cached in URLCache, show cached version. If not, show "Connect to load details."

4. **Home Feed** — if cached, show stale data with a "Pull to refresh" hint. If not cached, show "Connect to see your feed."

5. **Tracking mutation** — if offline, queue the mutation and apply it when connectivity returns. This is the one place where offline support matters (user finishes an episode and wants to log it).

### Offline Mutation Queue (Future Enhancement)

For the initial implementation, tracking mutations just fail with an error toast if offline. If user feedback indicates this is a friction point, we add a simple queue:

```swift
// Queued in UserDefaults as JSON
struct QueuedMutation: Codable {
    let id: UUID
    let type: String  // "track", "updateProgress", "rate"
    let payload: Data  // JSON-encoded mutation body
    let createdAt: Date
}
```

On app foreground or network change → drain the queue.

---

## 13. Security Architecture

### API Key Protection

- **TheTVDB API key** → stored as Supabase Edge Function environment variable. Never in the iOS binary. Kitsu and Open Library require no API keys.
- **Supabase anon key** → in the iOS binary (this is by design — it's a "publishable" key that only works with RLS).
- **Supabase service role key** → only in Edge Functions (server-side). Never on-device.

### Row Level Security (RLS)

Every table has RLS enabled. Key policies:

```sql
-- Users can only read their own tracked media
CREATE POLICY "Users read own tracked_media"
ON tracked_media FOR SELECT
USING (auth.uid() = user_id);

-- Users can read public reviews (or their own)
CREATE POLICY "Users read reviews"
ON reviews FOR SELECT
USING (true);  -- reviews are public

-- Users can only write their own reviews
CREATE POLICY "Users write own reviews"
ON reviews FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Club posts visible to members only (for non-public clubs)
CREATE POLICY "Club members read posts"
ON club_posts FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM clubs c
        WHERE c.id = club_posts.club_id
        AND (c.privacy = 'public' OR EXISTS (
            SELECT 1 FROM club_members cm
            WHERE cm.club_id = c.id AND cm.user_id = auth.uid()
        ))
    )
);

-- Nook visibility based on privacy + follow relationship
CREATE POLICY "Nook visibility"
ON nooks FOR SELECT
USING (
    privacy = 'public'
    OR user_id = auth.uid()
    OR (privacy = 'friends_only' AND EXISTS (
        SELECT 1 FROM user_follows
        WHERE follower_id = auth.uid() AND following_id = nooks.user_id
    ))
);
```

### Input Validation

- All user text input (review body, post content, nook descriptions) is stored as plain text. No HTML rendering on display.
- Username validation: alphanumeric + underscores, 3-20 chars, enforced at both DB (CHECK constraint) and iOS (regex validation before submit).
- Image uploads: validated MIME type server-side via Supabase Storage policies. Only `image/jpeg`, `image/png`, `image/webp` allowed. Max 5MB per file.

---

## 14. Performance Budget

### Target Metrics

| Metric                             | Target                                   | Measured How                 |
| ---------------------------------- | ---------------------------------------- | ---------------------------- |
| Cold launch → Home visible         | < 2s                                     | Xcode Instruments            |
| Search keystroke → results visible | < 800ms (400ms debounce + 400ms network) | Perceived latency            |
| Tab switch (cached)                | < 100ms                                  | Instant from in-memory cache |
| Library load (100 items)           | < 500ms                                  | Supabase query + decode      |
| Media detail load                  | < 1s                                     | Edge Function + image load   |
| Image poster load                  | < 500ms (with placeholder)               | Shimmer shown immediately    |
| Tracking mutation (optimistic)     | < 50ms perceived                         | UI updates before network    |
| Memory usage (typical session)     | < 150MB                                  | Xcode memory gauge           |

### What We Monitor

- **Network calls**: total count per session, average latency per endpoint
- **Cache hit rate**: in-memory hits vs network fetches (logged in debug builds)
- **Image loading**: track failed image loads (broken URLs, timeouts)
- **Error rate**: count of errors shown to users per session

### Pagination Limits

| List             | Page Size | Max In-Memory | Reasoning                                                              |
| ---------------- | --------- | ------------- | ---------------------------------------------------------------------- |
| Search results   | 24        | 120 (5 pages) | User rarely scrolls past 5 pages; new search resets                    |
| Library items    | 50        | All           | User owns this data, needs full filtering; typical library < 500 items |
| Club posts       | 20        | 100 (5 pages) | Chronological feed, older posts rarely accessed                        |
| Activity feed    | 20        | 60 (3 pages)  | Recent activity most relevant                                          |
| Reviews on media | 10        | 30 (3 pages)  | Most users read 5-10 reviews                                           |
| Notifications    | 20        | 60 (3 pages)  | Recent notifications most relevant                                     |

---

## Appendix: Model Naming Conventions

To avoid confusion between API response models and database models:

| Layer                               | Prefix/Suffix | Example                                           |
| ----------------------------------- | ------------- | ------------------------------------------------- |
| API response (from Edge Function)   | `API` prefix  | `APISearchResult`, `APIMediaDetail`               |
| Database row (from Supabase)        | `Row` suffix  | `TrackedMediaRow`, `ReviewRow`                    |
| View-facing model (what VMs expose) | Plain name    | `MediaSearchResult`, `TrackedMediaItem`, `Review` |

The view-facing model is what the VM creates by combining API and DB data. Views never see `Row` or `API` types directly.
