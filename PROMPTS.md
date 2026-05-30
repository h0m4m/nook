# Nook Build Prompts

> Sequential prompts for another Claude agent to build Nook phase by phase.
> Each prompt is self-contained. Give the next one only after testing the deliverable from the previous one.

---

## How to Use

1. Start a fresh Claude Code session
2. Copy-paste Prompt 1
3. Wait for it to finish and say "done"
4. **You test** the deliverable (described under "What to test")
5. If it works, start a new session and give Prompt 2
6. Repeat

Each prompt builds on the previous one. Don't skip prompts. Don't give two at once.

---

## Prompt 1 — Database Schema & Storage Buckets

**What it builds**: All Supabase tables, RLS policies, triggers, database functions, and storage buckets.

**What to test**: Open Supabase Studio (local or remote). Check that all tables exist with correct columns. Try inserting a row into `tracked_media` without being authenticated — it should be denied by RLS. Check that the three storage buckets exist.

```
You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files first to understand the full context:
- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 0.1 — the full table schemas)
- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Section 4 — Data Storage Strategy, Section 13 — Security Architecture for RLS policies)
- /Users/humammourad/Projects/nook/supabase/migrations/20260524000000_create_user_profiles.sql (existing migration — don't recreate this table, ALTER it)
- /Users/humammourad/Projects/nook/supabase/config.toml (project config)

Your task: Create the full Supabase database schema as a NEW migration file (don't modify the existing one).

Create a single migration file at:
supabase/migrations/20260529000000_full_schema.sql

This migration must:

1. ALTER the existing `user_profiles` table to ADD these columns (they don't exist yet):
   - full_name (text, nullable)
   - username (text, nullable, UNIQUE)
   - bio (text, nullable)
   - avatar_url (text, nullable)
   Do NOT recreate the table. It already has: id, interests, onboarding_completed, created_at, updated_at.

2. CREATE all these tables (exact schemas are in IMPLEMENTATION_PLAN.md Phase 0.1):
   - user_follows
   - media_items (with UNIQUE on (source, source_id))
   - tracked_media (with UNIQUE on (user_id, media_item_id))
   - reviews (with INDEX on (media_item_id, created_at))
   - review_likes (composite PK)
   - review_comments (self-referencing parent_comment_id)
   - clubs
   - club_members (composite PK)
   - club_posts
   - club_post_likes (composite PK)
   - club_post_comments (self-referencing parent_comment_id)
   - nooks
   - nook_items
   - notifications
   - activity_feed

3. Enable RLS on EVERY table and create policies:
   - user_profiles: users read/update own profile. All authenticated users can read any profile (for viewing other users).
   - user_follows: users can read all follows (public social graph). Users insert/delete own follows only.
   - media_items: all authenticated users can read. Service role can insert/update (Edge Functions do the upserting). Also allow authenticated users to insert (so iOS can upsert on track).
   - tracked_media: users read/insert/update/delete own only.
   - reviews: all authenticated users can read (reviews are public). Users insert/update/delete own only.
   - review_likes: all authenticated can read. Users insert/delete own only.
   - review_comments: all authenticated can read. Users insert/update/delete own only.
   - clubs: all authenticated can read public clubs. Members can read friends_only/members_only clubs.
   - club_members: readable by anyone in the same club. Users can insert (join) and delete (leave) themselves.
   - club_posts: readable by club members (or anyone if club is public). Users insert/update/delete own posts.
   - club_post_likes: readable by club members. Users insert/delete own.
   - club_post_comments: readable by club members. Users insert/update/delete own.
   - nooks: public nooks readable by all. friends_only readable by followers. private readable by owner only.
   - nook_items: same visibility as parent nook.
   - notifications: users read/update own only.
   - activity_feed: readable by all authenticated (it's a public feed). Users insert own.

4. Create these triggers and functions:
   - `handle_updated_at()` already exists from the first migration. Reuse it — add triggers for ALL new tables that have updated_at.
   - `increment_member_count()` trigger on club_members INSERT → increment clubs.member_count
   - `decrement_member_count()` trigger on club_members DELETE → decrement clubs.member_count
   - `increment_review_likes()` trigger on review_likes INSERT → increment reviews.likes_count
   - `decrement_review_likes()` trigger on review_likes DELETE → decrement reviews.likes_count
   - `increment_post_likes()` trigger on club_post_likes INSERT → increment club_posts.likes_count
   - `decrement_post_likes()` trigger on club_post_likes DELETE → decrement club_posts.likes_count
   - `get_user_stats(target_user_id uuid)` — returns JSON with tracked_count, review_count, nook_count, club_count

5. Create storage buckets by inserting into storage.buckets:
   - `avatars` (public = true)
   - `nook-covers` (public = true)
   - `club-assets` (public = true)
   And create storage policies:
   - avatars: anyone can read. Authenticated users can upload to their own path (`{user_id}/*`). Users can update/delete own files.
   - nook-covers: same pattern.
   - club-assets: same pattern.

6. Add a CHECK constraint on user_profiles.username: `username ~ '^[a-zA-Z0-9_]{3,20}$'` (alphanumeric + underscore, 3-20 chars).

Use `gen_random_uuid()` for default UUIDs. Use `now()` for default timestamps. Use `auth.uid()` in RLS policies.

Do NOT use the Supabase MCP tools to apply this. Just write the SQL migration file. I will apply it myself.

When done, say: "Migration file created. Run `supabase db push` or `supabase db reset` to apply."
```

---

## Prompt 2 — Edge Functions (Search + Detail API Proxy)

**COMPLETED — Edge Functions deployed.**

Providers used:

- **TheTVDB** for movies + TV (env var: `THETVDB_API_KEY`)
- **Kitsu** for anime + manga (no auth needed)
- **Open Library** for books (no auth needed)
- Games (IGDB) are skipped for now — will be added later.

The 5 supported media types are: movie, tv, anime, manga, book.

---

## Prompt 3 — iOS Models & Service Layer Foundation

**What it builds**: All Swift data models, the APIClient, error types, and service stubs. The app should still compile and run identically to before (no view changes yet).

**What to test**: Build the project in Xcode (`Cmd+B`). It should compile with zero errors. Run the app — it should work exactly as before (all mock data still shows). The new files should exist but nothing references them from views yet.

````
You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files first:
- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Sections 7, 8, 11, and the Appendix on naming conventions)
- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 0.3 — iOS Networking & Service Layer)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Supabase.swift (existing Supabase client)
- /Users/humammourad/Projects/nook/apps/ios/Nook/AppRouter.swift (existing auth pattern — understand how supabase is used)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Profile/UserProfile.swift (existing profile model)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Search/SearchView.swift (read the existing enums: SearchMediaCategory, SearchResultItem, TrackingStatus, SearchState — we'll need to align new models with these)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Library/LibraryView.swift (read existing enums: LibraryMediaCategory, LibraryItem, LibraryFilter, LibrarySortOption)

Your task: Create the data models, error types, caching utility, APIClient, and service classes. DO NOT modify any existing files. The app must continue to compile and run with mock data.

All new files go under /Users/humammourad/Projects/nook/apps/ios/Nook/. Create `Models/` and `Services/` directories.

### 1. Create Models/AppError.swift
```swift
// Typed error enum as described in ARCHITECTURE.md Section 11
// Cases: networkError, rateLimited, unauthorized, notFound, clientError(String), serverError(Int), supabaseError(String), unknown(Error)
// Conform to LocalizedError with errorDescription
// Add: init(from error: Error) that maps common errors (URLError, etc.) to the right case
````

### 2. Create Models/MediaItem.swift

This is the core model. Create THREE types in this file:

- `APISearchResult` — Codable, maps to Edge Function search response items. Fields: media_id (String), source (thetvdb/kitsu/openlibrary), media_type (movie/tv/anime/manga/book), title, image_url (String?), year (String?), score (Double?)
- `APISearchResponse` — Codable, maps to full search response. Fields: results ([APISearchResult]), page (Int), total_pages (Int), per_page (Int)
- `APIMediaDetail` — Codable, maps to Edge Function detail response. Fields: media_id, source, media_type, source_url, title, image_url (String?), synopsis, genres ([String]), score (Double?), score_count (Int?), max_progress (Int?), details ([String: AnyCodable] or just use a details struct), related (with recommendations), db_id (UUID?)

For the `details` field, use a simple approach: make it `[String: JSONValue]` where JSONValue is a Codable enum handling string/int/double/bool/null/array/object. Or simpler: just store it as `Data?` and decode specific fields on demand. Choose whichever is cleaner — the key is that this field is a grab-bag of type-specific metadata.

Also create a `MediaSearchResult` — the view-facing model. It should be Identifiable + Hashable (for NavigationStack). Fields: id (UUID, auto-generated), mediaId (String), source, mediaType, title, imageURL (URL?), year (String?), score (Double?). Add an `init(from api: APISearchResult)` converter.

### 3. Create Models/TrackedMedia.swift

- `TrackedMediaRow` — Codable, maps to Supabase tracked_media table with nested media_item. Use CodingKeys for snake_case mapping.
- `TrackedMediaItem` — view-facing Identifiable + Hashable model with all display fields. Init from TrackedMediaRow.

### 4. Create Models/Review.swift

- `ReviewRow` — Codable, maps to reviews table with joined user_profiles (author name, avatar) and media_items (title, image).
- `Review` — view-facing Identifiable + Hashable.

### 5. Create Models/Club.swift

- `ClubRow` — Codable, maps to clubs table.
- `ClubMemberRow` — Codable, maps to club_members with joined user_profiles.
- View-facing models for both.

### 6. Create Models/ClubPost.swift

- `ClubPostRow` — Codable, maps to club_posts with joined user_profiles.
- View-facing model.

### 7. Create Models/NookModel.swift (avoid name collision with existing NookItem in views)

- `NookRow` — Codable, maps to nooks table.
- `NookItemRow` — Codable, maps to nook_items with joined media_items.
- View-facing models.

### 8. Create Models/Notification.swift

- `NotificationRow` — Codable, maps to notifications table with joined actor profile.
- View-facing model.

### 9. Create Models/ActivityFeedItem.swift

- `ActivityFeedRow` — Codable, maps to activity_feed with joined user_profiles and media_items.
- View-facing model.

### 10. Create Services/InMemoryCache.swift

The actor-based cache from ARCHITECTURE.md Section 5:

```swift
actor InMemoryCache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: (value: Value, timestamp: Date)] = [:]
    private let ttl: TimeInterval
    init(ttl: TimeInterval) { self.ttl = ttl }
    func get(_ key: Key) -> Value? { ... check TTL ... }
    func set(_ key: Key, value: Value) { ... }
    func invalidate(_ key: Key) { ... }
    func invalidateAll() { ... }
}
```

### 11. Create Services/APIClient.swift

As described in ARCHITECTURE.md Section 9 (iOS APIClient):

- Takes the Supabase URL and constructs Edge Function URLs
- POST requests with JSON body
- Attaches the user's JWT from `supabase.auth.session.accessToken`
- Uses URLSession with URLCache.shared
- Maps HTTP status codes to AppError cases
- Generic `func request<T: Decodable>(_ endpoint: String, body: Encodable) async throws -> T`

### 12. Create service stubs (methods with signatures but real implementations will come in later prompts):

- Services/MediaAPIService.swift — `func search(query:mediaType:page:) async throws -> APISearchResponse` and `func detail(source:sourceId:mediaType:) async throws -> APIMediaDetail`
- Services/TrackingService.swift — `func getLibrary(userId:) async throws -> [TrackedMediaItem]`, `func track(...)`, `func updateTracking(...)`, `func removeTracking(...)`
- Services/ReviewService.swift — stubs for CRUD + likes + comments
- Services/ClubService.swift — stubs for CRUD + membership + posts
- Services/NookService.swift — stubs for CRUD + items
- Services/ProfileService.swift — `func getProfile(userId:)`, `func updateProfile(...)`, `func follow(...)`, `func unfollow(...)`, `func getStats(...)`
- Services/NotificationService.swift — stubs
- Services/StorageService.swift — `func uploadImage(bucket:path:data:) async throws -> URL`
- Services/ActivityFeedService.swift — stubs

Each service should be a final class (not @Observable yet — we'll add that when we wire them to views).

### Key conventions:

- Use `import Supabase` where needed (already in the project)
- Use CodingKeys with snake_case strategy for all Supabase row types
- Make all Row types use `let` properties (immutable from DB)
- Make all view-facing types use `let` except mutable tracking state
- Use `UUID` for all Supabase id fields
- Use `Date` for all timestamp fields (Supabase SDK handles ISO8601)
- Follow existing code style: no trailing commas, standard Swift formatting
- Use design tokens from NookColors where color references are needed in models (like TrackingStatus dot colors)

DO NOT modify any existing files. DO NOT change any views. The app must compile and run exactly as before.

When done, say: "Models and services created. Project compiles. No existing files were modified."

```

---

## Prompt 4 — Wire Up Media Search (SearchView + Edge Functions)

**What it builds**: Replaces mock data in SearchView with real API calls. Search for "Naruto" and see real anime results from Kitsu. Search for "The Matrix" and see real movies from TheTVDB.

**What to test**: Run the app. Go to Search tab. Type "naruto" with anime filter — you should see real anime results with poster images. Switch to movies filter, type "inception" — real TheTVDB results. Try "dune" with books filter. Check that results have real images, scores, and years. Test pagination by scrolling to the bottom.

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Sections 3, 5, 6, 7 — fetching, caching, images, state management)
- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 1.1 — Wire Up Search)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Search/SearchView.swift (the current search view — understand every pattern before changing anything)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Search/TrackMediaSheet.swift (also uses search — needs same treatment)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/APIClient.swift (the client you'll use)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/MediaAPIService.swift (implement the real methods)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Models/MediaItem.swift (the models)

Also read the Edge Function code to understand the exact response shapes:

- /Users/humammourad/Projects/nook/supabase/functions/search-media/index.ts
- /Users/humammourad/Projects/nook/supabase/functions/\_shared/types.ts

Your task: Wire SearchView and TrackMediaSheet to use real API data instead of mock data.

### Step 1: Implement MediaAPIService.search()

Fill in the real implementation in Services/MediaAPIService.swift:

- Call APIClient to POST to "search-media" with { query, media_type, page }
- media_type mapping: the Edge Function expects "movie", "tv", "anime", "manga", "book" — map from SearchMediaCategory
- Return APISearchResponse
- Add in-memory caching (5 min TTL) keyed by "{type}:{query}:{page}"

### Step 2: Create a SearchViewModel

Create a new file at Views/Search/SearchViewModel.swift (or Services/ — your call, but keep it near the view).

This @Observable class should:

- Hold: results ([MediaSearchResult]), searchState (SearchState), searchText (String), selectedFilter (SearchMediaCategory?), currentPage, hasMorePages, error (AppError?)
- Have a `search()` method that cancels previous task, debounces 400ms, calls MediaAPIService.search(), maps results to [MediaSearchResult]
- Have a `loadNextPage()` method for pagination
- Mirror the existing debounce pattern from SearchView (searchTask?.cancel → Task.sleep → isCancelled check)

### Step 3: Modify SearchView.swift

- Remove all mock data (the static `mockAllMedia` array and `performSearch` method that filters mock data)
- Replace @State search properties with a @State SearchViewModel
- The SearchViewModel needs a MediaAPIService — for now, create it inline (we'll do proper DI later)
- Keep ALL existing UI code (layout, filter chips, result cards, animations, transitions, iOS 26 conditionals)
- Change the result items to use MediaSearchResult instead of SearchResultItem
- The result card should use AsyncImage for the image_url instead of Image(imageName) or placeholderColor
- Create a reusable MediaPosterImage view (as described in ARCHITECTURE.md Section 6) for the poster images with shimmer loading placeholder
- Add "load more" pagination: when the user scrolls to the last item, call viewModel.loadNextPage()
- Show error state if viewModel.error is set (a simple banner or toast)

### Step 4: Modify TrackMediaSheet.swift

- Same treatment: replace mock search with real API calls
- It has its own search functionality — reuse SearchViewModel or create a simpler variant
- Keep all existing UI

### Important:

- The MediaPosterImage component should go in Views/Components/MediaPosterImage.swift
- Use shimmer animation for loading state (a gray rounded rect with opacity animation)
- Keep the existing filter chip UI exactly as-is
- Keep the existing debounce timing (400ms)
- Keep all iOS 26+ conditional code
- Use design tokens (Color.nook._, NookFont._, NookRadii.\*) — don't use raw hex colors
- If there's no score from the API, don't show the score badge (instead of showing 0)
- If there's no image_url, show a colored placeholder (can use the category dot color from SearchMediaCategory)

When done, say: "Search is live. Build and run — type any query in the Search tab to see real results from TheTVDB/Kitsu/Open Library."

```

---

## Prompt 5 — Wire Up Media Detail View

**What it builds**: Tap a search result → see real media details (synopsis, genres, episodes, studios, score, etc.) fetched from the API.

**What to test**: Search for "Attack on Titan" (anime), tap it — should see real synopsis, episode count, studios, Kitsu score. Search for "The Godfather" (movie), tap it — runtime, director, cast, TheTVDB score. Try a book too.

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Sections 3, 7 — fetching flow, state management)
- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 1.2 — Media Detail View with Real Data, and Phase 1.3 — Upsert Media Items)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/MediaDetail/MediaDetailView.swift (current view — read ALL of it, understand every section)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/MediaAPIService.swift (implement the detail() method)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Models/MediaItem.swift (APIMediaDetail model)
- /Users/humammourad/Projects/nook/supabase/functions/media-detail/index.ts (understand the response shape)
- /Users/humammourad/Projects/nook/supabase/functions/\_shared/types.ts

Your task: Make MediaDetailView load real data from the API instead of displaying a pre-populated MediaDetail struct.

### Step 1: Implement MediaAPIService.detail()

- Call APIClient to POST to "media-detail" with { source, source_id, media_type }
- Return APIMediaDetail
- Cache in-memory with 1 hour TTL keyed by "{source}:{source_id}"

### Step 2: Create MediaDetailViewModel

New @Observable class:

- Input: mediaId (String), source (String), mediaType (String) — enough to fetch from API
- Also accept optional pre-populated fields from search result (title, imageURL, year, score) so the view can show something immediately while loading
- State: detail (APIMediaDetail?), isLoading, error (AppError?)
- On init, show the pre-populated fields. On .task, call detail() and populate the full view.
- Extract the db_id (UUID) from the response — this is the media_items table ID needed for tracking/reviews later.

### Step 3: Change navigation to pass lightweight data

Currently, NavigationStack uses `navigationDestination(for: MediaDetail.self)` where MediaDetail is a heavy struct with all data pre-populated from mock.

Change this: The search result card should navigate using a lightweight identifier (mediaId + source + mediaType + preview data), NOT the full MediaDetail. The MediaDetailView then fetches the full detail on appear.

You'll need to:

- Create a `MediaDetailRoute` struct (Identifiable + Hashable) with: mediaId, source, mediaType, title, imageURL, year, score (the preview fields from search)
- Change `navigationDestination(for: MediaDetail.self)` to `navigationDestination(for: MediaDetailRoute.self)` in MainTabView.swift
- Change MediaDetailView to accept a MediaDetailRoute and create its own MediaDetailViewModel

### Step 4: Update MediaDetailView to use real data

- Replace the `let media: MediaDetail` with the ViewModel
- On appear (.task), call viewModel.loadDetail()
- While loading: show the preview data (title, image, score from the route) with a loading skeleton for the rest
- Once loaded: populate all sections — synopsis, details grid, genres, related/recommendations
- The dominant color extraction should work with the remote image URL (load via URLSession, then extract — or skip it for now and use a default gradient if the async image extraction is complex)
- Map the details dict to the appropriate fields based on media_type (movies show director + runtime, anime shows studios + episodes, books show author + pages)
- Keep the Reviews tab and Track button — they'll show empty/non-functional for now, that's fine

### Important:

- The existing MediaDetailView is 2199 lines. Be surgical — change the data source, don't rewrite the UI.
- Keep all animations, transitions, iOS 26 conditionals, sheet presentations exactly as they are.
- The image at the top should use AsyncImage with the URL from the API (replacing Image(media.imageName))
- If detail loading fails, show an error state with a retry button
- Preserve the existing Hashable conformance patterns for navigation

When done, say: "Media detail is live. Tap any search result to see real data from the API."

```

---

## Prompt 6 — Wire Up Tracking & Library

**What it builds**: Users can track media (set status, progress, score) and see their tracked items in the Library tab, persisted to Supabase.

**What to test**: Search for an anime, tap it, tap "Track", set status to "In Progress" with episode 5 and score 8. Go to Library tab — the anime should appear with correct status/progress/score. Change the status to "Completed" — library should update. Close and reopen the app — library data should persist.

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Sections 4, 7, 8 — storage, state, services — especially the "Data Flow for a Tracking Mutation" diagram)
- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 2 — all of it)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Library/LibraryView.swift (current view with mock data)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/MediaDetail/MediaDetailView.swift (the tracking sheet integration)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Search/SearchView.swift (the tracking sheet from search results)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Home/ContinueTrackingSection.swift (in-progress items on home)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/TrackingService.swift (implement the real methods)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Models/TrackedMedia.swift (the models)
- /Users/humammourad/Projects/nook/supabase/migrations/ (check the tracked_media and media_items table schemas)

Your task: Implement tracking persistence and wire up the Library view.

### Step 1: Implement TrackingService

Fill in the real methods:

- `getLibrary(userId: UUID) async throws -> [TrackedMediaItem]` — query tracked_media joined with media_items (use `.select("*, media_item:media_items(*)")`), ordered by updated_at DESC
- `track(mediaItemId: UUID, status: String, progress: Int, score: Double?) async throws` — upsert into tracked_media (on conflict user_id + media_item_id)
- `updateTracking(trackingId: UUID, status: String?, progress: Int?, score: Double?) async throws` — update specific fields
- `removeTracking(trackingId: UUID) async throws` — delete from tracked_media
- `getTrackingForMedia(userId: UUID, mediaItemId: UUID) async throws -> TrackedMediaRow?` — check if user is already tracking this media
- Add in-memory cache for library (invalidate on any mutation)

### Step 2: Create LibraryViewModel

@Observable class:

- Holds: items ([TrackedMediaItem]), filteredItems (computed), selectedFilter, selectedSort, searchText, isLoading, error
- loadLibrary() — calls TrackingService.getLibrary()
- All the existing filter/sort logic from LibraryView should move here (currently it's computed properties in the view)

### Step 3: Wire up LibraryView

- Replace mock `items` with LibraryViewModel
- Load library on .task { await viewModel.loadLibrary() }
- Keep ALL existing UI — filter chips, sort menu, search bar, item cards, glass effects
- Replace Image(item.imageName) / placeholderColor with MediaPosterImage (the component from Prompt 4)
- Add pull-to-refresh
- The tracking sheet should now call TrackingService to persist changes (not just update local state)

### Step 4: Wire up tracking from MediaDetailView

- When user taps "Track" on MediaDetailView:
  1. The detail view already has the db_id (media_items UUID) from the API response
  2. Call TrackingService.track() with the db_id, status, progress, score
  3. Use optimistic update: change local tracking state immediately, fire Supabase call in background, rollback on error
- When user opens MediaDetailView for already-tracked media, check if tracking exists (TrackingService.getTrackingForMedia) and pre-populate the status/progress/score

### Step 5: Wire up tracking from SearchView

- When user taps a search result and tracks from the tracking sheet:
  1. First ensure the media_item exists in Supabase (it should already exist if user viewed the detail, but if they tracked directly from search, it might not). The TrackMediaSheet should call media-detail Edge Function first (or at minimum, the search result should carry enough data to create a media_items row).
  2. Then call TrackingService.track()

### Step 6: Wire up ContinueTrackingSection on Home

- Replace mock items with a query: tracked_media WHERE status = 'in_progress' ORDER BY updated_at DESC LIMIT 10
- Show real media images, titles, progress

### Important:

- Use the Supabase SDK directly in TrackingService (not Edge Functions — this is user data, not API proxy)
- All Supabase queries need the user's JWT (the SDK handles this automatically since the user is authenticated)
- The user_id comes from `supabase.auth.session.user.id`
- Use design tokens for all colors and fonts
- Handle the "not logged in" edge case gracefully (shouldn't happen since auth is required, but don't crash)

When done, say: "Tracking and Library are live. Track media from search or detail view, and see it in the Library tab."

```

---

## Prompt 7 — User Profiles & Edit Profile

**What it builds**: Real profile data from Supabase. Edit profile with avatar upload. View other users' profiles.

**What to test**: Go to your profile — it should show your real name/email (from auth), interests, tracked count. Edit profile: set a username, bio, upload a photo. Close and reopen — changes should persist. The avatar should show in the Home header too.

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Sections 4, 8 — storage, services)
- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 0.4 and Phase 4.1, 4.2, 4.4)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Profile/MyProfileView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Profile/OtherProfileView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Profile/StatsView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Profile/UserProfile.swift (existing model)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Settings/EditProfileSheet.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Home/HomeView.swift (avatar loading)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Home/HomeHeaderView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/AppRouter.swift (extend to save full_name on Apple Sign-in)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/ProfileService.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/StorageService.swift

Your task: Implement profile data persistence with Supabase.

### Step 1: Implement ProfileService

- `getProfile(userId: UUID) async throws -> UserProfileData` — query user_profiles joined with stats
- `updateProfile(userId: UUID, fullName: String?, username: String?, bio: String?, avatarURL: String?) async throws` — update user_profiles
- `checkUsernameAvailable(username: String) async throws -> Bool` — query user_profiles WHERE username = X AND id != current user
- `getStats(userId: UUID) async throws -> UserStats` — call the get_user_stats database function (or query counts directly)

### Step 2: Implement StorageService

- `uploadAvatar(userId: UUID, imageData: Data) async throws -> URL` — upload to `avatars/{userId}/avatar.jpg`, return public URL
- Use Supabase Storage SDK: `supabase.storage.from("avatars").upload(...)`

### Step 3: Update AppRouter

- On Apple Sign-in success, if the user's full name is captured, save it to user_profiles.full_name (currently it only saves to auth metadata)
- On Google Sign-in, extract display name from the Google profile and save similarly

### Step 4: Wire up EditProfileSheet

- Load current profile data on appear
- Save to Supabase on submit (not just local state)
- Avatar: when user picks a photo, upload via StorageService, get URL, save URL to user_profiles.avatar_url
- Username validation: check availability as user types (debounced), show error if taken, enforce regex pattern

### Step 5: Wire up MyProfileView

- Load profile from ProfileService on appear
- Load stats from ProfileService (tracked count, reviews count, nooks count, clubs count)
- Tracked tab: reuse TrackingService.getLibrary() with filter
- Reviews/Nooks/Communities tabs: show real counts (data for these tabs will come in later prompts — for now just show the count and "Coming soon" or empty state)

### Step 6: Wire up HomeView avatar

- Load avatar_url from user_profiles (not just auth metadata)
- Use AsyncImage for the avatar in HomeHeaderView

### Step 7: Wire up StatsView

- Load real stats: total tracked, review count, nook count, club count from Supabase
- Category breakdown: GROUP BY media_type on tracked_media (via Supabase query or RPC)
- Rating distribution: aggregate scores (can be a simple count per score value)
- The rest (streak, genre breakdown) can remain as placeholder for now

### Important:

- The existing UserProfile model in Views/Profile/UserProfile.swift has sample profiles for preview. Keep that for SwiftUI previews but load real data at runtime.
- Don't break preview providers
- Use design tokens for all UI
- Handle the case where user has no profile yet (first login before any profile edit)

When done, say: "Profiles are live. Edit your profile, upload an avatar, and see real stats."

```

---

## Prompt 8 — Reviews System

**What it builds**: Write reviews, see reviews on media detail, like/comment on reviews.

**What to test**: Open a media detail. Tap "Write Review". Write a review with rating 8, some text, mark as spoiler. Submit. The review should appear on the media's Reviews tab. Open the review detail — like it, write a comment. Go to another media detail — it should show "no reviews yet".

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 3 — all of it)
- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Section 7 — optimistic updates for likes)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/MediaDetail/MediaDetailView.swift (reviews tab section)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Reviews/ReviewDetailView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Home/TrendingReviewsSection.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/ReviewService.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Models/Review.swift

Your task: Implement the full reviews system.

### Step 1: Implement ReviewService

- `getReviewsForMedia(mediaItemId: UUID, page: Int) async throws -> [Review]` — query reviews joined with user_profiles, ordered by created_at DESC, with pagination
- `createReview(mediaItemId: UUID, title: String?, body: String, rating: Double, isSpoiler: Bool) async throws -> Review`
- `deleteReview(reviewId: UUID) async throws`
- `likeReview(reviewId: UUID) async throws` — insert into review_likes (optimistic: return immediately, fire DB call async)
- `unlikeReview(reviewId: UUID) async throws` — delete from review_likes
- `isReviewLiked(reviewId: UUID) async throws -> Bool`
- `getComments(reviewId: UUID) async throws -> [ReviewComment]` — query review_comments with nesting
- `addComment(reviewId: UUID, body: String, parentCommentId: UUID?) async throws`
- `getTrendingReviews(limit: Int) async throws -> [Review]` — recent reviews ordered by likes_count DESC

### Step 2: Create ComposeReviewSheet

New file at Views/Reviews/ComposeReviewSheet.swift:

- Form with: rating picker (0-10 with half steps or whole numbers), title (optional), body (TextEditor), spoiler toggle
- Submit calls ReviewService.createReview()
- Also inserts an activity_feed entry (action_type: "reviewed")
- Presented from MediaDetailView when user taps "Write Review"
- Design: match the existing sheet aesthetics (presentationDetents, background color, drag indicator)

### Step 3: Wire up Reviews tab on MediaDetailView

- Load reviews for this media item on tab selection
- Replace mock reviews with real data
- Show author name, avatar (AsyncImage), rating badge, body preview, spoiler tag
- "Write Review" button opens ComposeReviewSheet
- Pass the media_items db_id (from detail response) to the review queries

### Step 4: Wire up ReviewDetailView

- Load full review + comments from Supabase
- Like/unlike: optimistic update (toggle UI immediately, fire DB call)
- Comments: load and display nested (parent_comment_id). Add comment form at bottom.
- Navigate to author profile on avatar tap

### Step 5: Wire up TrendingReviewsSection on Home

- Replace mock data with ReviewService.getTrendingReviews(limit: 5)
- Show review cards with media thumbnail, author, rating

When done, say: "Reviews system is live. Write reviews, like them, comment on them, and see trending reviews on Home."

```

---

## Prompt 9 — Nooks (Collections)

**What it builds**: Create nooks, add media to them, view nook detail, see popular nooks on home.

**What to test**: Tap the FAB → Create Nook. Name it "Comfort Movies", add a description, search and add 3 movies, add notes to each. Save. Go to your profile → Nooks tab — it should appear. Tap it — see the detail with all 3 movies and notes. Check Home → Popular Nooks section.

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 5 — all of it)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Nooks/CreateNookSheet.swift (current UI)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Nooks/NookDetailView.swift (current UI)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Home/PopularNooksSection.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/NookService.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Models/NookModel.swift

Your task: Implement the full nooks system.

### Step 1: Implement NookService

- `createNook(name:description:coverData:privacy:layout:items:) async throws -> NookRow` — upload cover to Storage if provided, insert nook row, insert nook_items, insert activity_feed entry
- `getNook(nookId: UUID) async throws -> NookDetail` — nook + items joined with media_items + owner profile
- `getUserNooks(userId: UUID) async throws -> [NookRow]`
- `updateNook(...) async throws`
- `deleteNook(nookId: UUID) async throws`
- `getPopularNooks(limit: Int) async throws -> [NookRow]` — public nooks ordered by item count or recency

### Step 2: Wire up CreateNookSheet

- The "Add Media" search within CreateNookSheet should use the real MediaAPIService.search()
- On save: call NookService.createNook() with all form data
- Cover image upload via StorageService
- Dismiss on success with haptic feedback

### Step 3: Wire up NookDetailView

- Load real nook data on appear
- Show media items with MediaPosterImage
- Show owner info (name, avatar)
- Edit/delete actions if current user is owner

### Step 4: Wire up PopularNooksSection on Home

- Replace mock data with NookService.getPopularNooks()

When done, say: "Nooks are live. Create collections, add media with notes, and see them on your profile and Home."

```

---

## Prompt 10 — Clubs & Communities

**What it builds**: Create clubs, join/leave, post, comment, like posts.

**What to test**: Create a club with a name and category. Go to Communities tab — see your club. Open it, write a post. Like the post. Leave the club and rejoin. Check that member count updates.

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 6 — all of it)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Communities/CommunitiesView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Communities/ClubDetailView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Communities/CreateClubSheet.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Communities/ComposePostView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Communities/PostDetailView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/ClubService.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Models/Club.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Models/ClubPost.swift

Your task: Implement the full clubs/communities system.

### Step 1: Implement ClubService

- createClub, getClub, getMyClubs, getPublicClubs, joinClub, leaveClub
- createPost, getPosts (paginated), likePost, unlikePost
- getComments, addComment
- Upload banner/icon via StorageService

### Step 2: Create CommunitiesViewModel

- Two sections: "My Clubs" (where user is member) and "Discover" (public clubs)
- Category filter

### Step 3: Create ClubDetailViewModel

- Club info, members list, posts feed with pagination
- Join/leave actions
- Post composition

### Step 4: Wire up all community views

- CommunitiesView: real club lists
- CreateClubSheet: persist to Supabase with image upload
- ClubDetailView: real posts, members, join/leave
- ComposePostView: insert club_posts
- PostDetailView: real comments, likes

Keep all existing UI — just replace mock data sources.

When done, say: "Clubs are live. Create clubs, post, comment, and manage membership."

```

---

## Prompt 11 — Follow System, Activity Feed & Notifications

**What it builds**: Follow/unfollow users, see activity from followed users on Home, real notifications.

**What to test**: View another user's profile (navigate from a review author or club member). Tap Follow. Go to Home — their activity should appear in the feed. Check notifications — you should see a follow notification if someone follows you back (test with two accounts or manually insert a row).

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 4.3, Phase 7 — all of it)
- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Section 10 — Realtime & Notifications, the activity_feed SQL query)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Profile/OtherProfileView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Home/ActivityFeedSection.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Notifications/NotificationsView.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/ProfileService.swift (add follow/unfollow)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/ActivityFeedService.swift
- /Users/humammourad/Projects/nook/apps/ios/Nook/Services/NotificationService.swift

Your task: Implement follows, activity feed, and notifications.

### Step 1: Add follow/unfollow to ProfileService

- follow(userId:) — insert user_follows + insert notification for followed user
- unfollow(userId:) — delete user_follows
- isFollowing(userId:) — check if current user follows target
- getFollowerCount/getFollowingCount

### Step 2: Implement ActivityFeedService

- getFeed(userId: UUID, page: Int) async throws -> [ActivityFeedItem]
- The query joins activity_feed with user_profiles and media_items, filtered to followed users
- Include the SQL from ARCHITECTURE.md Section 10

### Step 3: Implement NotificationService

- getNotifications(page: Int) async throws -> [NotificationItem]
- markAsRead(notificationId: UUID) async throws
- markAllAsRead() async throws
- getUnreadCount() async throws -> Int

### Step 4: Wire up OtherProfileView

- Follow/unfollow button (already exists as UI shell) — call ProfileService
- Show follower/following counts

### Step 5: Wire up ActivityFeedSection on Home

- Replace mock data with real feed from followed users
- Show activity cards: "X tracked Y", "X reviewed Y", etc.
- Pull-to-refresh

### Step 6: Wire up NotificationsView

- Load real notifications grouped by time (Today, This Week, Earlier)
- Mark as read on view
- Badge count on bell icon in HomeHeaderView
- Tap to navigate to referenced content

When done, say: "Social features are live. Follow users, see their activity on Home, and get notifications."

```

---

## Prompt 12 — Settings Completion & Polish

**What it builds**: Complete the stubbed settings features, add loading skeletons everywhere, finalize error handling.

**What to test**: Settings → Clear Cache (should actually clear). Settings → Delete Account (should delete and sign out). Check that every list view shows a shimmer loading state before data arrives. Check that network errors show a user-friendly message.

```

You are working on the Nook iOS app at /Users/humammourad/Projects/nook.

Read these files:

- /Users/humammourad/Projects/nook/IMPLEMENTATION_PLAN.md (Phase 8 — all of it)
- /Users/humammourad/Projects/nook/ARCHITECTURE.md (Sections 11, 12 — error handling, offline)
- /Users/humammourad/Projects/nook/apps/ios/Nook/Views/Settings/SettingsView.swift (has TODOs for cache clear and delete account)

Your task: Final polish pass.

### Step 1: Settings completion

- Clear Cache: clear URLCache.shared, clear all in-memory caches across services, show confirmation
- Delete Account: show confirmation alert, call a Supabase Edge Function or RPC that deletes the user (CASCADE should handle related data), then sign out and navigate to IntroView
- Notification preferences: add a toggle that saves to user_profiles (add a `notifications_enabled` column if needed, or just use UserDefaults for local preference)

### Step 2: Loading skeletons

Create a reusable ShimmerView component (animated gray placeholder) and apply it to:

- Search results (while searching)
- Library items (while loading)
- Media detail (while fetching)
- Reviews (while loading)
- Club posts (while loading)
- Activity feed (while loading)
- Notifications (while loading)
- Profile (while loading)
  Match the size/shape of the actual content cards so the skeleton looks natural.

### Step 3: Error handling audit

Go through every ViewModel and Service call and ensure:

- No `try?` remains (all errors are caught and surfaced)
- Network errors show a banner/toast (not silent failure)
- 401/unauthorized redirects to login
- Empty states have appropriate messaging ("No reviews yet", "Nothing tracked", etc.)

### Step 4: Pull-to-refresh

Add pull-to-refresh to any scrollable view that loads from the network:

- Library, Home feed, Club posts, Notifications, Profile tabs

### Step 5: URLCache configuration

In NookApp.swift, configure URLCache at app startup:

```swift
URLCache.shared = URLCache(
    memoryCapacity: 50_000_000,  // 50 MB
    diskCapacity: 100_000_000,   // 100 MB
    diskPath: "nook_url_cache"
)
```

When done, say: "Polish complete. All settings work, loading skeletons are in place, and errors are handled gracefully."

```

---

## Summary: Prompt Sequence

| # | Prompt | Builds | Test Checkpoint |
|---|---|---|---|
| 1 | Database Schema | All Supabase tables, RLS, triggers, storage | Check tables in Supabase Studio |
| 2 | Edge Functions | COMPLETED — deployed (TheTVDB, Kitsu, Open Library) | N/A |
| 3 | iOS Models & Services | Swift models, APIClient, service stubs | Xcode builds, app runs with mock data unchanged |
| 4 | Wire Search | Real search results from APIs | Search "naruto" → real anime results with images (5 media types) |
| 5 | Wire Media Detail | Real detail data on tap | Tap result → real synopsis, score, episodes |
| 6 | Wire Tracking & Library | Persist tracking, real library | Track anime, see it in Library, survives app restart |
| 7 | Profiles & Edit | Real profiles, avatar upload | Edit profile, upload photo, see stats |
| 8 | Reviews | Write/read/like/comment reviews | Write review, see it on media detail |
| 9 | Nooks | Create/view collections | Create nook with 3 movies, see on profile |
| 10 | Clubs | Create/join/post/comment in clubs | Create club, post, like, leave/rejoin |
| 11 | Social & Feed | Follow, activity feed, notifications | Follow user, see activity on Home |
| 12 | Polish | Settings, skeletons, error handling, media catalog caching | Clear cache, delete account, loading states, DB-first search |

### Media Catalog Caching (included in Prompt 12)

**Already done:**
- Search results auto-upsert into `media_items` on every search (Step 1 — deployed)
- Detail view upserts full detail into `media_items` (Step 2 — deployed)

**Prompt 12 adds:**
- DB-first search: before hitting provider, query `media_items` for cached matches. If enough results, skip provider call.
- Staleness re-fetch: on detail view, if `media_items.updated_at` > 30 days old, re-fetch from provider and update row.

**Post-launch (not in prompts):**
- Cron Edge Function to resync popular+stale `media_items` rows periodically.
```
