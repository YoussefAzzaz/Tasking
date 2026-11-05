-- =============================================================================
-- AXIS: Strict Multi-Tenant Row-Level Security (RLS) for Companions & Prayers
-- Restores strict security policies on daily_prayer_status and friend_activity_logs.
-- 1. daily_prayer_status:
--    - SELECT: Allowed only for the row owner or mutually accepted companions.
--    - INSERT/UPDATE/DELETE: Strictly restricted to the row owner (auth.uid() = user_id).
-- 2. friend_activity_logs:
--    - SELECT: Allowed only for the row owner or mutually accepted companions.
--    - INSERT: Restricted to row owner or verified sender in metadata.
--    - UPDATE/DELETE: Strictly restricted to the row owner.
-- 3. user_profiles:
--    - SELECT: Open to authenticated users for companion discovery and search.
--    - INSERT/UPDATE/DELETE: Strictly restricted to row owner.
-- =============================================================================

-- 1. Daily Prayer Status Security Policies
ALTER TABLE public.daily_prayer_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "daily_prayer_status_select" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_insert" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_update" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_delete" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_all_auth" ON public.daily_prayer_status;
DROP POLICY IF EXISTS "daily_prayer_status_permissive" ON public.daily_prayer_status;

-- Only self and mutually accepted companions can view prayer progress
CREATE POLICY "daily_prayer_status_select" ON public.daily_prayer_status
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    OR user_id IN (SELECT public.get_accepted_friend_ids((SELECT auth.uid())))
  );

-- Only the account owner can insert their daily prayer status
CREATE POLICY "daily_prayer_status_insert" ON public.daily_prayer_status
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Only the account owner can update their daily prayer status
CREATE POLICY "daily_prayer_status_update" ON public.daily_prayer_status
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Only the account owner can delete their daily prayer status
CREATE POLICY "daily_prayer_status_delete" ON public.daily_prayer_status
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 2. Friend Activity Logs Security Policies
ALTER TABLE public.friend_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friend_activity_logs_select" ON public.friend_activity_logs;
DROP POLICY IF EXISTS "friend_activity_logs_insert" ON public.friend_activity_logs;
DROP POLICY IF EXISTS "friend_activity_logs_update" ON public.friend_activity_logs;
DROP POLICY IF EXISTS "friend_activity_logs_delete" ON public.friend_activity_logs;
DROP POLICY IF EXISTS "friend_activity_logs_permissive" ON public.friend_activity_logs;

-- Only recipient or accepted companions can view activity logs
CREATE POLICY "friend_activity_logs_select" ON public.friend_activity_logs
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    OR user_id IN (SELECT public.get_accepted_friend_ids((SELECT auth.uid())))
  );

-- Row owner can log events for themselves; senders can send reminders/requests with verified sender_id
CREATE POLICY "friend_activity_logs_insert" ON public.friend_activity_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    OR (metadata->>'sender_id' = (SELECT auth.uid())::text)
  );

-- Only recipient/owner can update or mark logs
CREATE POLICY "friend_activity_logs_update" ON public.friend_activity_logs
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Only recipient/owner can delete/dismiss their activity logs
CREATE POLICY "friend_activity_logs_delete" ON public.friend_activity_logs
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 3. User Profiles Security Policies
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_profiles_select_policy" ON public.user_profiles;
CREATE POLICY "user_profiles_select_policy" ON public.user_profiles
  FOR SELECT TO authenticated
  USING (true);

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

-- 4. Friendships Security Policies
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friendships_select" ON public.friendships;
DROP POLICY IF EXISTS "friendships_insert" ON public.friendships;
DROP POLICY IF EXISTS "friendships_update" ON public.friendships;
DROP POLICY IF EXISTS "friendships_delete" ON public.friendships;

-- Either participant can view their friendship
CREATE POLICY "friendships_select" ON public.friendships
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IN (requester_id, addressee_id));

-- Either participant (requester or addressee) can insert or upsert the friendship connection
CREATE POLICY "friendships_insert" ON public.friendships
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) IN (requester_id, addressee_id));

-- Either participant can update friendship status (e.g. accepting, declining)
CREATE POLICY "friendships_update" ON public.friendships
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) IN (requester_id, addressee_id))
  WITH CHECK ((SELECT auth.uid()) IN (requester_id, addressee_id));

-- Either participant can delete or cancel a friendship
CREATE POLICY "friendships_delete" ON public.friendships
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) IN (requester_id, addressee_id));

-- 5. Enable REPLICA IDENTITY FULL so Postgres Realtime broadcasts full row payloads on updates
ALTER TABLE public.daily_prayer_status REPLICA IDENTITY FULL;
ALTER TABLE public.friend_activity_logs REPLICA IDENTITY FULL;
ALTER TABLE public.friendships REPLICA IDENTITY FULL;
ALTER TABLE public.user_profiles REPLICA IDENTITY FULL;



