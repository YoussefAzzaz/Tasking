-- =============================================================================
-- AXIS: Auto-Seed 5 Prayers for New and Existing Users Trigger
-- Ensures that whenever a user account is created in auth.users,
-- exactly five prayers (Fajr, Dhuhr, Asr, Maghrib, Isha) are populated in public.prayers.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user_prayers()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.prayers (id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at)
  VALUES
    ('prayer_' || NEW.id || '_fajr', NEW.id, 'fajr', 'Fajr', 'fajr', '05:15 AM', 1, false, now(), now()),
    ('prayer_' || NEW.id || '_dhuhr', NEW.id, 'dhuhr', 'Dhuhr', 'dhuhr', '12:30 PM', 2, false, now(), now()),
    ('prayer_' || NEW.id || '_asr', NEW.id, 'asr', 'Asr', 'asr', '04:15 PM', 3, false, now(), now()),
    ('prayer_' || NEW.id || '_maghrib', NEW.id, 'maghrib', 'Maghrib', 'maghrib', '06:45 PM', 4, false, now(), now()),
    ('prayer_' || NEW.id || '_isha', NEW.id, 'isha', 'Isha', 'isha', '08:15 PM', 5, false, now(), now())
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_prayers ON auth.users;
CREATE TRIGGER on_auth_user_created_prayers
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_prayers();

-- Backfill all existing users in auth.users with the 5 canonical daily prayers
DO $$
DECLARE
  u RECORD;
BEGIN
  FOR u IN SELECT id FROM auth.users LOOP
    INSERT INTO public.prayers (id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at)
    VALUES
      ('prayer_' || u.id || '_fajr', u.id, 'fajr', 'Fajr', 'fajr', '05:15 AM', 1, false, now(), now()),
      ('prayer_' || u.id || '_dhuhr', u.id, 'dhuhr', 'Dhuhr', 'dhuhr', '12:30 PM', 2, false, now(), now()),
      ('prayer_' || u.id || '_asr', u.id, 'asr', 'Asr', 'asr', '04:15 PM', 3, false, now(), now()),
      ('prayer_' || u.id || '_maghrib', u.id, 'maghrib', 'Maghrib', 'maghrib', '06:45 PM', 4, false, now(), now()),
      ('prayer_' || u.id || '_isha', u.id, 'isha', 'Isha', 'isha', '08:15 PM', 5, false, now(), now())
    ON CONFLICT (id) DO NOTHING;
  END LOOP;
END $$;
