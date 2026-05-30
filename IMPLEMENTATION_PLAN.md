# Nook Implementation Plan

> From shell to real app — a phased roadmap to bring every screen to life with real data, real APIs, and a real backend.

**Date**: 2026-05-29
**Current state**: Auth (Email OTP, Apple, Google) and onboarding work end-to-end. Every other screen uses hardcoded mock data. Only one Supabase table exists (`user_profiles` with interests + onboarding flag).

**Reference project**: `/Users/humammourad/Projects/tracker` — a Django/Python multi-media tracker. We use it strictly as reference for API patterns. Nook uses TheTVDB (movies/TV), Kitsu (anime/manga), and Open Library (books).

---

## Architecture Decisions (Read First)

### API Provider Mapping for Nook

| Nook Media Type | Primary API  | Auth Method                                            | Ref File                                   |
| --------------- | ------------ | ------------------------------------------------------ | ------------------------------------------ |
| Movies          | TheTVDB      | API Key → POST /login → Bearer token (cached ~1 month) | `tracker/src/app/providers/tmdb.py`        |
| TV Shows        | TheTVDB      | API Key → POST /login → Bearer token (cached ~1 month) | `tracker/src/app/providers/tmdb.py`        |
| Anime           | Kitsu        | None (public JSON:API)                                 | `tracker/src/app/providers/mal.py`         |
| Manga           | Kitsu        | None (public JSON:API)                                 | `tracker/src/app/providers/mal.py`         |
| Books           | Open Library | None (public)                                          | `tracker/src/app/providers/openlibrary.py` |

> Kitsu and Open Library are both public APIs requiring no auth. TheTVDB requires an API key to obtain a Bearer token. Hardcover (GraphQL + JWT) can be added later as an alternative book source if needed.

### Backend Architecture

- **Supabase Postgres** — all user data, tracking, reviews, clubs, nooks, follows, notifications
- **Supabase Storage** — avatars, nook covers, club banners
- **Supabase Realtime** — live notifications, activity feed updates, club chat
- **Supabase Edge Functions** — API proxy for keys that shouldn't live on-device (TheTVDB auth, future webhooks)
- **Row Level Security (RLS)** — on every table, enforcing ownership and visibility rules

### iOS Architecture

- **Services layer** (`Services/`) — one service per domain (MediaAPI, TrackingService, ReviewService, etc.)
- **Models layer** (`Models/`) — Codable structs mapping to both API responses and Supabase tables
- **ViewModels** — `@Observable` classes per major screen, owned by the view
- **Existing views** — keep all current SwiftUI views, replace mock data with real bindings

---

## Phase 0: Foundation & Infrastructure

> Set up the backend schema, networking layer, and service architecture that every subsequent phase depends on.

### 0.1 — Supabase Database Schema

Create migrations for all tables needed across the app. This is the single most important step — every feature depends on the schema being right.

**Tables to create:**

```
user_profiles (EXTEND existing)
├── Add: full_name, username, bio, avatar_url
├── Add: created_at, updated_at (already exist)
└── Keep: interests, onboarding_completed

user_follows
├── follower_id (uuid, FK → auth.users)
├── following_id (uuid, FK → auth.users)
├── created_at
└── Unique constraint on (follower_id, following_id)

media_items (cached API media — acts as a local catalog)
├── id (uuid, PK)
├── source (text: thetvdb, kitsu, openlibrary)
├── source_id (text: external API ID)
├── media_type (text: movie, tv, anime, manga, book)
├── title (text)
├── image_url (text, nullable)
├── year (text, nullable)
├── genres (text[], nullable)
├── score (decimal, nullable — community score from API)
├── score_count (int, nullable)
├── synopsis (text, nullable)
├── details (jsonb, nullable — format-specific: episodes, pages, studios, etc.)
├── created_at, updated_at
└── Unique constraint on (source, source_id)

tracked_media (user's tracking entries)
├── id (uuid, PK)
├── user_id (uuid, FK → auth.users)
├── media_item_id (uuid, FK → media_items)
├── status (text: in_progress, planned, on_hold, dropped, completed)
├── progress (int, default 0 — episodes watched, pages read, etc.)
├── score (decimal, nullable — user's personal rating 0-10)
├── started_at (timestamptz, nullable)
├── completed_at (timestamptz, nullable)
├── notes (text, nullable)
├── created_at, updated_at
└── Unique constraint on (user_id, media_item_id)

reviews
├── id (uuid, PK)
├── user_id (uuid, FK → auth.users)
├── media_item_id (uuid, FK → media_items)
├── title (text, nullable)
├── body (text)
├── rating (decimal — 0-10)
├── is_spoiler (boolean, default false)
├── likes_count (int, default 0)
├── created_at, updated_at
└── Index on (media_item_id, created_at)

review_likes
├── user_id (uuid, FK → auth.users)
├── review_id (uuid, FK → reviews)
├── created_at
└── PK on (user_id, review_id)

review_comments
├── id (uuid, PK)
├── review_id (uuid, FK → reviews)
├── user_id (uuid, FK → auth.users)
├── parent_comment_id (uuid, nullable, FK → review_comments — for nesting)
├── body (text)
├── created_at, updated_at

clubs
├── id (uuid, PK)
├── owner_id (uuid, FK → auth.users)
├── name (text)
├── description (text, nullable)
├── category (text: movies, tv, anime, manga, books, mixed)
├── privacy (text: public, friends_only, members_only)
├── banner_url (text, nullable)
├── icon_url (text, nullable)
├── member_count (int, default 1)
├── created_at, updated_at

club_members
├── club_id (uuid, FK → clubs)
├── user_id (uuid, FK → auth.users)
├── role (text: owner, admin, member)
├── joined_at (timestamptz)
└── PK on (club_id, user_id)

club_posts
├── id (uuid, PK)
├── club_id (uuid, FK → clubs)
├── user_id (uuid, FK → auth.users)
├── body (text)
├── is_pinned (boolean, default false)
├── likes_count (int, default 0)
├── created_at, updated_at

club_post_likes
├── user_id (uuid, FK → auth.users)
├── post_id (uuid, FK → club_posts)
├── created_at
└── PK on (user_id, post_id)

club_post_comments
├── id (uuid, PK)
├── post_id (uuid, FK → club_posts)
├── user_id (uuid, FK → auth.users)
├── parent_comment_id (uuid, nullable, FK → club_post_comments)
├── body (text)
├── created_at, updated_at

nooks
├── id (uuid, PK)
├── user_id (uuid, FK → auth.users)
├── name (text)
├── description (text, nullable)
├── cover_url (text, nullable)
├── privacy (text: public, friends_only, private)
├── layout (text: grid, list)
├── created_at, updated_at

nook_items
├── id (uuid, PK)
├── nook_id (uuid, FK → nooks)
├── media_item_id (uuid, FK → media_items)
├── note (text, nullable — personal commentary)
├── sort_order (int)
├── created_at

notifications
├── id (uuid, PK)
├── user_id (uuid, FK → auth.users — recipient)
├── actor_id (uuid, FK → auth.users — who triggered it)
├── type (text: follow, like_review, comment_review, like_post, comment_post, club_invite, nook_mention)
├── reference_id (uuid, nullable — points to review/post/club/nook)
├── reference_type (text, nullable — review, post, club, nook)
├── is_read (boolean, default false)
├── created_at

activity_feed (denormalized for fast home feed)
├── id (uuid, PK)
├── user_id (uuid, FK → auth.users — who did the action)
├── action_type (text: tracked, reviewed, created_nook, joined_club, completed)
├── media_item_id (uuid, nullable, FK → media_items)
├── reference_id (uuid, nullable — review/nook/club id)
├── reference_type (text, nullable)
├── created_at
```

**RLS policies** for every table — users read their own data + public data based on privacy settings. Follow relationships gate "friends_only" content.

**Database functions:**

- `increment_member_count()` / `decrement_member_count()` — triggers on club_members insert/delete
- `increment_likes_count()` / `decrement_likes_count()` — triggers on review_likes / club_post_likes
- `get_user_stats(user_id)` — returns tracked count, review count, nook count, club count
- `get_home_feed(user_id, limit, offset)` — returns activity from followed users

**Supabase Storage buckets:**

- `avatars` — user profile photos (public read, authenticated write own)
- `nook-covers` — nook cover images (public read, authenticated write own)
- `club-assets` — club banners and icons (public read, club owner write)

### 0.2 — Supabase Edge Functions (API Proxy) ✅

Media APIs need keys that shouldn't be embedded in the iOS binary. Create Edge Functions that proxy requests and manage API keys server-side.

**Edge Functions to create:**

```
supabase/functions/
├── _shared/
│   ├── providers.ts     → Provider routing (getProvider by media_type)
│   └── thetvdb-auth.ts  → TheTVDB Bearer token management (cached ~1 month)
│
├── search-media/        → Unified search endpoint
│   Accepts: { query, media_type, page }
│   Routes to: TheTVDB / Kitsu / OpenLibrary based on media_type
│   Returns: standardized { results[], page, total_pages }
│
└── media-detail/        → Fetch full media details
    Accepts: { source, source_id, media_type }
    Returns: standardized media detail object
```

**Environment variables to configure on Supabase:**

- `THETVDB_API_KEY`

> Kitsu (https://kitsu.io/api/edge) and Open Library require no API keys or auth.

**Standardized API response format** (same shape for all providers):

```json
{
  "media_id": "string",
  "source": "thetvdb|kitsu|openlibrary",
  "media_type": "movie|tv|anime|manga|book",
  "title": "string",
  "image_url": "string?",
  "year": "string?",
  "genres": ["string"],
  "score": 7.5,
  "score_count": 12345,
  "synopsis": "string?",
  "details": {
    // media-type-specific fields
  }
}
```

### 0.3 — iOS Networking & Service Layer

Build the foundational networking code on the iOS side.

**Files to create:**

```
apps/ios/Nook/Services/
├── APIClient.swift              → Generic HTTP client for Edge Functions
├── MediaAPIService.swift        → Search + detail via Edge Functions
├── TrackingService.swift        → CRUD on tracked_media via Supabase SDK
├── ReviewService.swift          → CRUD on reviews, likes, comments
├── ClubService.swift            → CRUD on clubs, posts, members
├── NookService.swift            → CRUD on nooks + nook_items
├── ProfileService.swift         → User profiles, follows, stats
├── NotificationService.swift    → Fetch + mark read notifications
├── StorageService.swift         → Upload/download from Supabase Storage
└── ActivityFeedService.swift    → Home feed queries

apps/ios/Nook/Models/
├── MediaItem.swift              → Maps to media_items table + API responses
├── TrackedMedia.swift           → Maps to tracked_media table
├── Review.swift                 → Maps to reviews table
├── Club.swift                   → Maps to clubs + club_members
├── ClubPost.swift               → Maps to club_posts
├── Nook.swift                   → Maps to nooks + nook_items
├── UserProfile.swift            → EXTEND existing — add Codable conformance for Supabase
├── Notification.swift           → Maps to notifications table
└── ActivityFeedItem.swift       → Maps to activity_feed table
```

**Key patterns:**

- All services use the Supabase Swift SDK directly for database operations
- Media search/detail goes through Edge Functions via `APIClient`
- Services are `@Observable` classes injected via SwiftUI environment
- Pagination via cursor-based (created_at) or offset-based depending on use case
- Error handling with typed errors that views can display

### 0.4 — Extend `user_profiles` & Profile Service

Update the existing profile flow to support the full profile fields.

**Changes:**

- Extend `user_profiles` migration with `full_name`, `username`, `bio`, `avatar_url`
- Update `AppRouter` to save full name from Apple Sign-in into `user_profiles`
- Update `EditProfileSheet` to write to Supabase instead of local state
- Update `MyProfileView` and `OtherProfileView` to load from Supabase
- Implement avatar upload via Supabase Storage
- Add username uniqueness check (database constraint + client validation)

---

## Phase 1: Media Search & Discovery (Search Tab)

> Replace mock search data with real API results. This is the core user action — finding media to track.

### 1.1 — Wire Up Search to Edge Functions

**What changes:**

- `SearchView.swift` — replace mock `searchResults` array with calls to `MediaAPIService.search(query:mediaType:page:)`
- Keep the existing debounce (400ms) and filter chip UI
- Map API response to `SearchResultItem` (or replace with new `MediaItem` model)
- Add pagination — load more on scroll to bottom
- Handle loading states (skeleton placeholders), empty states, and errors
- Cache recent searches locally (UserDefaults or SwiftData)

**API flow:**

```
User types → 400ms debounce → MediaAPIService.search()
  → Edge Function /search-media
    → TheTVDB (movies/tv) | Kitsu (anime/manga) | OpenLibrary (books)
  → Standardized response → Display in SearchView
```

### 1.2 — Media Detail View with Real Data

**What changes:**

- `MediaDetailView.swift` — accept a `MediaItem` (from search) and fetch full details
- Call `MediaAPIService.detail(source:sourceId:mediaType:)` on appear
- Map response to populate: title, year, genres, episodes, rating, synopsis, studio/director, status, air dates
- Show loading skeleton while fetching
- Keep the existing review section (will be wired up in Phase 3)
- Keep the tracking button (will be wired up in Phase 2)

**Media-type-specific detail fields (from tracker reference):**

| Field          | Movies       | TV         | Anime             | Manga          | Books        |
| -------------- | ------------ | ---------- | ----------------- | -------------- | ------------ |
| Episodes/Pages | —            | episodes   | episodes          | chapters       | pages        |
| Runtime        | runtime      | ep runtime | ep runtime        | —              | —            |
| Studio         | studios      | studios    | studios           | —              | publisher    |
| Director       | director     | —          | —                 | authors        | authors      |
| Status         | Released/etc | Airing/etc | Airing/etc        | Publishing/etc | —            |
| Dates          | release_date | start/end  | start/end         | start/end      | release_date |
| Source         | —            | —          | source (manga/LN) | —              | —            |

### 1.3 — Upsert Media Items to Supabase

When a user views media details or tracks something, upsert the media item to `media_items` table so it can be referenced by tracking, reviews, nooks, etc.

**Logic:**

- On detail view load: check if `media_items` has this (source, source_id) → if not, insert
- On track action: ensure media item exists before creating tracked_media row
- This creates a local catalog that grows organically as users interact with media

### 1.4 — Media Catalog Caching Strategy

**Goal:** Reduce provider dependency over time. The `media_items` table becomes a growing catalog — fetch from providers once, serve from our DB forever, resync periodically.

**How it works:**

1. **Search results → save to DB.** When the `search-media` Edge Function returns results, upsert each result into `media_items` with basic fields (title, image, year, source, source_id, media_type). This means even search results populate the catalog.

2. **Detail view → save full data.** The `media-detail` Edge Function already upserts full detail (synopsis, genres, score, details JSON) into `media_items` on every detail fetch. This enriches the catalog entry.

3. **Search checks DB first.** Before hitting the provider, the `search-media` Edge Function queries `media_items` for matching titles. If we have enough cached results (e.g., ≥10 matches), return those. If not, fall through to the provider and upsert new results.

4. **Staleness policy.** A `media_items` row is considered "fresh enough" for list display indefinitely. For detail view, if `updated_at` is older than 30 days, re-fetch from provider and update the row. This keeps scores and episode counts reasonably current without hammering providers.

5. **Periodic resync (future).** A scheduled Edge Function (cron) that re-fetches and updates `media_items` rows that are popular (referenced by many tracked_media/reviews) and stale (updated_at > 30 days). Low priority — implement after core features are solid.

**Implementation order:**

- Step 1 (now): Search result upsert in `search-media` Edge Function
- Step 2 (now): Detail upsert already done
- Step 3 (Phase 8+): DB-first search fallback
- Step 4 (Phase 8+): Staleness-based re-fetch on detail view
- Step 5 (post-launch): Cron resync job

---

## Phase 2: Media Tracking (Library Tab)

> Let users track media progress and build their library with real persistence.

### 2.1 — Track Media Flow

**What changes:**

- `TrackMediaSheet.swift` — on "Track" button tap:
  1. Upsert media to `media_items` if not exists
  2. Insert/update row in `tracked_media` with status, progress, score
  3. Insert activity_feed entry (action_type: "tracked")
  4. Dismiss sheet with success haptic
- `MediaDetailView.swift` — track button checks if already tracked, shows current status
- Support updating existing tracking (change status, update progress, update score)
- Support removing tracking (delete from tracked_media)

### 2.2 — Library View with Real Data

**What changes:**

- `LibraryView.swift` — replace mock `libraryItems` with query to `tracked_media` joined with `media_items`
- Implement all existing filters (status, category) as Supabase query filters
- Implement all existing sort options (status, alphabetical, score, progress, date)
- Search within library (client-side filter on loaded items, or Supabase text search)
- Pull-to-refresh
- Loading and empty states

**Query pattern:**

```swift
let items = try await supabase
    .from("tracked_media")
    .select("*, media_item:media_items(*)")
    .eq("user_id", userId)
    .eq("status", filterStatus) // if filtered
    .order("updated_at", ascending: false)
    .range(from: offset, to: offset + limit)
    .execute()
```

### 2.3 — Continue Tracking Section (Home)

**What changes:**

- `ContinueTrackingSection.swift` — query tracked_media where status = "in_progress", ordered by updated_at
- Show real media images, titles, progress
- Tapping opens MediaDetailView with tracking state
- Quick-update progress inline (increment episode/chapter)

---

## Phase 3: Reviews & Ratings

> Enable users to write, read, and interact with reviews.

### 3.1 — Write a Review

**What to build:**

- Create `ComposeReviewSheet.swift` — form with: rating slider (0-10), title, body, spoiler toggle
- Accessible from MediaDetailView "Write Review" button
- On submit: insert into `reviews` table, insert activity_feed entry (action_type: "reviewed")
- Validate: must have rating, body optional but encouraged

### 3.2 — Reviews on Media Detail

**What changes:**

- `MediaDetailView.swift` Reviews tab — query `reviews` for this media_item_id
- Join with `user_profiles` to show author name, avatar
- Show rating badge, spoiler tag, truncated body
- Tap to open `ReviewDetailView`

### 3.3 — Review Detail with Real Interactions

**What changes:**

- `ReviewDetailView.swift` — load full review from Supabase
- Like/unlike: insert/delete `review_likes`, update `likes_count` via trigger
- Comments: insert into `review_comments`, display nested thread
- Reply to comments (parent_comment_id)
- Navigate to author's profile

### 3.4 — Trending Reviews (Home)

**What changes:**

- `TrendingReviewsSection.swift` — query reviews ordered by likes_count DESC, created_at recent
- Show review cards with media thumbnail, author, rating
- Tap to open ReviewDetailView

---

## Phase 4: User Profiles & Social

> Make profiles real and enable the social graph.

### 4.1 — Full Profile Data

**What changes:**

- `MyProfileView.swift` — load all data from Supabase:
  - Profile info from `user_profiles`
  - Stats from `get_user_stats()` database function
  - Tracked tab: query `tracked_media` for this user
  - Reviews tab: query `reviews` for this user
  - Nooks tab: query `nooks` for this user
  - Communities tab: query `club_members` → `clubs` for this user
- `EditProfileSheet.swift` — save to Supabase, upload avatar to Storage

### 4.2 — Other User Profiles

**What changes:**

- `OtherProfileView.swift` — same data loading as MyProfileView but for another user_id
- Follow/unfollow: insert/delete `user_follows`
- Respect privacy: only show content the viewer is allowed to see

### 4.3 — Follow System

**What to build:**

- Follow/unfollow buttons on OtherProfileView (already exist as UI shells)
- Followers/following count on profiles
- "Following" feed filter on Home (see activity only from followed users)
- Notification on follow (insert into `notifications`)

### 4.4 — Stats View with Real Data

**What changes:**

- `StatsView.swift` — replace mock data with real queries:
  - Total tracked, reviews, nooks, clubs from `get_user_stats()`
  - Category breakdown: GROUP BY media_type on tracked_media
  - Rating distribution: GROUP BY rating on tracked_media
  - Genre breakdown: aggregate genres from tracked media_items
  - Streak: calculate consecutive days with tracking activity

---

## Phase 5: Nooks (Collections)

> Make nooks a real, persistent, shareable feature.

### 5.1 — Create Nook Flow

**What changes:**

- `CreateNookSheet.swift` — on save:
  1. Upload cover image to Supabase Storage (if selected)
  2. Insert into `nooks` table
  3. Insert all media items into `nook_items` with notes and sort_order
  4. Insert activity_feed entry (action_type: "created_nook")
- Media search within CreateNookSheet should use the real MediaAPIService

### 5.2 — Nook Detail View

**What changes:**

- `NookDetailView.swift` — load from Supabase:
  - Nook metadata from `nooks`
  - Items from `nook_items` joined with `media_items`
  - Owner info from `user_profiles`
- Edit nook (if owner): update items, reorder, change privacy
- Delete nook (if owner)

### 5.3 — Popular Nooks (Home)

**What changes:**

- `PopularNooksSection.swift` — query public nooks ordered by some engagement metric (views, items count, or recency)
- Show nook cards with cover, title, item count, owner

---

## Phase 6: Communities / Clubs

> Bring clubs to life with real membership, posts, and discussions.

### 6.1 — Create Club Flow

**What changes:**

- `CreateClubSheet.swift` — on create:
  1. Upload banner/icon to Supabase Storage
  2. Insert into `clubs`
  3. Insert creator into `club_members` with role "owner"
  4. Invite members (if selected) → insert notifications

### 6.2 — Club Discovery & Membership

**What changes:**

- `CommunitiesView.swift` — load clubs from Supabase:
  - "My Clubs": query `club_members` where user_id = me → join `clubs`
  - "Discover": query public `clubs` ordered by member_count DESC
  - Category filter: WHERE category = selected
- Join club: insert into `club_members`, increment member_count
- Leave club: delete from `club_members`, decrement member_count

### 6.3 — Club Detail & Posts

**What changes:**

- `ClubDetailView.swift` — load real data:
  - Club info from `clubs`
  - Members from `club_members` joined with `user_profiles`
  - Posts from `club_posts` joined with `user_profiles`
  - Pinned posts first, then by created_at DESC
- Like post: insert `club_post_likes`, increment likes_count
- `ComposePostView.swift` — insert into `club_posts`

### 6.4 — Post Detail & Comments

**What changes:**

- `PostDetailView.swift` — load real post + comments from Supabase
- Comment on post: insert into `club_post_comments`
- Nested replies via parent_comment_id
- Like/unlike post

---

## Phase 7: Activity Feed & Notifications

> Connect the social experience with real-time updates.

### 7.1 — Home Activity Feed

**What changes:**

- `ActivityFeedSection.swift` — query `activity_feed` for followed users
- Join with `user_profiles` and `media_items` for display
- Types: "X started tracking Y", "X reviewed Y", "X created nook Z", "X joined club Z"
- Pagination with infinite scroll
- Pull-to-refresh

### 7.2 — Notifications

**What changes:**

- `NotificationsView.swift` — query `notifications` for current user
- Group by time period (Today, This Week, Earlier — already in UI)
- Mark as read on view
- Tap to navigate to referenced content (review, post, club, profile)
- Badge count on bell icon (unread notifications count)

### 7.3 — Realtime Updates (Optional Enhancement)

- Subscribe to Supabase Realtime on `notifications` table for push-like experience
- Subscribe to `club_posts` for live club feed updates
- Subscribe to `activity_feed` for live home feed

---

## Phase 8: Settings & Polish

> Complete the remaining settings functionality and polish edge cases.

### 8.1 — Settings Completion

**What changes:**

- `SettingsView.swift`:
  - **Clear Cache**: implement actual cache clearing (URLCache, any local image cache)
  - **Delete Account**: call Supabase auth admin delete or edge function, sign out, navigate to intro
  - **Notification preferences**: add toggle storage in user_profiles (push_notifications_enabled, etc.)
  - **App appearance**: already works (stored in AppStorage)

### 8.2 — Error Handling & Edge Cases

- Network offline states across all views
- Retry mechanisms for failed API calls
- Graceful degradation when Edge Functions are slow
- Rate limit handling (show user-friendly messages)
- Session expiry → redirect to login

### 8.3 — Performance & Caching

- Image caching strategy (AsyncImage with URLCache or a library like Kingfisher/Nuke)
- Prefetch media details when scrolling search results
- Cache recent search results locally
- Cache library data for instant tab switching
- Debounce rapid user actions (double-tap like, etc.)

### 8.4 — Loading States & Skeletons

- Add shimmer/skeleton loading placeholders to:
  - Search results
  - Library items
  - Media detail
  - Club feed
  - Activity feed
  - Notifications
- Match existing design tokens (NookColors, NookRadii)

---

## Phase Dependency Graph

```
Phase 0 (Foundation)
  ├── 0.1 Database Schema ─────────────────┐
  ├── 0.2 Edge Functions ──────┐            │
  ├── 0.3 iOS Service Layer ───┤            │
  └── 0.4 Profile Extension ───┤            │
                                │            │
Phase 1 (Search) ◄─────────────┘            │
  ├── 1.1 Search ──────────────┐            │
  ├── 1.2 Media Detail ────────┤            │
  └── 1.3 Media Item Upsert ──┤            │
                                │            │
Phase 2 (Tracking) ◄───────────┘            │
  ├── 2.1 Track Flow ──────────┐            │
  ├── 2.2 Library View ────────┤            │
  └── 2.3 Continue Tracking ───┤            │
                                │            │
Phase 3 (Reviews) ◄────────────┘            │
  ├── 3.1 Write Review                      │
  ├── 3.2 Reviews on Detail                 │
  ├── 3.3 Review Interactions               │
  └── 3.4 Trending Reviews                  │
                                             │
Phase 4 (Profiles & Social) ◄───────────────┘
  ├── 4.1 Full Profile
  ├── 4.2 Other Profiles
  ├── 4.3 Follow System
  └── 4.4 Stats View

Phase 5 (Nooks) ◄── Phase 1 + Phase 4
  ├── 5.1 Create Nook
  ├── 5.2 Nook Detail
  └── 5.3 Popular Nooks

Phase 6 (Clubs) ◄── Phase 4
  ├── 6.1 Create Club
  ├── 6.2 Discovery & Membership
  ├── 6.3 Club Detail & Posts
  └── 6.4 Post Comments

Phase 7 (Feed & Notifications) ◄── Phase 4 + Phase 6
  ├── 7.1 Activity Feed
  ├── 7.2 Notifications
  └── 7.3 Realtime (optional)

Phase 8 (Polish) ◄── All phases
  ├── 8.1 Settings Completion
  ├── 8.2 Error Handling
  ├── 8.3 Performance & Caching
  └── 8.4 Loading States
```

---

## API Reference Quick Sheet

### TheTVDB (Movies & TV)

- **Base URL**: `https://api4.thetvdb.com/v4`
- **Auth**: API Key → `POST /login` with `{ "apikey": "XXXX" }` → Bearer token (cached ~1 month)
- **Search**: `GET /search?query=X&type=movie` or `&type=series`
- **Detail**: `GET /movies/{id}/extended` or `/series/{id}/extended`
- **Images**: Full URLs returned in `image_url` field
- **Rate limit**: Generous (no documented hard limit)

### Kitsu (Anime & Manga)

- **Base URL**: `https://kitsu.io/api/edge`
- **Auth**: None (public API)
- **Format**: JSON:API (responses wrapped in `data` array with `attributes`)
- **Search**: `GET /anime?filter[text]=X&page[limit]=20&page[offset]=0` or `/manga`
- **Detail**: `GET /anime/{id}` or `/manga/{id}`
- **Images**: `posterImage.large` field in attributes
- **Score**: `averageRating` field (0-100, divide by 10 for normalized 0-10)
- **Rate limit**: No documented limit
- **Pagination**: `page[offset]` / `page[limit]` (max 20 per page)

### Open Library (Books)

- **Base URL**: `https://openlibrary.org`
- **Auth**: None (public API)
- **Search**: `GET /search.json?q=X&page=1&limit=24`
- **Detail**: `GET /works/{id}.json` + `/editions/{id}.json` for page count
- **Images**: `https://covers.openlibrary.org/b/id/{cover_id}-L.jpg`
- **Rate limit**: ~3 req/sec (must include `User-Agent` header)

---

## Files That Will Be Modified (Existing)

| File                            | Phase              | Changes                                                  |
| ------------------------------- | ------------------ | -------------------------------------------------------- |
| `AppRouter.swift`               | 0.4                | Save full_name on Apple sign-in, extend profile creation |
| `SearchView.swift`              | 1.1                | Replace mock data with MediaAPIService calls             |
| `MediaDetailView.swift`         | 1.2, 2.1, 3.2      | Real data loading, tracking integration, reviews         |
| `TrackMediaSheet.swift`         | 1.1, 2.1           | Real search + real tracking persistence                  |
| `LibraryView.swift`             | 2.2                | Replace mock data with Supabase queries                  |
| `ContinueTrackingSection.swift` | 2.3                | Real in-progress items                                   |
| `HomeView.swift`                | 2.3, 3.4, 5.3, 7.1 | Wire up all home sections                                |
| `ActivityFeedSection.swift`     | 7.1                | Real activity feed                                       |
| `TrendingReviewsSection.swift`  | 3.4                | Real trending reviews                                    |
| `PopularNooksSection.swift`     | 5.3                | Real popular nooks                                       |
| `ReviewDetailView.swift`        | 3.3                | Real interactions (likes, comments)                      |
| `MyProfileView.swift`           | 4.1                | Real profile data + stats                                |
| `OtherProfileView.swift`        | 4.2                | Real profile + follow/unfollow                           |
| `StatsView.swift`               | 4.4                | Real statistics                                          |
| `EditProfileSheet.swift`        | 0.4                | Supabase persistence + avatar upload                     |
| `CreateNookSheet.swift`         | 5.1                | Real persistence + media search                          |
| `NookDetailView.swift`          | 5.2                | Real data loading                                        |
| `CommunitiesView.swift`         | 6.2                | Real club data                                           |
| `ClubDetailView.swift`          | 6.3                | Real posts, members, interactions                        |
| `CreateClubSheet.swift`         | 6.1                | Real persistence + image upload                          |
| `ComposePostView.swift`         | 6.3                | Real post creation                                       |
| `PostDetailView.swift`          | 6.4                | Real comments + interactions                             |
| `NotificationsView.swift`       | 7.2                | Real notifications                                       |
| `SettingsView.swift`            | 8.1                | Complete TODO implementations                            |
| `UserProfile.swift`             | 0.4                | Add Codable, Supabase mapping                            |

## Files That Will Be Created (New)

| File                                         | Phase | Purpose                             |
| -------------------------------------------- | ----- | ----------------------------------- |
| `supabase/migrations/XXXX_full_schema.sql`   | 0.1   | All database tables                 |
| `supabase/functions/_shared/providers.ts`    | 0.2   | Provider routing + shared utilities |
| `supabase/functions/_shared/thetvdb-auth.ts` | 0.2   | TheTVDB Bearer token management     |
| `supabase/functions/search-media/index.ts`   | 0.2   | Media search proxy                  |
| `supabase/functions/media-detail/index.ts`   | 0.2   | Media detail proxy                  |
| `Services/APIClient.swift`                   | 0.3   | HTTP client for Edge Functions      |
| `Services/MediaAPIService.swift`             | 0.3   | Media search + detail               |
| `Services/TrackingService.swift`             | 0.3   | Tracking CRUD                       |
| `Services/ReviewService.swift`               | 0.3   | Review CRUD                         |
| `Services/ClubService.swift`                 | 0.3   | Club CRUD                           |
| `Services/NookService.swift`                 | 0.3   | Nook CRUD                           |
| `Services/ProfileService.swift`              | 0.3   | Profile + follows                   |
| `Services/NotificationService.swift`         | 0.3   | Notifications                       |
| `Services/StorageService.swift`              | 0.3   | Image upload/download               |
| `Services/ActivityFeedService.swift`         | 0.3   | Home feed                           |
| `Models/MediaItem.swift`                     | 0.3   | Media item model                    |
| `Models/TrackedMedia.swift`                  | 0.3   | Tracking model                      |
| `Models/Review.swift`                        | 0.3   | Review model                        |
| `Models/Club.swift`                          | 0.3   | Club model                          |
| `Models/ClubPost.swift`                      | 0.3   | Club post model                     |
| `Models/NookModel.swift`                     | 0.3   | Nook model                          |
| `Models/Notification.swift`                  | 0.3   | Notification model                  |
| `Models/ActivityFeedItem.swift`              | 0.3   | Feed item model                     |
| `Views/Reviews/ComposeReviewSheet.swift`     | 3.1   | Review composition form             |

---

## Implementation Notes

### What NOT to change

- **Design tokens** (NookColors, NookFonts, NookTypography, NookRadii) — already complete
- **Auth flow** (IntroView, OTP, Apple, Google) — already production-ready
- **Onboarding** (OnboardingInterestsView) — already production-ready
- **Navigation structure** (MainTabView, tabs, sheets) — already correct
- **iOS 26+ / fallback patterns** — already handled throughout
- **Icon assets** — already comprehensive (80+)
- **Component library** (NookTextField, FlowLayout, etc.) — already built

### Key Risks & Mitigations

1. **API rate limits** → Edge Functions can cache responses in Supabase/Redis, implement debounce
2. **TheTVDB token lifecycle** → Edge Function manages Bearer token refresh server-side
3. **Large query joins** → Use Supabase views or database functions for complex joins
4. **Image loading performance** → Consider adding Kingfisher/Nuke as a dependency for proper caching
5. **Realtime costs** → Start without realtime subscriptions, add selectively where needed
