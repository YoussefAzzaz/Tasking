-- 20261114203000_collaborative_tasks_bidirectional_sync.sql
-- Fixes collaborative task acceptance & bidirectional real-time sync:
-- 1. Preserves & propagates the original sender's @username tag onto collaborative tasks.
-- 2. Prevents early-return gaps when accepted_entity_id was pre-written locally.
-- 3. Fires collaborative sync on INSERT OR UPDATE and upserts missing partner rows.
-- 4. Provides atomic SECURITY DEFINER sync_collaborative_task_rpc for immediate 2-way updates.

-- Helper: Merge sender username into comma-separated tags without duplicates
CREATE OR REPLACE FUNCTION public.merge_share_sender_tag(
  p_tags text,
  p_sender_name text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_clean_sender text;
  v_parts text[];
  v_elem text;
  v_out text[] := ARRAY[]::text[];
  v_has_sender boolean := false;
BEGIN
  v_clean_sender := NULLIF(regexp_replace(trim(COALESCE(p_sender_name, '')), '^@+', ''), '');
  IF p_tags IS NOT NULL AND trim(p_tags) <> '' THEN
    v_parts := string_to_array(p_tags, ',');
    FOREACH v_elem IN ARRAY v_parts LOOP
      v_elem := trim(v_elem);
      IF v_elem <> '' THEN
        v_out := array_append(v_out, v_elem);
        IF v_clean_sender IS NOT NULL
           AND lower(regexp_replace(v_elem, '^@+', '')) = lower(v_clean_sender) THEN
          v_has_sender := true;
        END IF;
      END IF;
    END LOOP;
  END IF;

  IF v_clean_sender IS NOT NULL AND NOT v_has_sender THEN
    v_out := array_append(v_out, v_clean_sender);
  END IF;

  IF array_length(v_out, 1) IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN array_to_string(v_out, ',');
END;
$$;

GRANT EXECUTE ON FUNCTION public.merge_share_sender_tag(text, text) TO authenticated, service_role;

-- 1. Replace accept_companion_share with sender username tagging, missing partner task creation,
-- and idempotency that verifies the target row actually exists remotely.
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
  v_sender_name text;
  v_recipient_name text;
  v_item_title text;
  v_tags_text text;
  v_task_status text;
  v_priority integer;
  v_rec_mode text;
  v_now_iso text;
  v_target_exists boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_share
  FROM public.companion_shares
  WHERE id = p_share_id
    AND recipient_id = v_uid
    AND status IN ('pending', 'accepted')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Share request not found or already processed';
  END IF;

  BEGIN
    v_preview := v_share.preview_data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    v_preview := '{}'::jsonb;
  END;

  SELECT NULLIF(trim(name), '') INTO v_sender_name
  FROM public.user_profiles
  WHERE user_id = v_share.sender_id
  LIMIT 1;

  v_sender_name := COALESCE(
    v_sender_name,
    NULLIF(trim(v_preview->>'sender_name'), ''),
    'Companion'
  );

  v_new_id := COALESCE(
    NULLIF(trim(p_cloned_id), ''),
    NULLIF(trim(v_share.accepted_entity_id), ''),
    gen_random_uuid()::text
  );

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

  v_now_iso := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');

  IF v_share.entity_type = 'task' THEN
    v_tags_text := public.merge_share_sender_tag(v_tags_text, v_sender_name);
    v_task_status := CASE
      WHEN v_preview->>'status' IN ('todo', 'done', 'cancelled') THEN v_preview->>'status'
      WHEN v_preview->>'status' = 'skipped' THEN 'done'
      ELSE 'todo'
    END;
    v_priority := LEAST(GREATEST(COALESCE((v_preview->>'priority')::numeric::integer, 0), 0), 3);
    v_rec_mode := CASE
      WHEN v_preview->>'recurrence_mode' IN ('fixed', 'after_completion') THEN v_preview->>'recurrence_mode'
      ELSE 'fixed'
    END;

    SELECT EXISTS(
      SELECT 1 FROM public.tasks WHERE id = v_new_id AND deleted_at IS NULL
    ) INTO v_target_exists;

    IF v_target_exists THEN
      UPDATE public.tasks
      SET tags = public.merge_share_sender_tag(tags, v_sender_name),
          updated_at = now()
      WHERE id = v_new_id
        AND deleted_at IS NULL
        AND tags IS DISTINCT FROM public.merge_share_sender_tag(tags, v_sender_name);
    ELSE
      INSERT INTO public.tasks (
        id, user_id, title, notes, status, priority,
        project_id, tags, due_date, due_time, estimate_min,
        recurrence_rule, recurrence_mode, created_at, updated_at
      ) VALUES (
        v_new_id,
        v_uid,
        v_item_title,
        v_preview->>'notes',
        v_task_status,
        v_priority,
        NULL,
        v_tags_text,
        NULLIF(v_preview->>'due_date', ''),
        NULLIF(v_preview->>'due_time', ''),
        (v_preview->>'estimate_min')::numeric::integer,
        NULLIF(v_preview->>'recurrence_rule', ''),
        v_rec_mode,
        now(),
        now()
      )
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        notes = EXCLUDED.notes,
        status = EXCLUDED.status,
        priority = EXCLUDED.priority,
        tags = EXCLUDED.tags,
        due_date = EXCLUDED.due_date,
        due_time = EXCLUDED.due_time,
        estimate_min = EXCLUDED.estimate_min,
        recurrence_rule = EXCLUDED.recurrence_rule,
        recurrence_mode = EXCLUDED.recurrence_mode,
        updated_at = now();
    END IF;

    -- For collaborative tasks, guarantee sender's original row also exists & has sender tag
    IF v_share.share_mode = 'collaborate' THEN
      INSERT INTO public.tasks (
        id, user_id, title, notes, status, priority,
        project_id, tags, due_date, due_time, estimate_min,
        recurrence_rule, recurrence_mode, created_at, updated_at
      ) VALUES (
        v_share.entity_id,
        v_share.sender_id,
        v_item_title,
        v_preview->>'notes',
        v_task_status,
        v_priority,
        NULL,
        v_tags_text,
        NULLIF(v_preview->>'due_date', ''),
        NULLIF(v_preview->>'due_time', ''),
        (v_preview->>'estimate_min')::numeric::integer,
        NULLIF(v_preview->>'recurrence_rule', ''),
        v_rec_mode,
        COALESCE(v_share.created_at, now()),
        now()
      )
      ON CONFLICT (id) DO UPDATE SET
        tags = public.merge_share_sender_tag(public.tasks.tags, v_sender_name),
        updated_at = now()
      WHERE public.tasks.deleted_at IS NULL
        AND public.tasks.tags IS DISTINCT FROM public.merge_share_sender_tag(public.tasks.tags, v_sender_name);
    END IF;

    v_preview := v_preview || jsonb_build_object(
      'sender_id', v_share.sender_id::text,
      'sender_name', v_sender_name,
      'status', v_task_status,
      'tags', v_tags_text,
      'task_updated_at', v_now_iso
    );

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

  UPDATE public.companion_shares
  SET status = 'accepted',
      accepted_entity_id = v_new_id,
      preview_data = v_preview::text,
      updated_at = now()
  WHERE id = p_share_id;

  IF v_share.status = 'pending' THEN
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
  END IF;

  RETURN v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_companion_share(text, text) TO authenticated, service_role;

-- 2. Upgrade collaborative task trigger to AFTER INSERT OR UPDATE + upsert partner row + preview_data sync
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
  v_sender_name text;
  v_actor_name text;
  v_merged_tags text;
  v_preview jsonb;
  v_now_iso text;
BEGIN
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND NOT (
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

  v_now_iso := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');

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

    BEGIN
      v_preview := v_share.preview_data::jsonb;
    EXCEPTION WHEN OTHERS THEN
      v_preview := '{}'::jsonb;
    END;

    SELECT NULLIF(trim(name), '') INTO v_sender_name
    FROM public.user_profiles
    WHERE user_id = v_share.sender_id
    LIMIT 1;

    v_sender_name := COALESCE(
      v_sender_name,
      NULLIF(trim(v_preview->>'sender_name'), ''),
      'Companion'
    );

    v_merged_tags := public.merge_share_sender_tag(NEW.tags, v_sender_name);

    -- Ensure sender tag exists on the edited row if missing (trigger depth prevents recursion)
    IF v_merged_tags IS DISTINCT FROM NEW.tags THEN
      UPDATE public.tasks
      SET tags = v_merged_tags,
          updated_at = now()
      WHERE id = NEW.id AND deleted_at IS NULL;
    END IF;

    -- Upsert counterpart task row so missing rows self-heal cleanly
    INSERT INTO public.tasks (
      id, user_id, title, notes, status, priority,
      project_id, tags, due_date, due_time, estimate_min,
      recurrence_rule, recurrence_mode, completed_at, created_at, updated_at
    ) VALUES (
      v_partner_task_id,
      v_partner_user_id,
      NEW.title,
      NEW.notes,
      NEW.status,
      COALESCE(NEW.priority, 0),
      NULL,
      v_merged_tags,
      NEW.due_date,
      NEW.due_time,
      NEW.estimate_min,
      NEW.recurrence_rule,
      NEW.recurrence_mode,
      NEW.completed_at,
      COALESCE(NEW.created_at, now()),
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      notes = EXCLUDED.notes,
      status = EXCLUDED.status,
      priority = EXCLUDED.priority,
      tags = EXCLUDED.tags,
      due_date = EXCLUDED.due_date,
      due_time = EXCLUDED.due_time,
      estimate_min = EXCLUDED.estimate_min,
      recurrence_rule = EXCLUDED.recurrence_rule,
      recurrence_mode = EXCLUDED.recurrence_mode,
      completed_at = EXCLUDED.completed_at,
      updated_at = now()
    WHERE public.tasks.deleted_at IS NULL;

    v_preview := v_preview || jsonb_build_object(
      'sender_id', v_share.sender_id::text,
      'sender_name', v_sender_name,
      'title', NEW.title,
      'notes', NEW.notes,
      'status', NEW.status,
      'priority', COALESCE(NEW.priority, 0),
      'tags', v_merged_tags,
      'due_date', NEW.due_date,
      'due_time', NEW.due_time,
      'estimate_min', NEW.estimate_min,
      'recurrence_rule', NEW.recurrence_rule,
      'recurrence_mode', NEW.recurrence_mode,
      'task_updated_at', v_now_iso
    );

    UPDATE public.companion_shares
    SET preview_data = v_preview::text,
        updated_at = now()
    WHERE id = v_share.id;

    IF (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'done') AND NEW.status = 'done' THEN
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
  AFTER INSERT OR UPDATE ON public.tasks
  FOR EACH ROW
  WHEN (pg_trigger_depth() < 1)
  EXECUTE FUNCTION public.sync_collaborative_task();

-- 3. Atomic SECURITY DEFINER RPC for direct two-way task synchronization
DROP FUNCTION IF EXISTS public.sync_collaborative_task_rpc(text, text, text, text, integer, text, text, text, integer, text, text);

CREATE OR REPLACE FUNCTION public.sync_collaborative_task_rpc(
  p_task_id text,
  p_title text,
  p_notes text DEFAULT NULL,
  p_status text DEFAULT 'todo',
  p_priority integer DEFAULT 0,
  p_tags text DEFAULT NULL,
  p_due_date text DEFAULT NULL,
  p_due_time text DEFAULT NULL,
  p_estimate_min integer DEFAULT NULL,
  p_recurrence_rule text DEFAULT NULL,
  p_recurrence_mode text DEFAULT 'fixed'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_share RECORD;
  v_sender_name text;
  v_merged_tags text;
  v_clean_status text;
  v_clean_priority integer;
  v_clean_rec_mode text;
  v_completed_at timestamptz;
  v_preview jsonb;
  v_now_iso text;
  v_synced boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  v_clean_status := CASE
    WHEN p_status IN ('todo', 'done', 'cancelled') THEN p_status
    WHEN p_status = 'skipped' THEN 'done'
    ELSE 'todo'
  END;
  v_clean_priority := LEAST(GREATEST(COALESCE(p_priority, 0), 0), 3);
  v_clean_rec_mode := CASE
    WHEN p_recurrence_mode IN ('fixed', 'after_completion') THEN p_recurrence_mode
    ELSE 'fixed'
  END;
  v_completed_at := CASE WHEN v_clean_status = 'done' THEN now() ELSE NULL END;
  v_now_iso := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');

  FOR v_share IN
    SELECT *
    FROM public.companion_shares
    WHERE entity_type = 'task'
      AND share_mode = 'collaborate'
      AND status IN ('accepted', 'pending')
      AND (entity_id = p_task_id OR accepted_entity_id = p_task_id)
      AND (sender_id = v_uid OR recipient_id = v_uid)
    FOR UPDATE
  LOOP
    v_synced := true;

    BEGIN
      v_preview := v_share.preview_data::jsonb;
    EXCEPTION WHEN OTHERS THEN
      v_preview := '{}'::jsonb;
    END;

    SELECT NULLIF(trim(name), '') INTO v_sender_name
    FROM public.user_profiles
    WHERE user_id = v_share.sender_id
    LIMIT 1;

    v_sender_name := COALESCE(
      v_sender_name,
      NULLIF(trim(v_preview->>'sender_name'), ''),
      'Companion'
    );

    v_merged_tags := public.merge_share_sender_tag(p_tags, v_sender_name);

    -- Upsert sender task row
    INSERT INTO public.tasks (
      id, user_id, title, notes, status, priority,
      project_id, tags, due_date, due_time, estimate_min,
      recurrence_rule, recurrence_mode, completed_at, created_at, updated_at
    ) VALUES (
      v_share.entity_id,
      v_share.sender_id,
      COALESCE(NULLIF(trim(p_title), ''), 'Shared Task'),
      p_notes,
      v_clean_status,
      v_clean_priority,
      NULL,
      v_merged_tags,
      NULLIF(trim(COALESCE(p_due_date, '')), ''),
      NULLIF(trim(COALESCE(p_due_time, '')), ''),
      p_estimate_min,
      NULLIF(trim(COALESCE(p_recurrence_rule, '')), ''),
      v_clean_rec_mode,
      v_completed_at,
      COALESCE(v_share.created_at, now()),
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      notes = EXCLUDED.notes,
      status = EXCLUDED.status,
      priority = EXCLUDED.priority,
      tags = EXCLUDED.tags,
      due_date = EXCLUDED.due_date,
      due_time = EXCLUDED.due_time,
      estimate_min = EXCLUDED.estimate_min,
      recurrence_rule = EXCLUDED.recurrence_rule,
      recurrence_mode = EXCLUDED.recurrence_mode,
      completed_at = EXCLUDED.completed_at,
      updated_at = now()
    WHERE public.tasks.deleted_at IS NULL;

    -- Upsert recipient task row if accepted
    IF v_share.accepted_entity_id IS NOT NULL AND v_share.accepted_entity_id <> '' THEN
      INSERT INTO public.tasks (
        id, user_id, title, notes, status, priority,
        project_id, tags, due_date, due_time, estimate_min,
        recurrence_rule, recurrence_mode, completed_at, created_at, updated_at
      ) VALUES (
        v_share.accepted_entity_id,
        v_share.recipient_id,
        COALESCE(NULLIF(trim(p_title), ''), 'Shared Task'),
        p_notes,
        v_clean_status,
        v_clean_priority,
        NULL,
        v_merged_tags,
        NULLIF(trim(COALESCE(p_due_date, '')), ''),
        NULLIF(trim(COALESCE(p_due_time, '')), ''),
        p_estimate_min,
        NULLIF(trim(COALESCE(p_recurrence_rule, '')), ''),
        v_clean_rec_mode,
        v_completed_at,
        COALESCE(v_share.created_at, now()),
        now()
      )
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        notes = EXCLUDED.notes,
        status = EXCLUDED.status,
        priority = EXCLUDED.priority,
        tags = EXCLUDED.tags,
        due_date = EXCLUDED.due_date,
        due_time = EXCLUDED.due_time,
        estimate_min = EXCLUDED.estimate_min,
        recurrence_rule = EXCLUDED.recurrence_rule,
        recurrence_mode = EXCLUDED.recurrence_mode,
        completed_at = EXCLUDED.completed_at,
        updated_at = now()
      WHERE public.tasks.deleted_at IS NULL;
    END IF;

    v_preview := v_preview || jsonb_build_object(
      'sender_id', v_share.sender_id::text,
      'sender_name', v_sender_name,
      'title', COALESCE(NULLIF(trim(p_title), ''), 'Shared Task'),
      'notes', p_notes,
      'status', v_clean_status,
      'priority', v_clean_priority,
      'tags', v_merged_tags,
      'due_date', NULLIF(trim(COALESCE(p_due_date, '')), ''),
      'due_time', NULLIF(trim(COALESCE(p_due_time, '')), ''),
      'estimate_min', p_estimate_min,
      'recurrence_rule', NULLIF(trim(COALESCE(p_recurrence_rule, '')), ''),
      'recurrence_mode', v_clean_rec_mode,
      'task_updated_at', v_now_iso
    );

    UPDATE public.companion_shares
    SET preview_data = v_preview::text,
        updated_at = now()
    WHERE id = v_share.id;
  END LOOP;

  RETURN v_synced;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_collaborative_task_rpc(
  text, text, text, text, integer, text, text, text, integer, text, text
) TO authenticated, service_role;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
