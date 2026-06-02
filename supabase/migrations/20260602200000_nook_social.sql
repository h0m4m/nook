-- =============================================================================
-- Nook social layer: likes + threaded comments + comment likes
-- Mirrors the review_likes / review_comments / review_comment_likes pattern.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. nooks.likes_count
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.nooks
  ADD COLUMN IF NOT EXISTS likes_count int NOT NULL DEFAULT 0;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. nook_likes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.nook_likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nook_id uuid NOT NULL REFERENCES public.nooks(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, nook_id)
);

ALTER TABLE public.nook_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read nook_likes"
  ON public.nook_likes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users insert own nook_likes"
  ON public.nook_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete own nook_likes"
  ON public.nook_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. nook_comments
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.nook_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nook_id uuid NOT NULL REFERENCES public.nooks(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_comment_id uuid REFERENCES public.nook_comments(id) ON DELETE CASCADE,
  body text NOT NULL,
  likes_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Second FK to user_profiles enables PostgREST embedding of the author profile
-- (mirrors review_comments_user_id_user_profiles_fkey).
ALTER TABLE public.nook_comments
  ADD CONSTRAINT nook_comments_user_id_user_profiles_fkey
  FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;

ALTER TABLE public.nook_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read nook_comments"
  ON public.nook_comments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users insert own nook_comments"
  ON public.nook_comments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own nook_comments"
  ON public.nook_comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own nook_comments"
  ON public.nook_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE TRIGGER on_nook_comments_updated
  BEFORE UPDATE ON public.nook_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. nook_comment_likes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.nook_comment_likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment_id uuid NOT NULL REFERENCES public.nook_comments(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, comment_id)
);

ALTER TABLE public.nook_comment_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read nook_comment_likes"
  ON public.nook_comment_likes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users insert own nook_comment_likes"
  ON public.nook_comment_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete own nook_comment_likes"
  ON public.nook_comment_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Triggers — nook likes count
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_nook_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.nooks SET likes_count = likes_count + 1 WHERE id = NEW.nook_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_nook_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.nooks SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.nook_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_nook_liked
  AFTER INSERT ON public.nook_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_nook_likes();

CREATE TRIGGER on_nook_unliked
  AFTER DELETE ON public.nook_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.decrement_nook_likes();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Triggers — nook comment likes count
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_nook_comment_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.nook_comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_nook_comment_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.nook_comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.comment_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_nook_comment_liked
  AFTER INSERT ON public.nook_comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_nook_comment_likes();

CREATE TRIGGER on_nook_comment_unliked
  AFTER DELETE ON public.nook_comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.decrement_nook_comment_likes();
