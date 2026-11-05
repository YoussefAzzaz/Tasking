-- =============================================================================
-- AXIS: Enable Supabase Realtime for Prayers, Companions, and Activity Logs
-- Ensures Postgres change events on daily_prayer_status, friendships,
-- friend_activity_logs, and user_profiles are broadcast via Realtime channels.
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'daily_prayer_status'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_prayer_status;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'friendships'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.friendships;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'friend_activity_logs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_activity_logs;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'user_profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_profiles;
  END IF;
END $$;

