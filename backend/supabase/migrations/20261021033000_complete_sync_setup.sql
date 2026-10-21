-- =============================================================================
-- AXIS: Complete Supabase Migration for Habit Categories, Prayers & Profiles
-- Run this script in the Supabase SQL Editor (Dashboard -> SQL Editor -> New Query)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Habit Categories Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.habit_categories (
  id          text PRIMARY KEY,
  user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  icon        text NOT NULL DEFAULT 'fitness',
  color       text NOT NULL DEFAULT '#10B981',
  sort_order  integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT habit_categories_user_name_unique UNIQUE (user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_habit_categories_user_id ON public.habit_categories(user_id);
ALTER TABLE public.habit_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "habit_categories_select_policy" ON public.habit_categories;
CREATE POLICY "habit_categories_select_policy" ON public.habit_categories
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habit_categories_insert_policy" ON public.habit_categories;
CREATE POLICY "habit_categories_insert_policy" ON public.habit_categories
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habit_categories_update_policy" ON public.habit_categories;
CREATE POLICY "habit_categories_update_policy" ON public.habit_categories
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habit_categories_delete_policy" ON public.habit_categories;
CREATE POLICY "habit_categories_delete_policy" ON public.habit_categories
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- 2. Dedicated Prayers Table (Fixed exactly 5 daily prayers per user)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.prayers (
  id           text PRIMARY KEY,
  user_id      uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  prayer_code  text NOT NULL,
  name         text NOT NULL,
  icon         text NOT NULL,
  time         text NOT NULL,
  sort_order   integer NOT NULL DEFAULT 1,
  is_done      boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT prayers_user_code_unique UNIQUE (user_id, prayer_code)
);

CREATE INDEX IF NOT EXISTS idx_prayers_user_id ON public.prayers(user_id);
CREATE INDEX IF NOT EXISTS idx_prayers_user_sort ON public.prayers(user_id, sort_order);
ALTER TABLE public.prayers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "prayers_select_policy" ON public.prayers;
CREATE POLICY "prayers_select_policy" ON public.prayers
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "prayers_insert_policy" ON public.prayers;
CREATE POLICY "prayers_insert_policy" ON public.prayers
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "prayers_update_policy" ON public.prayers;
CREATE POLICY "prayers_update_policy" ON public.prayers
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "prayers_delete_policy" ON public.prayers;
CREATE POLICY "prayers_delete_policy" ON public.prayers
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- 3. User Profiles & Stats Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id            text PRIMARY KEY,
  user_id       uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name          text NOT NULL DEFAULT 'Player One',
  title         text NOT NULL DEFAULT 'Disciplined Novice',
  avatar_color  text NOT NULL DEFAULT '#6366F1',
  total_xp      integer NOT NULL DEFAULT 0,
  level         integer NOT NULL DEFAULT 1,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_profiles_user_id_unique UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON public.user_profiles(user_id);
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_profiles_select_policy" ON public.user_profiles;
CREATE POLICY "user_profiles_select_policy" ON public.user_profiles
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_profiles_insert_policy" ON public.user_profiles;
CREATE POLICY "user_profiles_insert_policy" ON public.user_profiles
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_profiles_update_policy" ON public.user_profiles;
CREATE POLICY "user_profiles_update_policy" ON public.user_profiles
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_profiles_delete_policy" ON public.user_profiles;
CREATE POLICY "user_profiles_delete_policy" ON public.user_profiles
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- 4. Permissions & Role Grants
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

GRANT ALL ON TABLE public.habit_categories TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.prayers TO authenticated, service_role, postgres;
GRANT ALL ON TABLE public.user_profiles TO authenticated, service_role, postgres;

GRANT SELECT ON TABLE public.habit_categories TO anon;
GRANT SELECT ON TABLE public.prayers TO anon;
GRANT SELECT ON TABLE public.user_profiles TO anon;

-- Grant permissions to PowerSync replication roles if present
DO $$
DECLARE
  r RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_role') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO powersync_role';
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync_role';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powersync_role';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO powersync';
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powersync';
  END IF;

  FOR r IN (SELECT rolname FROM pg_roles WHERE rolreplication = true) LOOP
    BEGIN
      EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', r.rolname);
      EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %I', r.rolname);
      EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO %I', r.rolname);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 5. Add to PowerSync Logical Replication Publication
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.habit_categories;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.prayers;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.user_profiles;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync_axis') THEN
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.habit_categories;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.prayers;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.user_profiles;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;
