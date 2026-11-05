-- =============================================================================
-- AXIS: Atomic Daily Prayer Status Toggle and Synchronization RPCs
-- Eliminates client-side race conditions, partial column overwrites, and
-- dual-sync competition between PowerSync and Supabase Realtime.
-- =============================================================================

-- 1. Atomic Prayer Toggle & Progress Update Function
CREATE OR REPLACE FUNCTION public.toggle_user_prayer(
  p_code text DEFAULT NULL,
  p_done boolean DEFAULT false,
  p_date text DEFAULT NULL,
  p_streak integer DEFAULT NULL,
  p_habits_done integer DEFAULT NULL,
  p_habits_total integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_date text := COALESCE(p_date, to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD'));
  v_id text;
  v_code text := lower(trim(COALESCE(p_code, '')));
  v_row record;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_id := 'prs_' || v_uid || '_' || v_date;

  INSERT INTO public.daily_prayer_status (
    id,
    user_id,
    date,
    fajr,
    dhuhr,
    asr,
    maghrib,
    isha,
    streak_days,
    habits_done,
    habits_total,
    created_at,
    updated_at
  ) VALUES (
    v_id,
    v_uid,
    v_date,
    CASE WHEN v_code = 'fajr' THEN p_done ELSE false END,
    CASE WHEN v_code = 'dhuhr' THEN p_done ELSE false END,
    CASE WHEN v_code = 'asr' THEN p_done ELSE false END,
    CASE WHEN v_code = 'maghrib' THEN p_done ELSE false END,
    CASE WHEN v_code = 'isha' THEN p_done ELSE false END,
    COALESCE(p_streak, 0),
    COALESCE(p_habits_done, 0),
    COALESCE(p_habits_total, 0),
    now(),
    now()
  )
  ON CONFLICT (user_id, date) DO UPDATE SET
    fajr = CASE WHEN v_code = 'fajr' THEN p_done ELSE daily_prayer_status.fajr END,
    dhuhr = CASE WHEN v_code = 'dhuhr' THEN p_done ELSE daily_prayer_status.dhuhr END,
    asr = CASE WHEN v_code = 'asr' THEN p_done ELSE daily_prayer_status.asr END,
    maghrib = CASE WHEN v_code = 'maghrib' THEN p_done ELSE daily_prayer_status.maghrib END,
    isha = CASE WHEN v_code = 'isha' THEN p_done ELSE daily_prayer_status.isha END,
    streak_days = CASE
      WHEN p_streak IS NOT NULL AND p_streak > 0 THEN p_streak
      ELSE daily_prayer_status.streak_days
    END,
    habits_done = COALESCE(p_habits_done, daily_prayer_status.habits_done),
    habits_total = CASE
      WHEN p_habits_total IS NOT NULL AND p_habits_total > 0 THEN p_habits_total
      ELSE daily_prayer_status.habits_total
    END,
    updated_at = now()
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row);
END;
$$;

-- 2. Atomic Prayer Reset Function
CREATE OR REPLACE FUNCTION public.reset_user_prayers(p_date text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_date text := COALESCE(p_date, to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD'));
  v_row record;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.daily_prayer_status
  SET fajr = false,
      dhuhr = false,
      asr = false,
      maghrib = false,
      isha = false,
      updated_at = now()
  WHERE user_id = v_uid AND date = v_date
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row);
END;
$$;

-- 3. Security Grants
GRANT EXECUTE ON FUNCTION public.toggle_user_prayer TO authenticated;
GRANT EXECUTE ON FUNCTION public.reset_user_prayers TO authenticated;

-- 4. Ensure REPLICA IDENTITY FULL for zero-loss Realtime WAL broadcasting
ALTER TABLE public.daily_prayer_status REPLICA IDENTITY FULL;

-- 5. Ensure daily_prayer_status is in the PowerSync publication
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'powersync' AND tablename = 'daily_prayer_status') THEN
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.daily_prayer_status;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'powersync_axis' AND tablename = 'daily_prayer_status') THEN
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.daily_prayer_status;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;
END $$;

