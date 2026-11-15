-- =============================================================================
-- AXIS: Fix Companion Sharing Bugs & Add Collaborative Real-Time Sync
-- Covers Tasks, Habits, Notes, and Projects:
-- 1. Adds accepted_entity_id to companion_shares for two-way collaborative linking
-- 2. Drops legacy habits_kind_check constraint if present so category names sync
-- 3. Grants explicit table permissions & ensures publications + REPLICA IDENTITY FULL
-- 4. Fixes accept_companion_share(text, text) type mismatches & idempotency
-- 5. Adds collaborative sync triggers on tasks, habits, and notes
-- =============================================================================

-- 1. Schema Adjustments
ALTER TABLE public.companion_shares
  ADD COLUMN IF NOT EXISTS accepted_entity_id text;

CREATE INDEX IF NOT EXISTS idx_companion_shares_entity
  ON public.companion_shares(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_companion_shares_accepted_entity
  ON public.companion_shares(entity_type, accepted_entity_id);

-- Drop restrictive legacy check on habits.kind so category strings never fail
ALTER TABLE public.habits
  DROP CONSTRAINT IF EXISTS habits_kind_check;

-- 2. Table Permissions & Publications
GRANT ALL ON TABLE public.companion_shares TO authenticated, service_role, postgres;
GRANT SELECT ON TABLE public.companion_shares TO anon;

DO $$
DECLARE
  r RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_role') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO powersync_role';
    EXECUTE 'GRANT SELECT ON TABLE public.companion_shares TO powersync_role';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA public TO powersync';
    EXECUTE 'GRANT SELECT ON TABLE public.companion_shares TO powersync';
  END IF;

  FOR r IN (
    SELECT rolname FROM pg_roles
    WHERE rolname LIKE '%powersync%' OR rolreplication = true
  ) LOOP
    BEGIN
      EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', r.rolname);
      EXECUTE format('GRANT SELECT ON TABLE public.companion_shares TO %I', r.rolname);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END $$;

ALTER TABLE public.companion_shares REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    BEGIN
      ALTER PUBLICATION powersync ADD TABLE public.companion_shares;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync_axis') THEN
    BEGIN
      ALTER PUBLICATION powersync_axis ADD TABLE public.companion_shares;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.companion_shares;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- 3. Replace accept_companion_share RPC with fixed types, deterministic ID, and idempotency
DROP FUNCTION IF EXISTS public.accept_companion_share(text);
DROP FUNCTION IF EXISTS public.accept_companion_share(text, text);

CREATE OR REPLACE FUNCTION public.accept_companion_share(
  p_share_id text,
  p_cloned_id text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_share record;
  v_new_id text;
  v_preview jsonb;
  v_recipient_name text;
  v_item_title text;
  v_tags_text text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Lock & validate share belonging to authenticated recipient
  SELECT * INTO v_share
  FROM public.companion_shares
  WHERE id = p_share_id
    AND recipient_id = v_uid
    AND status IN ('pending', 'accepted')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Share request not found or already processed';
  END IF;

  -- Idempotent return if already cloned
  IF v_share.accepted_entity_id IS NOT NULL AND v_share.accepted_entity_id <> '' THEN
    UPDATE public.companion_shares
    SET status = 'accepted', updated_at = now()
    WHERE id = p_share_id AND status <> 'accepted';
    RETURN v_share.accepted_entity_id;
  END IF;

  v_new_id := COALESCE(NULLIF(trim(p_cloned_id), ''), gen_random_uuid()::text);

  BEGIN
    v_preview := v_share.preview_data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    v_preview := '{}'::jsonb;
  END;

  IF jsonb_typeof(v_preview->'tags') = 'array' THEN
    SELECT string_agg(elem, ',') INTO v_tags_text
    FROM jsonb_array_elements_text(v_preview->'tags') AS elem;
  ELSE
    v_tags_text := NULLIF(v_preview->>'tags', '');
  END IF;

  v_item_title := COALESCE(
    NULLIF(v_preview->>'title', ''),
    NULLIF(v_preview->>'name', ''),
    'Shared Item'
  );

  -- Clone entity based on entity_type (respecting uuid user_id & boolean types)
  IF v_share.entity_type = 'task' THEN
    INSERT INTO public.tasks (
      id, user_id, title, notes, status, priority,
      project_id, tags, due_date, due_time, estimate_min,
      recurrence_rule, recurrence_mode, created_at, updated_at
    ) VALUES (
      v_new_id,
      v_uid,
      COALESCE(NULLIF(v_preview->>'title', ''), 'Shared Task'),
      v_preview->>'notes',
      'todo',
      LEAST(GREATEST(COALESCE((v_preview->>'priority')::numeric::integer, 0), 0), 3),
      NULL,
      v_tags_text,
      NULLIF(v_preview->>'due_date', ''),
      NULLIF(v_preview->>'due_time', ''),
      (v_preview->>'estimate_min')::numeric::integer,
      NULLIF(v_preview->>'recurrence_rule', ''),
      CASE
        WHEN v_preview->>'recurrence_mode' IN ('fixed', 'after_completion')
          THEN v_preview->>'recurrence_mode'
        ELSE 'fixed'
      END,
      now(),
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      updated_at = now();

  ELSIF v_share.entity_type = 'habit' THEN
    INSERT INTO public.habits (
      id, user_id, name, icon, color, kind, target_value, unit,
      schedule_type, remind_time, sort_order, is_enabled, created_at, updated_at
    ) VALUES (
      v_new_id,
      v_uid,
      COALESCE(NULLIF(v_preview->>'title', ''), NULLIF(v_preview->>'name', ''), 'Shared Habit'),
      COALESCE(NULLIF(v_preview->>'icon', ''), 'fitness'),
      COALESCE(NULLIF(v_preview->>'color', ''), '#10B981'),
      COALESCE(NULLIF(v_preview->>'kind', ''), 'boolean'),
      COALESCE((v_preview->>'target_value')::numeric::integer, 20),
      COALESCE(NULLIF(v_preview->>'unit', ''), 'times'),
      COALESCE(NULLIF(v_preview->>'schedule_type', ''), 'daily'),
      NULLIF(v_preview->>'remind_time', ''),
      999,
      true,
      now(),
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      updated_at = now();

  ELSIF v_share.entity_type = 'note' THEN
    INSERT INTO public.notes (
      id, user_id, title, body_md, pinned, category, mood, energy, created_at, updated_at
    ) VALUES (
      v_new_id,
      v_uid,
      COALESCE(NULLIF(v_preview->>'title', ''), 'Shared Note'),
      COALESCE(v_preview->>'body_md', v_preview->>'notes', ''),
      false,
      COALESCE(NULLIF(v_preview->>'category', ''), 'General'),
      NULLIF(v_preview->>'mood', ''),
      NULLIF(v_preview->>'energy', ''),
      now(),
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      body_md = EXCLUDED.body_md,
      updated_at = now();

  ELSIF v_share.entity_type = 'project' THEN
    INSERT INTO public.projects (
      id, user_id, name, color, created_at, updated_at
    ) VALUES (
      v_new_id,
      v_uid,
      COALESCE(NULLIF(v_preview->>'title', ''), NULLIF(v_preview->>'name', ''), 'Shared Project'),
      COALESCE(NULLIF(v_preview->>'color', ''), '#6366F1'),
      now(),
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      updated_at = now();
  END IF;

  -- Link cloned entity and mark accepted
  UPDATE public.companion_shares
  SET status = 'accepted',
      accepted_entity_id = v_new_id,
      updated_at = now()
  WHERE id = p_share_id;

  -- Notify sender in friend_activity_logs
  BEGIN
    SELECT COALESCE(name, 'A companion') INTO v_recipient_name
    FROM public.user_profiles
    WHERE user_id = v_uid;

    INSERT INTO public.friend_activity_logs (
      id, user_id, event_type, title, metadata, created_at
    ) VALUES (
      gen_random_uuid()::text,
      v_share.sender_id,
      'shared_item_accepted',
      COALESCE(v_recipient_name, 'A companion') || ' accepted your shared ' || v_share.entity_type || ': ' || v_item_title,
      jsonb_build_object(
        'share_id', p_share_id,
        'entity_type', v_share.entity_type,
        'new_id', v_new_id,
        'accepted_by', v_uid::text,
        'sender_id', v_uid::text
      ),
      now()
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_companion_share(text, text) TO authenticated, service_role;

-- 4. Collaborative Real-Time Sync Triggers (share_mode = 'collaborate')
-- Uses pg_trigger_depth() < 1 to guarantee single-hop propagation without recursion.

CREATE OR REPLACE FUNCTION public.sync_collaborative_task()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_share RECORD;
  v_partner_task_id text;
  v_partner_user_id uuid;
  v_actor_name text;
BEGIN
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NOT (
    NEW.title IS DISTINCT FROM OLD.title OR
    NEW.notes IS DISTINCT FROM OLD.notes OR
    NEW.status IS DISTINCT FROM OLD.status OR
    NEW.priority IS DISTINCT FROM OLD.priority OR
    NEW.tags IS DISTINCT FROM OLD.tags OR
    NEW.due_date IS DISTINCT FROM OLD.due_date OR
    NEW.due_time IS DISTINCT FROM OLD.due_time OR
    NEW.estimate_min IS DISTINCT FROM OLD.estimate_min OR
    NEW.recurrence_rule IS DISTINCT FROM OLD.recurrence_rule OR
    NEW.recurrence_mode IS DISTINCT FROM OLD.recurrence_mode OR
    NEW.completed_at IS DISTINCT FROM OLD.completed_at
  ) THEN
    RETURN NEW;
  END IF;

  FOR v_share IN
    SELECT *
    FROM public.companion_shares
    WHERE entity_type = 'task'
      AND share_mode = 'collaborate'
      AND status = 'accepted'
      AND accepted_entity_id IS NOT NULL
      AND (entity_id = NEW.id OR accepted_entity_id = NEW.id)
  LOOP
    IF v_share.entity_id = NEW.id THEN
      v_partner_task_id := v_share.accepted_entity_id;
      v_partner_user_id := v_share.recipient_id;
    ELSE
      v_partner_task_id := v_share.entity_id;
      v_partner_user_id := v_share.sender_id;
    END IF;

    UPDATE public.tasks
    SET title = NEW.title,
        notes = NEW.notes,
        status = NEW.status,
        priority = NEW.priority,
        tags = NEW.tags,
        due_date = NEW.due_date,
        due_time = NEW.due_time,
        estimate_min = NEW.estimate_min,
        recurrence_rule = NEW.recurrence_rule,
        recurrence_mode = NEW.recurrence_mode,
        completed_at = NEW.completed_at,
        updated_at = now()
    WHERE id = v_partner_task_id
      AND deleted_at IS NULL;

    IF OLD.status IS DISTINCT FROM 'done' AND NEW.status = 'done' THEN
      BEGIN
        SELECT COALESCE(name, 'Companion') INTO v_actor_name
        FROM public.user_profiles
        WHERE user_id = NEW.user_id;

        INSERT INTO public.friend_activity_logs (
          id, user_id, event_type, title, metadata, created_at
        ) VALUES (
          gen_random_uuid()::text,
          v_partner_user_id,
          'collaborative_task_completed',
          COALESCE(v_actor_name, 'Companion') || ' completed shared task: ' || NEW.title,
          jsonb_build_object(
            'share_id', v_share.id,
            'entity_type', 'task',
            'task_id', v_partner_task_id,
            'sender_id', NEW.user_id::text
          ),
          now()
        );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_collaborative_task ON public.tasks;
CREATE TRIGGER trg_sync_collaborative_task
  AFTER UPDATE ON public.tasks
  FOR EACH ROW
  WHEN (pg_trigger_depth() < 1)
  EXECUTE FUNCTION public.sync_collaborative_task();

CREATE OR REPLACE FUNCTION public.sync_collaborative_habit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_share RECORD;
  v_partner_habit_id text;
BEGIN
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NOT (
    NEW.name IS DISTINCT FROM OLD.name OR
    NEW.icon IS DISTINCT FROM OLD.icon OR
    NEW.color IS DISTINCT FROM OLD.color OR
    NEW.kind IS DISTINCT FROM OLD.kind OR
    NEW.target_value IS DISTINCT FROM OLD.target_value OR
    NEW.schedule_type IS DISTINCT FROM OLD.schedule_type OR
    NEW.remind_time IS DISTINCT FROM OLD.remind_time
  ) THEN
    RETURN NEW;
  END IF;

  FOR v_share IN
    SELECT *
    FROM public.companion_shares
    WHERE entity_type = 'habit'
      AND share_mode = 'collaborate'
      AND status = 'accepted'
      AND accepted_entity_id IS NOT NULL
      AND (entity_id = NEW.id OR accepted_entity_id = NEW.id)
  LOOP
    IF v_share.entity_id = NEW.id THEN
      v_partner_habit_id := v_share.accepted_entity_id;
    ELSE
      v_partner_habit_id := v_share.entity_id;
    END IF;

    UPDATE public.habits
    SET name = NEW.name,
        icon = NEW.icon,
        color = NEW.color,
        kind = NEW.kind,
        target_value = NEW.target_value,
        schedule_type = NEW.schedule_type,
        remind_time = NEW.remind_time,
        updated_at = now()
    WHERE id = v_partner_habit_id
      AND deleted_at IS NULL;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_collaborative_habit ON public.habits;
CREATE TRIGGER trg_sync_collaborative_habit
  AFTER UPDATE ON public.habits
  FOR EACH ROW
  WHEN (pg_trigger_depth() < 1)
  EXECUTE FUNCTION public.sync_collaborative_habit();

CREATE OR REPLACE FUNCTION public.sync_collaborative_note()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_share RECORD;
  v_partner_note_id text;
BEGIN
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NOT (
    NEW.title IS DISTINCT FROM OLD.title OR
    NEW.body_md IS DISTINCT FROM OLD.body_md OR
    NEW.category IS DISTINCT FROM OLD.category OR
    NEW.mood IS DISTINCT FROM OLD.mood OR
    NEW.energy IS DISTINCT FROM OLD.energy
  ) THEN
    RETURN NEW;
  END IF;

  FOR v_share IN
    SELECT *
    FROM public.companion_shares
    WHERE entity_type = 'note'
      AND share_mode = 'collaborate'
      AND status = 'accepted'
      AND accepted_entity_id IS NOT NULL
      AND (entity_id = NEW.id OR accepted_entity_id = NEW.id)
  LOOP
    IF v_share.entity_id = NEW.id THEN
      v_partner_note_id := v_share.accepted_entity_id;
    ELSE
      v_partner_note_id := v_share.entity_id;
    END IF;

    UPDATE public.notes
    SET title = NEW.title,
        body_md = NEW.body_md,
        category = NEW.category,
        mood = NEW.mood,
        energy = NEW.energy,
        updated_at = now()
    WHERE id = v_partner_note_id
      AND deleted_at IS NULL;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_collaborative_note ON public.notes;
CREATE TRIGGER trg_sync_collaborative_note
  AFTER UPDATE ON public.notes
  FOR EACH ROW
  WHEN (pg_trigger_depth() < 1)
  EXECUTE FUNCTION public.sync_collaborative_note();

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
