-- Migration: 20261110220000_permanent_xp_logs_protection.sql
-- Description:
-- 1. Redefines public.clean_expired_logs() to strictly purge transient friend activity logs.
-- 2. Permanently preserves public.logs from truncation, ensuring user XP and level progression never reset.
-- 3. Unregisters any legacy pg_cron jobs that might have targeted public.logs.

CREATE OR REPLACE FUNCTION public.clean_expired_logs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Purge ONLY transient companion notifications and friend activity logs older than 15 days
  DELETE FROM public.friend_activity_logs
  WHERE created_at < (pg_catalog.now() - INTERVAL '15 days');

  -- public.logs is PERMANENTLY PRESERVED:
  -- Contains historical XP events, level progression, badges, and user gamification milestones.
  -- It must NEVER be deleted or truncated by automated cleanup routines.
END;
$$;

-- Allow authenticated users and background workers to call cleanup (revoke anon/public)
REVOKE EXECUTE ON FUNCTION public.clean_expired_logs() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.clean_expired_logs() TO authenticated, service_role;

-- Safely deschedule legacy pg_cron job if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      PERFORM cron.unschedule('purge_15_day_logs');
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

