-- =============================================================================
-- AXIS: Note Categories Table & Multi-Device Sync Migration
-- 1. Creates public.note_categories with multi-user RLS & PowerSync replication
-- 2. Configures grants for Supabase API roles and PowerSync replication
-- 3. Adds public.note_categories to PowerSync publication for cross-device sync
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Note Categories Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.note_categories (
  id          text PRIMARY KEY,
  user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  icon        text NOT NULL DEFAULT 'article',
  color       text NOT NULL DEFAULT '#38BDF8',
  sort_order  integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT note_categories_user_name_unique UNIQUE (user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_note_categories_user_id ON public.note_categories(user_id);

ALTER TABLE public.note_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "note_categories_select_policy" ON public.note_categories;
CREATE POLICY "note_categories_select_policy" ON public.note_categories
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "note_categories_insert_policy" ON public.note_categories;
CREATE POLICY "note_categories_insert_policy" ON public.note_categories
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "note_categories_update_policy" ON public.note_categories;
CREATE POLICY "note_categories_update_policy" ON public.note_categories
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "note_categories_delete_policy" ON public.note_categories;
CREATE POLICY "note_categories_delete_policy" ON public.note_categories
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- 2. Role Permissions & Default Privileges
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

GRANT ALL ON TABLE public.note_categories TO authenticated, service_role, postgres;
GRANT SELECT ON TABLE public.note_categories TO anon;

-- Grant permissions to PowerSync replication roles if present
DO $$
DECLARE
  r RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_role') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO powersync_role';
    EXECUTE 'GRANT SELECT ON TABLE public.note_categories TO powersync_role';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO powersync';
    EXECUTE 'GRANT SELECT ON TABLE public.note_categories TO powersync';
  END IF;

  FOR r IN (SELECT rolname FROM pg_roles WHERE rolreplication = true) LOOP
    BEGIN
      EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', r.rolname);
      EXECUTE format('GRANT SELECT ON TABLE public.note_categories TO %I', r.rolname);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Add to PowerSync Logical Replication Publications
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.note_categories;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync_axis') THEN
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.note_categories;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;
