-- =============================================================================
-- Migration: Phase 1 Security, RLS, Privilege & Schema Hardening
-- Resolves critical database security gaps identified in repository audit:
-- 1. Enables RLS on public.calendar_secrets and revokes all client grants.
-- 2. Revokes residual anon grants on daily_prayer_status, friend_activity_logs,
--    and companion_shares.
-- 3. Enforces consent state transitions on public.friendships (preventing
--    requester self-acceptance) and relationship-scoped friend_activity_logs.
-- 4. Scopes public.user_profiles SELECT policy to own profile and active
--    companions/share partners while maintaining authenticated search/profile RPCs.
-- 5. Sets a safe UTC date default on public.habits.start_date to eliminate
--    Postgres 23502 NOT NULL upload failures from offline clients.
-- 6. Revokes anon/public execution on sharing triggers & collaborative RPCs.
-- =============================================================================

-- 1. Lock down calendar_secrets (service_role only)
ALTER TABLE public.calendar_secrets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.calendar_secrets FROM PUBLIC, anon, authenticated;

-- 2. Revoke unintended anon table privileges
REVOKE ALL ON TABLE public.daily_prayer_status FROM anon;
REVOKE ALL ON TABLE public.friend_activity_logs FROM anon;
REVOKE ALL ON TABLE public.companion_shares FROM anon;

-- 3. Enforce reciprocal consent rules on friendships
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friendships_insert" ON public.friendships;
CREATE POLICY "friendships_insert" ON public.friendships
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = requester_id
    AND requester_id <> addressee_id
    AND status = 'pending'
  );

DROP POLICY IF EXISTS "friendships_update" ON public.friendships;
CREATE POLICY "friendships_update" ON public.friendships
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) IN (requester_id, addressee_id))
  WITH CHECK (
    (SELECT auth.uid()) = addressee_id
    OR ((SELECT auth.uid()) = requester_id AND status = 'pending')
  );

-- 4. Restrict friend_activity_logs inserts to self or linked companions/shares
ALTER TABLE public.friend_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friend_activity_logs_insert" ON public.friend_activity_logs;
CREATE POLICY "friend_activity_logs_insert" ON public.friend_activity_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    OR (
      (metadata->>'sender_id' = (SELECT auth.uid())::text)
      AND (
        EXISTS (
          SELECT 1
          FROM public.friendships f
          WHERE (f.requester_id = (SELECT auth.uid()) AND f.addressee_id = friend_activity_logs.user_id)
             OR (f.addressee_id = (SELECT auth.uid()) AND f.requester_id = friend_activity_logs.user_id)
        )
        OR EXISTS (
          SELECT 1
          FROM public.companion_shares cs
          WHERE (cs.sender_id = (SELECT auth.uid()) AND cs.recipient_id = friend_activity_logs.user_id)
             OR (cs.recipient_id = (SELECT auth.uid()) AND cs.sender_id = friend_activity_logs.user_id)
        )
      )
    )
  );

-- 5. Scope user_profiles SELECT to owner, companions, pending invites, and share partners
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_profiles_select_policy" ON public.user_profiles;
CREATE POLICY "user_profiles_select_policy" ON public.user_profiles
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    OR user_id IN (SELECT public.get_accepted_friend_ids((SELECT auth.uid())))
    OR EXISTS (
      SELECT 1
      FROM public.friendships f
      WHERE (f.requester_id = (SELECT auth.uid()) AND f.addressee_id = user_profiles.user_id)
         OR (f.addressee_id = (SELECT auth.uid()) AND f.requester_id = user_profiles.user_id)
    )
    OR EXISTS (
      SELECT 1
      FROM public.companion_shares cs
      WHERE (cs.sender_id = (SELECT auth.uid()) AND cs.recipient_id = user_profiles.user_id)
         OR (cs.recipient_id = (SELECT auth.uid()) AND cs.sender_id = user_profiles.user_id)
    )
  );

-- Controlled SECURITY DEFINER RPCs for companion search & profile lookup
-- (authenticated only, minimum query length & wildcard escaping to prevent scraping)
CREATE OR REPLACE FUNCTION public.search_companion(search_query text)
RETURNS TABLE (
  user_id uuid,
  name text,
  friend_code text,
  avatar_color text,
  avatar_url text,
  level integer,
  total_xp integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  clean_input text := trim(COALESCE(search_query, ''));
  clean_upper text := pg_catalog.upper(clean_input);
  clean_escaped text := pg_catalog.replace(
    pg_catalog.replace(
      pg_catalog.replace(clean_input, '\', '\\'),
      '%',
      '\%'
    ),
    '_',
    '\_'
  );
  raw_code text := pg_catalog.replace(
    pg_catalog.replace(pg_catalog.replace(clean_upper, 'AX-', ''), '-', ''),
    ' ',
    ''
  );
  curr_uid uuid := auth.uid();
BEGIN
  IF curr_uid IS NULL OR pg_catalog.length(clean_input) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    p.user_id,
    p.name,
    p.friend_code,
    p.avatar_color,
    p.avatar_url,
    p.level,
    p.total_xp
  FROM public.user_profiles p
  WHERE (
    pg_catalog.upper(p.friend_code) = clean_upper
    OR (raw_code <> '' AND pg_catalog.upper(p.friend_code) = ('AX-' || raw_code))
    OR (raw_code <> '' AND pg_catalog.replace(pg_catalog.upper(p.friend_code), '-', '') = raw_code)
    OR (pg_catalog.length(raw_code) >= 4 AND p.user_id::text ILIKE (pg_catalog.lower(raw_code) || '%'))
    OR p.name ILIKE ('%' || clean_escaped || '%') ESCAPE '\'
  )
  AND p.user_id <> curr_uid
  LIMIT 5;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.search_companion(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.search_companion(text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_companion_profile(target_uid uuid)
RETURNS TABLE (
  id text,
  user_id uuid,
  name text,
  title text,
  avatar_color text,
  avatar_url text,
  total_xp integer,
  level integer,
  friend_code text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p.id,
    p.user_id,
    p.name,
    p.title,
    p.avatar_color,
    p.avatar_url,
    p.total_xp,
    p.level,
    p.friend_code
  FROM public.user_profiles p
  WHERE p.user_id = target_uid
    AND (SELECT auth.uid()) IS NOT NULL
    AND (
      p.user_id = (SELECT auth.uid())
      OR EXISTS (
        SELECT 1
        FROM public.friendships f
        WHERE (f.requester_id = (SELECT auth.uid()) AND f.addressee_id = target_uid)
           OR (f.addressee_id = (SELECT auth.uid()) AND f.requester_id = target_uid)
      )
      OR EXISTS (
        SELECT 1
        FROM public.companion_shares cs
        WHERE (cs.sender_id = (SELECT auth.uid()) AND cs.recipient_id = target_uid)
           OR (cs.recipient_id = (SELECT auth.uid()) AND cs.sender_id = target_uid)
      )
    )
  LIMIT 1;
$$;

REVOKE EXECUTE ON FUNCTION public.get_companion_profile(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_companion_profile(uuid) TO authenticated, service_role;

-- 6. Habits schema safety: ensure start_date NOT NULL column has a server default
ALTER TABLE public.habits
  ALTER COLUMN start_date
  SET DEFAULT pg_catalog.to_char(pg_catalog.now() AT TIME ZONE 'UTC', 'YYYY-MM-DD');

-- 7. Revoke public/anon execution on sharing RPCs & internal trigger functions
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc WHERE proname = 'prevent_duplicate_companion_share') THEN
    REVOKE EXECUTE ON FUNCTION public.prevent_duplicate_companion_share() FROM public, anon, authenticated;
    GRANT EXECUTE ON FUNCTION public.prevent_duplicate_companion_share() TO postgres, service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc WHERE proname = 'sync_collaborative_task') THEN
    REVOKE EXECUTE ON FUNCTION public.sync_collaborative_task() FROM public, anon, authenticated;
    GRANT EXECUTE ON FUNCTION public.sync_collaborative_task() TO postgres, service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc WHERE proname = 'accept_companion_share') THEN
    REVOKE EXECUTE ON FUNCTION public.accept_companion_share(text, text) FROM public, anon;
    GRANT EXECUTE ON FUNCTION public.accept_companion_share(text, text) TO authenticated, service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc WHERE proname = 'cancel_collaborative_share_on_task_delete') THEN
    REVOKE EXECUTE ON FUNCTION public.cancel_collaborative_share_on_task_delete(text) FROM public, anon;
    GRANT EXECUTE ON FUNCTION public.cancel_collaborative_share_on_task_delete(text) TO authenticated, service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc WHERE proname = 'merge_share_sender_tag') THEN
    REVOKE EXECUTE ON FUNCTION public.merge_share_sender_tag(text, text) FROM public, anon;
    GRANT EXECUTE ON FUNCTION public.merge_share_sender_tag(text, text) TO authenticated, service_role;
  END IF;
END $$;
