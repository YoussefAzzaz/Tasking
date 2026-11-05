-- Migration: 20261104010000_cleanup_old_logs.sql
-- Purges activity logs and notification logs older than 15 days in Supabase.

CREATE OR REPLACE FUNCTION public.clean_expired_logs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- 1. Purge companion notifications and activity logs older than 15 days
  DELETE FROM public.friend_activity_logs
  WHERE created_at < (pg_catalog.now() - INTERVAL '15 days');

  -- 2. Purge user event logs older than 15 days
  BEGIN
    DELETE FROM public.logs
    WHERE timestamp::timestamptz < (pg_catalog.now() - INTERVAL '15 days');
  EXCEPTION
    WHEN OTHERS THEN
      DELETE FROM public.logs
      WHERE timestamp < pg_catalog.to_char(pg_catalog.now() - INTERVAL '15 days', 'YYYY-MM-DD"T"HH24:MI:SS');
  END;
END;
$$;

-- Allow authenticated users and background workers to call cleanup (revoke anon/public)
REVOKE EXECUTE ON FUNCTION public.clean_expired_logs() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.clean_expired_logs() TO authenticated, service_role;

-- Setup automatic scheduled cleanup if pg_cron extension is available
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'purge_15_day_logs',
      '0 2 * * *',
      'SELECT public.clean_expired_logs();'
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

