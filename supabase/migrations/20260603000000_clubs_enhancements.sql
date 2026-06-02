-- =============================================================================
-- Clubs enhancements
--  - club_posts.comments_count + triggers
--  - club_post_comments.likes_count + club_post_comment_likes + triggers
--  - club_members.notifications_muted (mute preference)
--  - club_post_images (post attachments)
--  - polls: club_post_polls / club_poll_options / club_poll_votes + triggers
--  - moderation: reports / user_blocks
-- Mirrors the existing club_post_likes / nook_social like+comment patterns.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Denormalised counts + mute preference
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.club_posts
  ADD COLUMN IF NOT EXISTS comments_count int NOT NULL DEFAULT 0;

ALTER TABLE public.club_post_comments
  ADD COLUMN IF NOT EXISTS likes_count int NOT NULL DEFAULT 0;

ALTER TABLE public.club_members
  ADD COLUMN IF NOT EXISTS notifications_muted boolean NOT NULL DEFAULT false;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. club_post_comment_likes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.club_post_comment_likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment_id uuid NOT NULL REFERENCES public.club_post_comments(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, comment_id)
);

ALTER TABLE public.club_post_comment_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read club_post_comment_likes"
  ON public.club_post_comment_likes FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Insert own club_post_comment_likes"
  ON public.club_post_comment_likes FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Delete own club_post_comment_likes"
  ON public.club_post_comment_likes FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. club_post_images
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.club_post_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.club_posts(id) ON DELETE CASCADE,
  url text NOT NULL,
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS club_post_images_post_id_idx
  ON public.club_post_images (post_id);

ALTER TABLE public.club_post_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read club_post_images"
  ON public.club_post_images FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.club_posts cp
      JOIN public.clubs c ON c.id = cp.club_id
      WHERE cp.id = club_post_images.post_id
      AND (
        c.privacy = 'public'
        OR EXISTS (
          SELECT 1 FROM public.club_members cm
          WHERE cm.club_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "Insert own club_post_images"
  ON public.club_post_images FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.club_posts cp
      WHERE cp.id = club_post_images.post_id AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "Delete own club_post_images"
  ON public.club_post_images FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.club_posts cp
      WHERE cp.id = club_post_images.post_id AND cp.user_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Polls
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.club_post_polls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL UNIQUE REFERENCES public.club_posts(id) ON DELETE CASCADE,
  total_votes int NOT NULL DEFAULT 0,
  closes_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.club_poll_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL REFERENCES public.club_post_polls(id) ON DELETE CASCADE,
  text text NOT NULL,
  position int NOT NULL DEFAULT 0,
  votes_count int NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS club_poll_options_poll_id_idx
  ON public.club_poll_options (poll_id);

CREATE TABLE IF NOT EXISTS public.club_poll_votes (
  poll_id uuid NOT NULL REFERENCES public.club_post_polls(id) ON DELETE CASCADE,
  option_id uuid NOT NULL REFERENCES public.club_poll_options(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (poll_id, user_id)
);

ALTER TABLE public.club_post_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_poll_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read club_post_polls"
  ON public.club_post_polls FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read club_poll_options"
  ON public.club_poll_options FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read club_poll_votes"
  ON public.club_poll_votes FOR SELECT TO authenticated USING (true);

CREATE POLICY "Insert poll for own post"
  ON public.club_post_polls FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.club_posts cp
      WHERE cp.id = club_post_polls.post_id AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "Insert options for own poll"
  ON public.club_poll_options FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.club_post_polls pp
      JOIN public.club_posts cp ON cp.id = pp.post_id
      WHERE pp.id = club_poll_options.poll_id AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "Insert own vote"
  ON public.club_poll_votes FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Delete own vote"
  ON public.club_poll_votes FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Moderation: reports + user_blocks
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type text NOT NULL,        -- 'club' | 'post' | 'comment' | 'user'
  target_id uuid NOT NULL,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Insert own reports"
  ON public.reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Read own reports"
  ON public.reports FOR SELECT TO authenticated
  USING (auth.uid() = reporter_id);

CREATE TABLE IF NOT EXISTS public.user_blocks (
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read own blocks"
  ON public.user_blocks FOR SELECT TO authenticated
  USING (auth.uid() = blocker_id);
CREATE POLICY "Insert own blocks"
  ON public.user_blocks FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Delete own blocks"
  ON public.user_blocks FOR DELETE TO authenticated
  USING (auth.uid() = blocker_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Triggers — club_posts.comments_count
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_club_post_comments()
RETURNS trigger AS $$
BEGIN
  UPDATE public.club_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_club_post_comments()
RETURNS trigger AS $$
BEGIN
  UPDATE public.club_posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_club_post_comment_added ON public.club_post_comments;
CREATE TRIGGER on_club_post_comment_added
  AFTER INSERT ON public.club_post_comments
  FOR EACH ROW EXECUTE FUNCTION public.increment_club_post_comments();

DROP TRIGGER IF EXISTS on_club_post_comment_removed ON public.club_post_comments;
CREATE TRIGGER on_club_post_comment_removed
  AFTER DELETE ON public.club_post_comments
  FOR EACH ROW EXECUTE FUNCTION public.decrement_club_post_comments();

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Triggers — club_post_comments.likes_count
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_club_comment_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.club_post_comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_club_comment_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.club_post_comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.comment_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_club_comment_liked ON public.club_post_comment_likes;
CREATE TRIGGER on_club_comment_liked
  AFTER INSERT ON public.club_post_comment_likes
  FOR EACH ROW EXECUTE FUNCTION public.increment_club_comment_likes();

DROP TRIGGER IF EXISTS on_club_comment_unliked ON public.club_post_comment_likes;
CREATE TRIGGER on_club_comment_unliked
  AFTER DELETE ON public.club_post_comment_likes
  FOR EACH ROW EXECUTE FUNCTION public.decrement_club_comment_likes();

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Triggers — poll vote counts
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_club_poll_vote()
RETURNS trigger AS $$
BEGIN
  UPDATE public.club_poll_options SET votes_count = votes_count + 1 WHERE id = NEW.option_id;
  UPDATE public.club_post_polls SET total_votes = total_votes + 1 WHERE id = NEW.poll_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_club_poll_vote()
RETURNS trigger AS $$
BEGIN
  UPDATE public.club_poll_options SET votes_count = GREATEST(votes_count - 1, 0) WHERE id = OLD.option_id;
  UPDATE public.club_post_polls SET total_votes = GREATEST(total_votes - 1, 0) WHERE id = OLD.poll_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_club_poll_voted ON public.club_poll_votes;
CREATE TRIGGER on_club_poll_voted
  AFTER INSERT ON public.club_poll_votes
  FOR EACH ROW EXECUTE FUNCTION public.increment_club_poll_vote();

DROP TRIGGER IF EXISTS on_club_poll_unvoted ON public.club_poll_votes;
CREATE TRIGGER on_club_poll_unvoted
  AFTER DELETE ON public.club_poll_votes
  FOR EACH ROW EXECUTE FUNCTION public.decrement_club_poll_vote();

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. Backfill existing comment counts
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE public.club_posts cp
  SET comments_count = (
    SELECT count(*) FROM public.club_post_comments c WHERE c.post_id = cp.id
  );
