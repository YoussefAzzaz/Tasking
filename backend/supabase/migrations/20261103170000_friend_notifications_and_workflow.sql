-- =============================================================================
-- AXIS: Friend Notifications, Reminders & Request Workflow Migration
-- 1. Updates RLS policies on friend_activity_logs for cross-user nudges & requests
-- 2. Updates friendships constraint to support 'declined' status
-- 3. Adds SECURITY DEFINER helper RPCs for responding to requests and sending nudges
-- =============================================================================

-- 1. Update friendships table check constraint to support 'declined'
ALTER TABLE public.friendships
  DROP CONSTRAINT IF EXISTS friendships_status_check;

ALTER TABLE public.friendships
  ADD CONSTRAINT friendships_status_check
  CHECK (status IN ('pending', 'accepted', 'declined', 'blocked'));

-- 2. Fix friend_activity_logs RLS policies
ALTER TABLE public.friend_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friend_activity_logs_select" ON public.friend_activity_logs;
CREATE POLICY "friend_activity_logs_select" ON public.friend_activity_logs
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    OR user_id IN (SELECT public.get_accepted_friend_ids((SELECT auth.uid())))
  );

DROP POLICY IF EXISTS "friend_activity_logs_insert" ON public.friend_activity_logs;
CREATE POLICY "friend_activity_logs_insert" ON public.friend_activity_logs
  FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "friend_activity_logs_update" ON public.friend_activity_logs;
CREATE POLICY "friend_activity_logs_update" ON public.friend_activity_logs
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "friend_activity_logs_delete" ON public.friend_activity_logs;
CREATE POLICY "friend_activity_logs_delete" ON public.friend_activity_logs
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 3. Security Definer function to fetch any companion profile safely
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
) LANGUAGE sql SECURITY DEFINER STABLE AS $$
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

GRANT EXECUTE ON FUNCTION public.get_companion_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_companion_profile(uuid) TO anon;

-- 4. RPC to respond to a friend request (Accept or Refuse/Decline)
CREATE OR REPLACE FUNCTION public.respond_companion_request(
  p_friendship_id text,
  p_action text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  curr_uid uuid := auth.uid();
  f_row record;
  curr_name text;
  now_iso timestamptz := now();
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

  IF lower(p_action) = 'accept' THEN
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

GRANT EXECUTE ON FUNCTION public.respond_companion_request(text, text) TO authenticated;

-- 5. RPC to send gentle prayer reminder / nudge
CREATE OR REPLACE FUNCTION public.send_prayer_reminder_rpc(
  p_target_user_id uuid,
  p_prayer_name text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  curr_uid uuid := auth.uid();
  curr_name text;
  now_iso timestamptz := now();
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

GRANT EXECUTE ON FUNCTION public.send_prayer_reminder_rpc(uuid, text) TO authenticated;

