-- =============================================================================
-- Club post media attachments + richer mentions
-- =============================================================================

-- 1. club_post_media — specific media items (movies/shows/anime…) attached to a post.
CREATE TABLE IF NOT EXISTS public.club_post_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.club_posts(id) ON DELETE CASCADE,
  media_item_id uuid NOT NULL REFERENCES public.media_items(id) ON DELETE CASCADE,
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS club_post_media_post_id_idx ON public.club_post_media (post_id);

ALTER TABLE public.club_post_media ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read club_post_media"
  ON public.club_post_media FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.club_posts cp
      JOIN public.clubs c ON c.id = cp.club_id
      WHERE cp.id = club_post_media.post_id
      AND (c.privacy = 'public' OR public.is_club_member(c.id, auth.uid()))
    )
  );

CREATE POLICY "Insert own club_post_media"
  ON public.club_post_media FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.club_posts cp WHERE cp.id = club_post_media.post_id AND cp.user_id = auth.uid())
  );

CREATE POLICY "Delete own club_post_media"
  ON public.club_post_media FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.club_posts cp WHERE cp.id = club_post_media.post_id AND cp.user_id = auth.uid())
  );

-- 2. Mentions: posts in a club that involve me —
--    (a) a post whose body @mentions my username,
--    (b) a post I authored that someone else commented on,
--    (c) a post containing my comment that someone else replied to.
CREATE OR REPLACE FUNCTION public.get_club_mention_post_ids(p_club_id uuid)
RETURNS TABLE(post_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH me AS (SELECT auth.uid() AS uid)
  SELECT p.id
    FROM public.club_posts p
    CROSS JOIN me
    JOIN public.user_profiles up ON up.id = me.uid
   WHERE p.club_id = p_club_id
     AND up.username IS NOT NULL
     AND p.body ILIKE '%@' || up.username || '%'
  UNION
  SELECT c.post_id
    FROM public.club_post_comments c
    JOIN public.club_posts p ON p.id = c.post_id
    CROSS JOIN me
   WHERE p.club_id = p_club_id AND p.user_id = me.uid AND c.user_id <> me.uid
  UNION
  SELECT c.post_id
    FROM public.club_post_comments c
    JOIN public.club_post_comments parent ON parent.id = c.parent_comment_id
    JOIN public.club_posts p ON p.id = c.post_id
    CROSS JOIN me
   WHERE p.club_id = p_club_id AND parent.user_id = me.uid AND c.user_id <> me.uid;
$$;
