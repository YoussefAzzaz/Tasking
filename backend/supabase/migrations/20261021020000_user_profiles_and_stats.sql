-- =============================================================================
-- AXIS: User Profiles, User XP & Level Sync Migration
-- 1. Creates public.user_profiles storing per-user profile, total XP and Level
-- 2. Configures multi-user Row Level Security (RLS)
-- 3. Adds public.user_profiles to PowerSync logical replication publication
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id           text PRIMARY KEY,
  user_id      uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name         text NOT NULL DEFAULT 'Commander',
  title        text NOT NULL DEFAULT 'Specialist',
  avatar_color text NOT NULL DEFAULT '#6366F1',
  total_xp     integer NOT NULL DEFAULT 0,
  level        integer NOT NULL DEFAULT 1,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
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

-- Add to PowerSync replication publication
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    ALTER PUBLICATION powersync ADD TABLE public.user_profiles;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
