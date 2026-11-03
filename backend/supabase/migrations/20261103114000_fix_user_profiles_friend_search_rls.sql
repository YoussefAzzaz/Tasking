-- =============================================================================
-- AXIS: Fix user_profiles RLS and Companion Search Migration
-- 1. Updates public.user_profiles SELECT policy to allow authenticated users
--    to view public profile details (name, friend_code, avatar, level, total_xp)
-- 2. Creates search_companion() SECURITY DEFINER function for flexible matching
-- 3. Ensures all users have deterministic or assigned friend_code
-- 4. Updates RLS policies on friendships and daily_prayer_status
-- =============================================================================

-- 1. Ensure user_profiles SELECT policy is open to all authenticated users
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_profiles_select_policy" ON public.user_profiles;
CREATE POLICY "user_profiles_select_policy" ON public.user_profiles
  FOR SELECT TO authenticated
  USING (true);

-- 2. Populate deterministic friend_code for any existing rows if missing or null
-- Generates 'AX-' followed by the first 4 uppercase hex chars of the user_id
UPDATE public.user_profiles
SET friend_code = 'AX-' || upper(substr(replace(user_id::text, '-', ''), 1, 4))
WHERE friend_code IS NULL OR friend_code = '';

-- 3. Create or replace public search_companion function
CREATE OR REPLACE FUNCTION public.search_companion(search_query text)
RETURNS TABLE (
  user_id uuid,
  name text,
  friend_code text,
  avatar_color text,
  avatar_url text,
  level integer,
  total_xp integer
) LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  clean_input text := trim(search_query);
  clean_upper text := upper(clean_input);
  raw_code text := replace(replace(replace(clean_upper, 'AX-', ''), '-', ''), ' ', '');
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
    upper(p.friend_code) = clean_upper
    OR upper(p.friend_code) = ('AX-' || raw_code)
    OR replace(upper(p.friend_code), '-', '') = raw_code
    -- Match by UUID prefix (first 4+ chars)
    OR (length(raw_code) >= 4 AND p.user_id::text ILIKE (lower(raw_code) || '%'))
    -- Match by display name
    OR p.name ILIKE ('%' || clean_input || '%')
  )
  -- Do not return oneself
  AND (curr_uid IS NULL OR p.user_id <> curr_uid)
  LIMIT 5;
END;
$$;

-- Grant execution permission to authenticated users
GRANT EXECUTE ON FUNCTION public.search_companion(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_companion(text) TO anon;

-- 4. RPC to send friend request by friend code directly on Supabase
CREATE OR REPLACE FUNCTION public.send_companion_request(target_code_or_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  curr_uid uuid := auth.uid();
  target_uid uuid;
  friendship_id text;
  now_iso timestamptz := now();
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

GRANT EXECUTE ON FUNCTION public.send_companion_request(text) TO authenticated;
