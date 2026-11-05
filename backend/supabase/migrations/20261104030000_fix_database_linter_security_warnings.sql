-- =============================================================================
-- Migration: Fix Database Linter Security Warnings (0011, 0025, 0028, 0029)
-- 1. Sets fixed search_path = '' on all functions (fixes function_search_path_mutable 0011)
-- 2. Restricts bucket listing on storage.objects for public bucket 'avatars' (fixes public_bucket_allows_listing 0025)
-- 3. Revokes anon execute on sensitive/internal SECURITY DEFINER functions (fixes anon_security_definer_function_executable 0028)
-- 4. Converts RPC endpoints to SECURITY INVOKER where caller permissions suffice,
--    and revokes public/authenticated execute on purely internal triggers (fixes authenticated_security_definer_function_executable 0029)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Trigger functions & Helper functions: Set fixed search_path & Revoke public execute
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.axis_set_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = pg_catalog.now();
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.axis_set_updated_at() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.axis_set_updated_at() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.generate_friend_code()
RETURNS text 
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  chars text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  result text := 'AX-';
  i integer;
BEGIN
  FOR i IN 1..4 LOOP
    result := result || pg_catalog.substr(chars, pg_catalog.floor(pg_catalog.random() * pg_catalog.length(chars) + 1)::integer, 1);
  END LOOP;
  RETURN result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.generate_friend_code() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.generate_friend_code() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.trg_assign_friend_code()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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

REVOKE EXECUTE ON FUNCTION public.trg_assign_friend_code() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.trg_assign_friend_code() TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Auth Trigger: handle_new_user_prayers
-- Internal trigger for auth.users; revoke from public, anon, and authenticated
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user_prayers()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.prayers (id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at)
  VALUES
    ('prayer_' || NEW.id || '_fajr', NEW.id, 'fajr', 'Fajr', 'fajr', '05:15 AM', 1, false, pg_catalog.now(), pg_catalog.now()),
    ('prayer_' || NEW.id || '_dhuhr', NEW.id, 'dhuhr', 'Dhuhr', 'dhuhr', '12:30 PM', 2, false, pg_catalog.now(), pg_catalog.now()),
    ('prayer_' || NEW.id || '_asr', NEW.id, 'asr', 'Asr', 'asr', '04:15 PM', 3, false, pg_catalog.now(), pg_catalog.now()),
    ('prayer_' || NEW.id || '_maghrib', NEW.id, 'maghrib', 'Maghrib', 'maghrib', '06:45 PM', 4, false, pg_catalog.now(), pg_catalog.now()),
    ('prayer_' || NEW.id || '_isha', NEW.id, 'isha', 'Isha', 'isha', '08:15 PM', 5, false, pg_catalog.now(), pg_catalog.now())
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.handle_new_user_prayers() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user_prayers() TO postgres, service_role;

-- Internal DDL helper if present:
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc WHERE proname = 'rls_auto_enable') THEN
    ALTER FUNCTION public.rls_auto_enable() SET search_path = '';
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM public, anon, authenticated;
    GRANT EXECUTE ON FUNCTION public.rls_auto_enable() TO postgres, service_role;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. RLS helper: get_accepted_friend_ids
-- Called within policies. User already has SELECT access on their friendships.
-- Switched to SECURITY INVOKER + search_path = '' + revoked from anon.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_accepted_friend_ids(user_uuid uuid)
RETURNS SETOF uuid 
LANGUAGE sql 
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT CASE WHEN requester_id = user_uuid THEN addressee_id ELSE requester_id END
  FROM public.friendships
  WHERE status = 'accepted' AND (requester_id = user_uuid OR addressee_id = user_uuid);
$$;

REVOKE EXECUTE ON FUNCTION public.get_accepted_friend_ids(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_accepted_friend_ids(uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. Companion search & Profile RPCs
-- user_profiles already permits SELECT to authenticated users.
-- Switched to SECURITY INVOKER + search_path = '' + revoked from anon.
-- -----------------------------------------------------------------------------

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
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  clean_input text := trim(search_query);
  clean_upper text := pg_catalog.upper(clean_input);
  raw_code text := pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(clean_upper, 'AX-', ''), '-', ''), ' ', '');
  curr_uid uuid := auth.uid();
BEGIN
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
    -- Match exact or partial friend_code (with or without 'AX-')
    pg_catalog.upper(p.friend_code) = clean_upper
    OR pg_catalog.upper(p.friend_code) = ('AX-' || raw_code)
    OR pg_catalog.replace(pg_catalog.upper(p.friend_code), '-', '') = raw_code
    -- Match by UUID prefix (first 4+ chars)
    OR (pg_catalog.length(raw_code) >= 4 AND p.user_id::text ILIKE (pg_catalog.lower(raw_code) || '%'))
    -- Match by display name
    OR p.name ILIKE ('%' || clean_input || '%')
  )
  -- Do not return oneself
  AND (curr_uid IS NULL OR p.user_id <> curr_uid)
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
SECURITY INVOKER
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
  LIMIT 1;
$$;

REVOKE EXECUTE ON FUNCTION public.get_companion_profile(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_companion_profile(uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5. Companion Action RPCs: respond_companion_request & send_prayer_reminder_rpc & send_companion_request
-- Table RLS permits user's own updates & friend notification inserts.
-- Switched to SECURITY INVOKER + search_path = '' + revoked from anon.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.respond_companion_request(
  p_friendship_id text,
  p_action text
) 
RETURNS jsonb 
LANGUAGE plpgsql 
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  curr_uid uuid := auth.uid();
  f_row record;
  curr_name text;
  now_iso timestamptz := pg_catalog.now();
  log_id text;
BEGIN
  IF curr_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Must be authenticated');
  END IF;

  SELECT * INTO f_row FROM public.friendships WHERE id = p_friendship_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friendship request not found');
  END IF;

  -- Ensure only the addressee can accept or refuse the request
  IF f_row.addressee_id <> curr_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized to respond to this request');
  END IF;

  -- Get current user display name
  SELECT COALESCE(name, 'Companion') INTO curr_name FROM public.user_profiles WHERE user_id = curr_uid;
  IF curr_name IS NULL THEN curr_name := 'Companion'; END IF;

  log_id := 'log_' || curr_uid::text || '_' || extract(epoch from now_iso)::bigint::text;

  IF pg_catalog.lower(p_action) = 'accept' THEN
    UPDATE public.friendships
    SET status = 'accepted', updated_at = now_iso
    WHERE id = p_friendship_id;

    -- Send notification to requester that request was accepted
    INSERT INTO public.friend_activity_logs (id, user_id, event_type, title, metadata, created_at)
    VALUES (
      log_id,
      f_row.requester_id,
      'request_accepted',
      curr_name || ' accepted your companion request',
      jsonb_build_object('sender_id', curr_uid, 'sender_name', curr_name, 'friendship_id', p_friendship_id),
      now_iso
    );

    RETURN jsonb_build_object('success', true, 'status', 'accepted');
  ELSE
    -- Refuse / Decline
    DELETE FROM public.friendships WHERE id = p_friendship_id;

    -- Send notification to requester that request was declined
    INSERT INTO public.friend_activity_logs (id, user_id, event_type, title, metadata, created_at)
    VALUES (
      log_id,
      f_row.requester_id,
      'request_declined',
      curr_name || ' declined your companion request',
      jsonb_build_object('sender_id', curr_uid, 'sender_name', curr_name, 'friendship_id', p_friendship_id),
      now_iso
    );

    RETURN jsonb_build_object('success', true, 'status', 'declined');
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.respond_companion_request(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.respond_companion_request(text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.send_prayer_reminder_rpc(
  p_target_user_id uuid,
  p_prayer_name text
) 
RETURNS jsonb 
LANGUAGE plpgsql 
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  curr_uid uuid := auth.uid();
  curr_name text;
  now_iso timestamptz := pg_catalog.now();
  log_id text;
BEGIN
  IF curr_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Must be authenticated');
  END IF;

  SELECT COALESCE(name, 'Companion') INTO curr_name FROM public.user_profiles WHERE user_id = curr_uid;
  IF curr_name IS NULL THEN curr_name := 'Companion'; END IF;

  log_id := 'nudge_' || curr_uid::text || '_' || p_target_user_id::text || '_' || extract(epoch from now_iso)::bigint::text;

  INSERT INTO public.friend_activity_logs (id, user_id, event_type, title, metadata, created_at)
  VALUES (
    log_id,
    p_target_user_id,
    'prayer_reminder',
    curr_name || ' reminded you to pray ' || p_prayer_name,
    jsonb_build_object('sender_id', curr_uid, 'sender_name', curr_name, 'prayer_name', p_prayer_name),
    now_iso
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_prayer_reminder_rpc(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.send_prayer_reminder_rpc(uuid, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.send_companion_request(target_code_or_name text)
RETURNS jsonb 
LANGUAGE plpgsql 
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  curr_uid uuid := auth.uid();
  target_uid uuid;
  friendship_id text;
  now_iso timestamptz := pg_catalog.now();
BEGIN
  IF curr_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Must be authenticated');
  END IF;

  -- Find target user using search_companion logic
  SELECT s.user_id INTO target_uid
  FROM public.search_companion(target_code_or_name) s
  LIMIT 1;

  IF target_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Companion not found');
  END IF;

  IF target_uid = curr_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot add yourself');
  END IF;

  friendship_id := 'friendship_' || curr_uid::text || '_' || target_uid::text;

  INSERT INTO public.friendships (id, requester_id, addressee_id, status, created_at, updated_at)
  VALUES (friendship_id, curr_uid, target_uid, 'pending', now_iso, now_iso)
  ON CONFLICT (requester_id, addressee_id) 
  DO UPDATE SET updated_at = now_iso, status = CASE WHEN friendships.status = 'accepted' THEN 'accepted' ELSE 'pending' END;

  RETURN jsonb_build_object('success', true, 'target_user_id', target_uid);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_companion_request(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.send_companion_request(text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 6. Storage: Restrict public listing on storage.objects for avatars bucket
-- Fixes public_bucket_allows_listing (Lint 0025)
-- Public URL access to objects in public bucket 'avatars' is handled natively without SELECT on storage.objects.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "avatars_public_select" ON storage.objects;

-- Authenticated users can query only their own files in avatars/{user_id}/*
DROP POLICY IF EXISTS "avatars_owner_select" ON storage.objects;
CREATE POLICY "avatars_owner_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
  );

-- -----------------------------------------------------------------------------
-- 7. Log cleanup function: Set search_path = '' & Revoke from public, anon
-- -----------------------------------------------------------------------------

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

REVOKE EXECUTE ON FUNCTION public.clean_expired_logs() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.clean_expired_logs() TO authenticated, service_role;


