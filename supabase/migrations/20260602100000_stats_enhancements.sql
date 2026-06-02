-- Stats enhancements: hours spent + review likes received
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Helper: parse runtime string ("2h 15m", "45m", "23 min") → integer minutes
-- Uses runtime_minutes from details JSONB when available, falls back to string parsing.
CREATE OR REPLACE FUNCTION public.parse_runtime_minutes(details jsonb)
RETURNS int AS $$
DECLARE
  raw_minutes int;
  runtime_str text;
  h int;
  m int;
BEGIN
  -- Prefer the numeric field stored by newer provider code
  raw_minutes := (details->>'runtime_minutes')::int;
  IF raw_minutes IS NOT NULL AND raw_minutes > 0 THEN
    RETURN raw_minutes;
  END IF;

  -- Fallback: parse the human-readable runtime string
  runtime_str := details->>'runtime';
  IF runtime_str IS NULL OR runtime_str = '' THEN
    RETURN NULL;
  END IF;

  -- Format "Xh Ym"
  IF runtime_str ~ '^\d+h\s*\d+m$' THEN
    h := (regexp_match(runtime_str, '^(\d+)h'))[1]::int;
    m := (regexp_match(runtime_str, '(\d+)m$'))[1]::int;
    RETURN h * 60 + m;
  END IF;

  -- Format "Xm" or "X min"
  IF runtime_str ~ '^\d+\s*(m|min)$' THEN
    m := (regexp_match(runtime_str, '^(\d+)'))[1]::int;
    RETURN m;
  END IF;

  -- Format "Xh" (edge case, no minutes)
  IF runtime_str ~ '^\d+h$' THEN
    h := (regexp_match(runtime_str, '^(\d+)'))[1]::int;
    RETURN h * 60;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. RPC: compute total minutes spent on tracked media for a user
-- Covers: movies (runtime if completed), tv/anime (per-episode runtime × progress)
-- Books/manga/games are excluded — no reliable time-per-unit data.
CREATE OR REPLACE FUNCTION public.get_hours_spent(target_user_id uuid)
RETURNS json AS $$
DECLARE
  total_minutes bigint;
BEGIN
  SELECT COALESCE(SUM(
    CASE
      -- Movies: full runtime if progress >= 1 (i.e. watched)
      WHEN mi.media_type = 'movie' AND tm.progress >= 1 THEN
        public.parse_runtime_minutes(mi.details)
      -- TV / Anime: per-episode runtime × episodes watched
      WHEN mi.media_type IN ('tv', 'anime') AND tm.progress > 0 THEN
        public.parse_runtime_minutes(mi.details) * tm.progress
      ELSE 0
    END
  ), 0)
  INTO total_minutes
  FROM public.tracked_media tm
  JOIN public.media_items mi ON mi.id = tm.media_item_id
  WHERE tm.user_id = target_user_id;

  RETURN json_build_object('total_minutes', total_minutes);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update get_user_stats to include review_likes_received
CREATE OR REPLACE FUNCTION public.get_user_stats(target_user_id uuid)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'tracked_count', (SELECT count(*) FROM public.tracked_media WHERE user_id = target_user_id),
    'review_count', (SELECT count(*) FROM public.reviews WHERE user_id = target_user_id),
    'nook_count', (SELECT count(*) FROM public.nooks WHERE user_id = target_user_id),
    'club_count', (SELECT count(*) FROM public.club_members WHERE user_id = target_user_id),
    'review_likes_received', (SELECT COALESCE(SUM(likes_count), 0) FROM public.reviews WHERE user_id = target_user_id)
  ) INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
