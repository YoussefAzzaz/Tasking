-- Migration: 20261108083000_preserve_logs_in_cleanup_rpc.sql
-- Purges transient friend activity logs older than 15 days in Supabase.
-- Preserves public.logs so user XP and gamification history are never lost.

CREATE OR REPLACE FUNCTION public.clean_expired_logs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- 1. Purge transient companion notifications and activity logs older than 15 days
  DELETE FROM public.friend_activity_logs
  WHERE created_at < (pg_catalog.now() - INTERVAL '15 days');

  -- 2. Note: public.logs contains historical XP events, level progression, and
  -- gamification metrics. It is intentionally preserved and not truncated.
END;
$$;

-- Allow authenticated users and background workers to call cleanup (revoke anon/public)
REVOKE EXECUTE ON FUNCTION public.clean_expired_logs() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.clean_expired_logs() TO authenticated, service_role;

