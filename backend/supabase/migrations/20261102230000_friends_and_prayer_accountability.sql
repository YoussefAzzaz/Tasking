-- =============================================================================
-- AXIS: Friends System, Daily Prayer Checklist & Mutual Accountability Migration
-- 1. Adds friend_code to user_profiles with auto-generator
-- 2. Creates friendships table with bidirectional accepted RLS
-- 3. Creates daily_prayer_status table for live prayer & habit checklist between friends
-- 4. Creates friend_activity_logs table for gentle celebration & nudges
-- 5. Configures PowerSync publication
-- =============================================================================

-- 1. Add friend_code column to user_profiles
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS friend_code text UNIQUE;

-- Function to generate a clean, readable 6-character uppercase alphanumeric code (e.g. AX-7482)
CREATE OR REPLACE FUNCTION public.generate_friend_code()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  chars text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  result text := 'AX-';
  i integer;
BEGIN
  FOR i IN 1..4 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  END LOOP;
  RETURN result;
END;
$$;

-- Trigger to auto-assign a friend_code if missing
CREATE OR REPLACE FUNCTION public.trg_assign_friend_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.friend_code IS NULL OR NEW.friend_code = '' THEN
    LOOP
      NEW.friend_code := public.generate_friend_code();
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE friend_code = NEW.friend_code);
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_friend_code_on_insert ON public.user_profiles;
CREATE TRIGGER set_friend_code_on_insert
  BEFORE INSERT ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.trg_assign_friend_code();

-- Populate any existing profiles that don't have a friend_code
UPDATE public.user_profiles
SET friend_code = public.generate_friend_code()
WHERE friend_code IS NULL OR friend_code = '';

-- 2. Friendships Table
CREATE TABLE IF NOT EXISTS public.friendships (
  id           text PRIMARY KEY,
  requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (requester_id, addressee_id),
  CHECK (requester_id <> addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_requester ON public.friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON public.friendships(addressee_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON public.friendships(status);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friendships_select" ON public.friendships;
CREATE POLICY "friendships_select" ON public.friendships
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IN (requester_id, addressee_id));

DROP POLICY IF EXISTS "friendships_insert" ON public.friendships;
CREATE POLICY "friendships_insert" ON public.friendships
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = requester_id);

DROP POLICY IF EXISTS "friendships_update" ON public.friendships;
CREATE POLICY "friendships_update" ON public.friendships
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) IN (requester_id, addressee_id))
  WITH CHECK ((SELECT auth.uid()) IN (requester_id, addressee_id));

DROP POLICY IF EXISTS "friendships_delete" ON public.friendships;
CREATE POLICY "friendships_delete" ON public.friendships
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) IN (requester_id, addressee_id));

-- Helper security definer function to return all accepted friend UUIDs for a given user
CREATE OR REPLACE FUNCTION public.get_accepted_friend_ids(user_uuid uuid)
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT CASE WHEN requester_id = user_uuid THEN addressee_id ELSE requester_id END
  FROM public.friendships
  WHERE status = 'accepted' AND (requester_id = user_uuid OR addressee_id = user_uuid);
$$;

-- 3. Daily Prayer & Habit Status Table (Checklist shared between friends)
CREATE TABLE IF NOT EXISTS public.daily_prayer_status (
  id           text PRIMARY KEY, -- 'prs_{user_id}_{date}'
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date         text NOT NULL,    -- 'YYYY-MM-DD'
  fajr         boolean NOT NULL DEFAULT false,
  dhuhr        boolean NOT NULL DEFAULT false,
  asr          boolean NOT NULL DEFAULT false,
  maghrib      boolean NOT NULL DEFAULT false,
  isha         boolean NOT NULL DEFAULT false,
  streak_days  integer NOT NULL DEFAULT 0,
  habits_done  integer NOT NULL DEFAULT 0,
  habits_total integer NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_prayer_status_user_date ON public.daily_prayer_status(user_id, date);

ALTER TABLE public.daily_prayer_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "daily_prayer_status_select" ON public.daily_prayer_status;
CREATE POLICY "daily_prayer_status_select" ON public.daily_prayer_status
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    OR user_id IN (SELECT public.get_accepted_friend_ids((SELECT auth.uid())))
  );

DROP POLICY IF EXISTS "daily_prayer_status_insert" ON public.daily_prayer_status;
CREATE POLICY "daily_prayer_status_insert" ON public.daily_prayer_status
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "daily_prayer_status_update" ON public.daily_prayer_status;
CREATE POLICY "daily_prayer_status_update" ON public.daily_prayer_status
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "daily_prayer_status_delete" ON public.daily_prayer_status;
CREATE POLICY "daily_prayer_status_delete" ON public.daily_prayer_status
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 4. Friend Activity Logs Table (Live updates for gentle encouragement)
CREATE TABLE IF NOT EXISTS public.friend_activity_logs (
  id          text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type  text NOT NULL, -- 'prayer_done', 'habits_completed', 'streak_milestone', 'nudge'
  title       text NOT NULL, -- e.g. "Completed Asr Prayer", "Hit 14 days prayer streak!"
  metadata    jsonb DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_friend_activity_logs_user ON public.friend_activity_logs(user_id, created_at DESC);

ALTER TABLE public.friend_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friend_activity_logs_select" ON public.friend_activity_logs;
CREATE POLICY "friend_activity_logs_select" ON public.friend_activity_logs
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    OR user_id IN (SELECT public.get_accepted_friend_ids((SELECT auth.uid())))
  );

DROP POLICY IF EXISTS "friend_activity_logs_insert" ON public.friend_activity_logs;
CREATE POLICY "friend_activity_logs_insert" ON public.friend_activity_logs
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 5. Add new tables to PowerSync publications if they exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.friendships;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.daily_prayer_status;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.friend_activity_logs;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync_axis') THEN
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.friendships;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.daily_prayer_status;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.friend_activity_logs;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

