-- =============================================================================
-- Full Schema Migration for Nook
-- Extends user_profiles + creates all tables, RLS, triggers, functions, storage
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ALTER user_profiles — add new columns
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS username text UNIQUE,
  ADD COLUMN IF NOT EXISTS bio text,
  ADD COLUMN IF NOT EXISTS avatar_url text;

ALTER TABLE public.user_profiles
  ADD CONSTRAINT user_profiles_username_format
  CHECK (username ~ '^[a-zA-Z0-9_]{3,20}$');

-- Allow all authenticated users to read any profile (for viewing other users)
CREATE POLICY "Authenticated users can read any profile"
  ON public.user_profiles FOR SELECT
  TO authenticated
  USING (true);

-- Drop the old restrictive select policy
DROP POLICY IF EXISTS "Users can read own profile" ON public.user_profiles;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. user_follows
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.user_follows (
  follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CONSTRAINT no_self_follow CHECK (follower_id != following_id)
);

ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can read follows"
  ON public.user_follows FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert own follows"
  ON public.user_follows FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can delete own follows"
  ON public.user_follows FOR DELETE
  TO authenticated
  USING (auth.uid() = follower_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. media_items
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.media_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL,
  source_id text NOT NULL,
  media_type text NOT NULL,
  title text NOT NULL,
  image_url text,
  year text,
  genres text[],
  score decimal,
  score_count int,
  synopsis text,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source, source_id)
);

ALTER TABLE public.media_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read media_items"
  ON public.media_items FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert media_items"
  ON public.media_items FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Service role can update media_items"
  ON public.media_items FOR UPDATE
  TO service_role
  USING (true);

CREATE TRIGGER on_media_items_updated
  BEFORE UPDATE ON public.media_items
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. tracked_media
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.tracked_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  media_item_id uuid NOT NULL REFERENCES public.media_items(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'planned',
  progress int NOT NULL DEFAULT 0,
  score decimal,
  started_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, media_item_id)
);

ALTER TABLE public.tracked_media ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own tracked_media"
  ON public.tracked_media FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own tracked_media"
  ON public.tracked_media FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own tracked_media"
  ON public.tracked_media FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own tracked_media"
  ON public.tracked_media FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE TRIGGER on_tracked_media_updated
  BEFORE UPDATE ON public.tracked_media
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. reviews
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  media_item_id uuid NOT NULL REFERENCES public.media_items(id) ON DELETE CASCADE,
  title text,
  body text NOT NULL,
  rating decimal NOT NULL,
  is_spoiler boolean NOT NULL DEFAULT false,
  likes_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_reviews_media_created ON public.reviews (media_item_id, created_at);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read reviews"
  ON public.reviews FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users insert own reviews"
  ON public.reviews FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own reviews"
  ON public.reviews FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own reviews"
  ON public.reviews FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE TRIGGER on_reviews_updated
  BEFORE UPDATE ON public.reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. review_likes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.review_likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  review_id uuid NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, review_id)
);

ALTER TABLE public.review_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read review_likes"
  ON public.review_likes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users insert own review_likes"
  ON public.review_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete own review_likes"
  ON public.review_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. review_comments
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.review_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_comment_id uuid REFERENCES public.review_comments(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.review_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read review_comments"
  ON public.review_comments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users insert own review_comments"
  ON public.review_comments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own review_comments"
  ON public.review_comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own review_comments"
  ON public.review_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE TRIGGER on_review_comments_updated
  BEFORE UPDATE ON public.review_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. clubs
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.clubs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  category text NOT NULL,
  privacy text NOT NULL DEFAULT 'public',
  banner_url text,
  icon_url text,
  member_count int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;

-- NOTE: clubs SELECT policy is deferred until after club_members table exists (see below)

CREATE POLICY "Users insert own clubs"
  ON public.clubs FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners update own clubs"
  ON public.clubs FOR UPDATE
  TO authenticated
  USING (auth.uid() = owner_id);

CREATE POLICY "Owners delete own clubs"
  ON public.clubs FOR DELETE
  TO authenticated
  USING (auth.uid() = owner_id);

CREATE TRIGGER on_clubs_updated
  BEFORE UPDATE ON public.clubs
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. club_members
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.club_members (
  club_id uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (club_id, user_id)
);

ALTER TABLE public.club_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Club members readable by same-club members"
  ON public.club_members FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.club_members my_membership
      WHERE my_membership.club_id = club_members.club_id
        AND my_membership.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.clubs c
      WHERE c.id = club_members.club_id AND c.privacy = 'public'
    )
  );

CREATE POLICY "Users can join clubs"
  ON public.club_members FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave clubs"
  ON public.club_members FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Deferred clubs SELECT policy (club_members now exists)
CREATE POLICY "Read public clubs"
  ON public.clubs FOR SELECT
  TO authenticated
  USING (
    privacy = 'public'
    OR owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.club_members cm
      WHERE cm.club_id = clubs.id AND cm.user_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. club_posts
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.club_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL,
  is_pinned boolean NOT NULL DEFAULT false,
  likes_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.club_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Club posts readable by members or public"
  ON public.club_posts FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.clubs c
      WHERE c.id = club_posts.club_id
      AND (
        c.privacy = 'public'
        OR EXISTS (
          SELECT 1 FROM public.club_members cm
          WHERE cm.club_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "Users insert own club_posts"
  ON public.club_posts FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own club_posts"
  ON public.club_posts FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own club_posts"
  ON public.club_posts FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE TRIGGER on_club_posts_updated
  BEFORE UPDATE ON public.club_posts
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. club_post_likes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.club_post_likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id uuid NOT NULL REFERENCES public.club_posts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

ALTER TABLE public.club_post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Club post likes readable by members"
  ON public.club_post_likes FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.club_posts cp
      JOIN public.clubs c ON c.id = cp.club_id
      WHERE cp.id = club_post_likes.post_id
      AND (
        c.privacy = 'public'
        OR EXISTS (
          SELECT 1 FROM public.club_members cm
          WHERE cm.club_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "Users insert own club_post_likes"
  ON public.club_post_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete own club_post_likes"
  ON public.club_post_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. club_post_comments
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.club_post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.club_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_comment_id uuid REFERENCES public.club_post_comments(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.club_post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Club post comments readable by members"
  ON public.club_post_comments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.club_posts cp
      JOIN public.clubs c ON c.id = cp.club_id
      WHERE cp.id = club_post_comments.post_id
      AND (
        c.privacy = 'public'
        OR EXISTS (
          SELECT 1 FROM public.club_members cm
          WHERE cm.club_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "Users insert own club_post_comments"
  ON public.club_post_comments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own club_post_comments"
  ON public.club_post_comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own club_post_comments"
  ON public.club_post_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE TRIGGER on_club_post_comments_updated
  BEFORE UPDATE ON public.club_post_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. nooks
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.nooks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  cover_url text,
  privacy text NOT NULL DEFAULT 'public',
  layout text NOT NULL DEFAULT 'grid',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.nooks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Nook visibility"
  ON public.nooks FOR SELECT
  TO authenticated
  USING (
    privacy = 'public'
    OR user_id = auth.uid()
    OR (privacy = 'friends_only' AND EXISTS (
      SELECT 1 FROM public.user_follows
      WHERE follower_id = auth.uid() AND following_id = nooks.user_id
    ))
  );

CREATE POLICY "Users insert own nooks"
  ON public.nooks FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own nooks"
  ON public.nooks FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users delete own nooks"
  ON public.nooks FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE TRIGGER on_nooks_updated
  BEFORE UPDATE ON public.nooks
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. nook_items
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.nook_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nook_id uuid NOT NULL REFERENCES public.nooks(id) ON DELETE CASCADE,
  media_item_id uuid NOT NULL REFERENCES public.media_items(id) ON DELETE CASCADE,
  note text,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.nook_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Nook items visibility follows parent nook"
  ON public.nook_items FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.nooks n
      WHERE n.id = nook_items.nook_id
      AND (
        n.privacy = 'public'
        OR n.user_id = auth.uid()
        OR (n.privacy = 'friends_only' AND EXISTS (
          SELECT 1 FROM public.user_follows
          WHERE follower_id = auth.uid() AND following_id = n.user_id
        ))
      )
    )
  );

CREATE POLICY "Users insert items to own nooks"
  ON public.nook_items FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.nooks n
      WHERE n.id = nook_items.nook_id AND n.user_id = auth.uid()
    )
  );

CREATE POLICY "Users update items in own nooks"
  ON public.nook_items FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.nooks n
      WHERE n.id = nook_items.nook_id AND n.user_id = auth.uid()
    )
  );

CREATE POLICY "Users delete items from own nooks"
  ON public.nook_items FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.nooks n
      WHERE n.id = nook_items.nook_id AND n.user_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. notifications
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL,
  reference_id uuid,
  reference_type text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users update own notifications"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Allow authenticated users to insert notifications (for triggering notifications on actions)
CREATE POLICY "Authenticated users can insert notifications"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = actor_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. activity_feed
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.activity_feed (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  media_item_id uuid REFERENCES public.media_items(id) ON DELETE SET NULL,
  reference_id uuid,
  reference_type text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read activity_feed"
  ON public.activity_feed FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users insert own activity_feed"
  ON public.activity_feed FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. Triggers — member count
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_member_count()
RETURNS trigger AS $$
BEGIN
  UPDATE public.clubs SET member_count = member_count + 1 WHERE id = NEW.club_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_member_count()
RETURNS trigger AS $$
BEGIN
  UPDATE public.clubs SET member_count = GREATEST(member_count - 1, 0) WHERE id = OLD.club_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_club_member_added
  AFTER INSERT ON public.club_members
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_member_count();

CREATE TRIGGER on_club_member_removed
  AFTER DELETE ON public.club_members
  FOR EACH ROW
  EXECUTE FUNCTION public.decrement_member_count();

-- ─────────────────────────────────────────────────────────────────────────────
-- 18. Triggers — review likes count
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_review_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.reviews SET likes_count = likes_count + 1 WHERE id = NEW.review_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_review_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.reviews SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.review_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_review_liked
  AFTER INSERT ON public.review_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_review_likes();

CREATE TRIGGER on_review_unliked
  AFTER DELETE ON public.review_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.decrement_review_likes();

-- ─────────────────────────────────────────────────────────────────────────────
-- 19. Triggers — post likes count
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_post_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.club_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_post_likes()
RETURNS trigger AS $$
BEGIN
  UPDATE public.club_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_post_liked
  AFTER INSERT ON public.club_post_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_post_likes();

CREATE TRIGGER on_post_unliked
  AFTER DELETE ON public.club_post_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.decrement_post_likes();

-- ─────────────────────────────────────────────────────────────────────────────
-- 20. Database function — get_user_stats
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_stats(target_user_id uuid)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'tracked_count', (SELECT count(*) FROM public.tracked_media WHERE user_id = target_user_id),
    'review_count', (SELECT count(*) FROM public.reviews WHERE user_id = target_user_id),
    'nook_count', (SELECT count(*) FROM public.nooks WHERE user_id = target_user_id),
    'club_count', (SELECT count(*) FROM public.club_members WHERE user_id = target_user_id)
  ) INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- 21. Storage buckets
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('avatars', 'avatars', true),
  ('nook-covers', 'nook-covers', true),
  ('club-assets', 'club-assets', true)
ON CONFLICT (id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 22. Storage policies — avatars
-- ─────────────────────────────────────────────────────────────────────────────

CREATE POLICY "Anyone can read avatars"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

CREATE POLICY "Users upload own avatars"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users update own avatars"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users delete own avatars"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 23. Storage policies — nook-covers
-- ─────────────────────────────────────────────────────────────────────────────

CREATE POLICY "Anyone can read nook-covers"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'nook-covers');

CREATE POLICY "Users upload own nook-covers"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'nook-covers'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users update own nook-covers"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'nook-covers'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users delete own nook-covers"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'nook-covers'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 24. Storage policies — club-assets
-- ─────────────────────────────────────────────────────────────────────────────

CREATE POLICY "Anyone can read club-assets"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'club-assets');

CREATE POLICY "Users upload own club-assets"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'club-assets'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users update own club-assets"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'club-assets'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users delete own club-assets"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'club-assets'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
