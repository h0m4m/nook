-- Speed up the search-media Edge Function's DB-first search (ilike '%query%' +
-- media_type filter + score ordering) and make it scale as the media_items
-- catalog grows. Applied to nook-staging (wzakmmuxsosfybqufdsn) via MCP.

create extension if not exists pg_trgm;

-- Trigram GIN index makes leading-wildcard ILIKE on title index-accelerated.
create index if not exists media_items_title_trgm_idx
  on public.media_items using gin (lower(title) gin_trgm_ops);

-- Supports the media_type filter + score-desc ordering used by searchCachedMedia().
create index if not exists media_items_type_score_idx
  on public.media_items (media_type, score desc nulls last);
