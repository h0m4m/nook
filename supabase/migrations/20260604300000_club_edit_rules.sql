-- =============================================================================
-- Club editing: name is immutable; other details editable once every 7 days.
-- Owner and managers may edit.
-- =============================================================================

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS details_updated_at timestamptz;

CREATE OR REPLACE FUNCTION public.enforce_club_edit_rules()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE details_changed boolean;
BEGIN
  IF NEW.name IS DISTINCT FROM OLD.name THEN
    RAISE EXCEPTION 'A club name cannot be changed.';
  END IF;

  details_changed :=
       NEW.description IS DISTINCT FROM OLD.description
    OR NEW.banner_url  IS DISTINCT FROM OLD.banner_url
    OR NEW.icon_url    IS DISTINCT FROM OLD.icon_url
    OR NEW.theme_color IS DISTINCT FROM OLD.theme_color
    OR NEW.category    IS DISTINCT FROM OLD.category
    OR NEW.privacy     IS DISTINCT FROM OLD.privacy;

  IF details_changed THEN
    IF OLD.details_updated_at IS NOT NULL AND now() - OLD.details_updated_at < interval '7 days' THEN
      RAISE EXCEPTION 'Club details can only be edited once every 7 days.';
    END IF;
    NEW.details_updated_at := now();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_club_edit ON public.clubs;
CREATE TRIGGER enforce_club_edit BEFORE UPDATE ON public.clubs
  FOR EACH ROW EXECUTE FUNCTION public.enforce_club_edit_rules();

-- Owner + managers may edit the club (was owner-only).
DROP POLICY IF EXISTS "Owners update own clubs" ON public.clubs;
DROP POLICY IF EXISTS "Admins update club" ON public.clubs;
CREATE POLICY "Admins update club" ON public.clubs FOR UPDATE TO authenticated
  USING (public.is_club_admin(id, auth.uid()));
