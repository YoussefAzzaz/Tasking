-- =============================================================================
-- AXIS: Companion Data Sharing & Task Collaboration Migration
-- Enables sharing and copying tasks, habits, notes, and projects between companions.
--
-- Features:
-- 1. companion_shares table with snapshot preview_data and full lifecycle tracking
-- 2. Row Level Security ensuring only sender & recipient can view or mutate shares
-- 3. PowerSync publication & REPLICA IDENTITY FULL for offline-first sync
-- 4. Atomic accept_companion_share RPC for instant server-side cloning when online
-- =============================================================================

-- 1. Companion Shares Table
CREATE TABLE IF NOT EXISTS public.companion_shares (
  id           text PRIMARY KEY,
  sender_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type  text NOT NULL CHECK (entity_type IN ('task', 'habit', 'note', 'project')),
  entity_id    text NOT NULL,
  share_mode   text NOT NULL DEFAULT 'copy' CHECK (share_mode IN ('copy', 'collaborate')),
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  preview_data text NOT NULL, -- JSON-encoded metadata for instant offline preview & local cloning
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (sender_id <> recipient_id)
);

-- Indexes for lightning-fast queries by recipient and sender
CREATE INDEX IF NOT EXISTS idx_companion_shares_recipient ON public.companion_shares(recipient_id, status);
CREATE INDEX IF NOT EXISTS idx_companion_shares_sender ON public.companion_shares(sender_id, status);
CREATE INDEX IF NOT EXISTS idx_companion_shares_entity ON public.companion_shares(entity_type, entity_id);

-- 2. Row Level Security Policies
ALTER TABLE public.companion_shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "companion_shares_select" ON public.companion_shares;
CREATE POLICY "companion_shares_select" ON public.companion_shares
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IN (sender_id, recipient_id));

DROP POLICY IF EXISTS "companion_shares_insert" ON public.companion_shares;
CREATE POLICY "companion_shares_insert" ON public.companion_shares
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = sender_id);

DROP POLICY IF EXISTS "companion_shares_update" ON public.companion_shares;
CREATE POLICY "companion_shares_update" ON public.companion_shares
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) IN (sender_id, recipient_id))
  WITH CHECK ((SELECT auth.uid()) IN (sender_id, recipient_id));

DROP POLICY IF EXISTS "companion_shares_delete" ON public.companion_shares;
CREATE POLICY "companion_shares_delete" ON public.companion_shares
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = sender_id);

-- 3. PowerSync Publication Integration
DO $$
BEGIN
  ALTER PUBLICATION powersync ADD TABLE public.companion_shares;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
  WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.companion_shares REPLICA IDENTITY FULL;

-- 4. Atomic Server-Side Share Acceptance RPC
CREATE OR REPLACE FUNCTION public.accept_companion_share(p_share_id text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_share record;
  v_new_id text := gen_random_uuid()::text;
  v_preview jsonb;
  v_sender_name text;
BEGIN
  -- 1. Find pending share matching ID and caller
  SELECT * INTO v_share
  FROM public.companion_shares
  WHERE id = p_share_id AND recipient_id = (SELECT auth.uid()) AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Share request not found or not in pending state';
  END IF;

  -- Parse JSON preview data
  BEGIN
    v_preview := v_share.preview_data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    v_preview := '{}'::jsonb;
  END;

  -- 2. Clone entity based on type
  IF v_share.entity_type = 'task' THEN
    INSERT INTO public.tasks (
      id, user_id, title, notes, status, priority,
      project_id, tags, due_date, due_time, estimate_min,
      recurrence_rule, recurrence_mode, created_at, updated_at
    ) VALUES (
      v_new_id,
      (SELECT auth.uid())::text,
      COALESCE(v_preview->>'title', 'Shared Task'),
      v_preview->>'notes',
      'todo',
      (v_preview->>'priority')::integer,
      NULL, -- Reset project_id on recipient so it doesn't collide with non-existent foreign projects
      v_preview->>'tags',
      v_preview->>'due_date',
      v_preview->>'due_time',
      (v_preview->>'estimate_min')::integer,
      v_preview->>'recurrence_rule',
      v_preview->>'recurrence_mode',
      now(),
      now()
    );

  ELSIF v_share.entity_type = 'habit' THEN
    INSERT INTO public.habits (
      id, user_id, name, icon, color, kind, target_value, unit,
      schedule_type, remind_time, sort_order, is_enabled, created_at, updated_at
    ) VALUES (
      v_new_id,
      (SELECT auth.uid())::text,
      COALESCE(v_preview->>'name', 'Shared Habit'),
      COALESCE(v_preview->>'icon', 'check_circle'),
      COALESCE(v_preview->>'color', '#10B981'),
      COALESCE(v_preview->>'kind', 'Daily plan'),
      COALESCE((v_preview->>'target_value')::integer, 1),
      COALESCE(v_preview->>'unit', 'times'),
      COALESCE(v_preview->>'schedule_type', 'daily'),
      v_preview->>'remind_time',
      99,
      1,
      now(),
      now()
    );

  ELSIF v_share.entity_type = 'note' THEN
    INSERT INTO public.notes (
      id, user_id, title, body_md, pinned, category, created_at, updated_at
    ) VALUES (
      v_new_id,
      (SELECT auth.uid())::text,
      COALESCE(v_preview->>'title', 'Shared Note'),
      COALESCE(v_preview->>'body_md', ''),
      0,
      v_preview->>'category',
      now(),
      now()
    );

  ELSIF v_share.entity_type = 'project' THEN
    INSERT INTO public.projects (
      id, user_id, name, color, created_at, updated_at
    ) VALUES (
      v_new_id,
      (SELECT auth.uid())::text,
      COALESCE(v_preview->>'name', 'Shared Project'),
      COALESCE(v_preview->>'color', '#6366F1'),
      now(),
      now()
    );
  END IF;

  -- 3. Mark share as accepted
  UPDATE public.companion_shares
  SET status = 'accepted', updated_at = now()
  WHERE id = p_share_id;

  -- 4. Log companion celebration activity if friend_activity_logs exists
  BEGIN
    SELECT COALESCE(name, 'Companion') INTO v_sender_name
    FROM public.user_profiles
    WHERE user_id = v_share.sender_id;

    INSERT INTO public.friend_activity_logs (
      id, user_id, event_type, title, metadata, created_at
    ) VALUES (
      gen_random_uuid()::text,
      (SELECT auth.uid())::text,
      'shared_item_accepted',
      'Accepted ' || v_share.entity_type || ' from ' || COALESCE(v_sender_name, 'a companion'),
      json_build_object(
        'share_id', p_share_id,
        'entity_type', v_share.entity_type,
        'new_id', v_new_id,
        'sender_id', v_share.sender_id::text
      )::text,
      now()
    );
  EXCEPTION WHEN OTHERS THEN
    -- Gentle failure: activity logging is non-blocking
    NULL;
  END;

  RETURN v_new_id;
END;
$$;

