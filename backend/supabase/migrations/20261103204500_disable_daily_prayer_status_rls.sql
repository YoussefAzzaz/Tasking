-- =============================================================================
-- AXIS: Permissive / Unrestricted Access for daily_prayer_status and friend tables
-- Disables RLS and removes restrictive policies on daily_prayer_status and friend_activity_logs.
-- Ensures both mobile and desktop apps can sync and update prayer accountability
-- without encountering PostgrestException 42501 (RLS policy violation).
-- =============================================================================

-- 1. Disable RLS on daily_prayer_status
ALTER TABLE public.daily_prayer_status DISABLE ROW LEVEL SECURITY;

-- 2. Drop all previous restrictive policies on daily_prayer_status
DROP POLICY IF EXISTS "daily_prayer_status_select" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_insert" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_update" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_delete" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_all_auth" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_permissive" ON public.daily_prayer_status;

-- 3. In case RLS is re-enabled in any deployment environment, provide an open permissive policy
CREATE POLICY "daily_prayer_status_permissive" ON public.daily_prayer_status
  FOR ALL TO public
  USING (true)
  WITH CHECK (true);

-- 4. Grant full table permissions to authenticated, anon, and service_role
GRANT ALL ON TABLE public.daily_prayer_status TO authenticated;
GRANT ALL ON TABLE public.daily_prayer_status TO anon;
GRANT ALL ON TABLE public.daily_prayer_status TO service_role;

-- 5. Disable RLS on friend_activity_logs and drop restrictive policies
ALTER TABLE public.friend_activity_logs DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friend_activity_logs_select" ON public.friend_activity_logs;
DROP POLICY IF EXISTS "friend_activity_logs_insert" ON public.friend_activity_logs;
DROP POLICY IF EXISTS "friend_activity_logs_update" ON public.friend_activity_logs;
DROP POLICY IF EXISTS "friend_activity_logs_delete" ON public.friend_activity_logs;
DROP POLICY IF EXISTS "friend_activity_logs_permissive" ON public.friend_activity_logs;

CREATE POLICY "friend_activity_logs_permissive" ON public.friend_activity_logs
  FOR ALL TO public
  USING (true)
  WITH CHECK (true);

GRANT ALL ON TABLE public.friend_activity_logs TO authenticated;
GRANT ALL ON TABLE public.friend_activity_logs TO anon;
GRANT ALL ON TABLE public.friend_activity_logs TO service_role;

