-- =============================================================================
-- AXIS: Dedicated Prayers Table & Synced Habit Categories Migration
-- 1. Creates public.habit_categories with multi-user RLS & PowerSync replication
-- 2. Creates public.prayers dedicated exclusively for the 5 daily prayers
-- 3. Cleans up legacy prayer habits from public.habits
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Habit Categories (Synced across devices)
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
  prayer_code  text NOT NULL, -- 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'
  name         text NOT NULL, -- 'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'
  icon         text NOT NULL, -- 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'
  time         text NOT NULL, -- e.g. '05:14'
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
-- 3. Add both tables to PowerSync logical replication publication
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    ALTER PUBLICATION powersync ADD TABLE public.habit_categories;
    ALTER PUBLICATION powersync ADD TABLE public.prayers;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- -----------------------------------------------------------------------------
-- 4. Purge legacy prayer habits from generic habits table
-- -----------------------------------------------------------------------------
DELETE FROM public.habits WHERE kind = 'Prayers' OR id LIKE 'habit_prayer_%';
