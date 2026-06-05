-- ─────────────────────────────────────────────────────────────────────────────
-- Recent tracked-media activity for any user's profile ("Recently Active").
--
-- tracked_media RLS is owner-only (a user can only read their own rows), so the
-- "Recently Active" list on another user's profile cannot be fetched with a
-- direct table query. This SECURITY DEFINER function exposes a bounded, read-only
-- projection of any user's most-recent tracked media — the same pattern used by
-- get_user_stats.
--
-- score is cast to double precision so PostgREST serializes it as a JSON number
-- (numeric serializes as a JSON string, which breaks Swift Double? decoding).
-- ─────────────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.get_user_recent_activity(uuid, int);

CREATE FUNCTION public.get_user_recent_activity(target_user_id uuid, item_limit int DEFAULT 5)
RETURNS TABLE (
  tracking_id uuid,
  media_item_id uuid,
  title text,
  image_url text,
  media_type text,
  status text,
  score double precision,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT tm.id, tm.media_item_id, mi.title, mi.image_url, mi.media_type, tm.status,
         tm.score::double precision, tm.updated_at
  FROM public.tracked_media tm
  JOIN public.media_items mi ON mi.id = tm.media_item_id
  WHERE tm.user_id = target_user_id
  ORDER BY tm.updated_at DESC
  LIMIT GREATEST(item_limit, 0);
$$;

GRANT EXECUTE ON FUNCTION public.get_user_recent_activity(uuid, int) TO authenticated;
