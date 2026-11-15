-- Separate copy-share attribution from collaborative-task classification,
-- unclassify collaborative tasks on decline or deletion (without deleting partner's task),
-- store sender attribution on habit/note shares, and notify senders when shares are declined.

-- 1. Helper to strip a sender username tag (with or without leading '@') cleanly
CREATE OR REPLACE FUNCTION public.remove_share_sender_tag(
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
  v_part text;
  v_clean_part text;
  v_parts text[] := ARRAY[]::text[];
BEGIN
  v_clean_sender := NULLIF(regexp_replace(trim(COALESCE(p_sender_name, '')), '^@+', ''), '');
  IF p_tags IS NULL OR trim(p_tags) = '' THEN
    RETURN NULL;
  END IF;

  FOREACH v_part IN ARRAY string_to_array(p_tags, ',')
  LOOP
    v_clean_part := trim(v_part);
    IF v_clean_part <> '' THEN
      IF v_clean_sender IS NULL OR lower(regexp_replace(v_clean_part, '^@+', '')) <> lower(v_clean_sender) THEN
        v_parts := array_append(v_parts, v_clean_part);
      END IF;
    END IF;
  END LOOP;

  IF array_length(v_parts, 1) IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN array_to_string(v_parts, ',');
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_share_sender_tag(text, text) TO authenticated, service_role;

-- One-time cleanup: remove stale sender self-tags from sender tasks that are no longer
-- actively linked as an accepted/pending collaborative share (e.g., copy shares or declined/cancelled shares).
UPDATE public.tasks t
SET tags = public.remove_share_sender_tag(t.tags, p.name),
    updated_at = now()
FROM public.user_profiles p
WHERE t.user_id = p.user_id
  AND t.tags IS NOT NULL
  AND t.tags <> ''
  AND p.name IS NOT NULL
  AND trim(p.name) <> ''
  AND EXISTS (
    SELECT 1
    FROM public.companion_shares cs
    WHERE cs.entity_type = 'task'
      AND cs.sender_id = t.user_id
      AND cs.entity_id = t.id
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.companion_shares cs_active
    WHERE cs_active.entity_type = 'task'
      AND cs_active.share_mode = 'collaborate'
      AND cs_active.status IN ('pending', 'accepted')
      AND cs_active.entity_id = t.id
  )
  AND t.tags IS DISTINCT FROM public.remove_share_sender_tag(t.tags, p.name);

-- 2. Update accept_companion_share:
--    - Recipient gets sender tag on cloned task (both copy and collaborate)
--    - Sender's own task does NOT get tagged on copy or collaborate in public.tasks.tags
--    - Habit/Note shares persist sender_id & sender_name in preview_data
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
  v_existing_clone_id text;
  v_preview jsonb;
  v_sender_name text;
  v_recipient_name text;
  v_item_title text;
  v_tags_text text;
  v_recipient_tags text;
  v_sender_tags text;
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

  SELECT NULLIF(trim(cs.accepted_entity_id), '') INTO v_existing_clone_id
  FROM public.companion_shares cs
  WHERE cs.sender_id = v_share.sender_id
    AND cs.recipient_id = v_share.recipient_id
    AND cs.entity_type = v_share.entity_type
    AND cs.entity_id = v_share.entity_id
    AND cs.status = 'accepted'
    AND cs.accepted_entity_id IS NOT NULL
    AND cs.accepted_entity_id <> ''
  ORDER BY cs.updated_at DESC
  LIMIT 1;

  v_new_id := COALESCE(
    NULLIF(trim(v_share.accepted_entity_id), ''),
    v_existing_clone_id,
    NULLIF(trim(p_cloned_id), ''),
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
    v_recipient_tags := public.merge_share_sender_tag(v_tags_text, v_sender_name);
    v_sender_tags := public.remove_share_sender_tag(v_tags_text, v_sender_name);
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
        v_recipient_tags,
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
        deleted_at = NULL,
        updated_at = now();
    END IF;

    -- Ensure sender's task exists remotely for bidirectional collaboration without adding sender tag onto sender's task
    IF v_share.share_mode = 'collaborate'
       AND NOT EXISTS (
         SELECT 1 FROM public.tasks WHERE id = v_share.entity_id AND deleted_at IS NOT NULL
       ) THEN
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
        v_sender_tags,
        NULLIF(v_preview->>'due_date', ''),
        NULLIF(v_preview->>'due_time', ''),
        (v_preview->>'estimate_min')::numeric::integer,
        NULLIF(v_preview->>'recurrence_rule', ''),
        v_rec_mode,
        COALESCE(v_share.created_at, now()),
        now()
      )
      ON CONFLICT (id) DO NOTHING;
    END IF;

    v_preview := v_preview || jsonb_build_object(
      'sender_id', v_share.sender_id::text,
      'sender_name', v_sender_name,
      'status', v_task_status,
      'tags', v_sender_tags,
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
      deleted_at = NULL,
      updated_at = now();

    v_preview := v_preview || jsonb_build_object(
      'sender_id', v_share.sender_id::text,
      'sender_name', v_sender_name
    );

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
      deleted_at = NULL,
      updated_at = now();

    v_preview := v_preview || jsonb_build_object(
      'sender_id', v_share.sender_id::text,
      'sender_name', v_sender_name
    );

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
      deleted_at = NULL,
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

-- 3. Decline RPC + Trigger on companion_shares status transitions:
--    - Strips sender tag from sender's task on declined/cancelled
--    - Inserts shared_item_declined notification into friend_activity_logs for sender_id
CREATE OR REPLACE FUNCTION public.decline_companion_share(
  p_share_id text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_updated integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.companion_shares
  SET status = 'declined',
      updated_at = now()
  WHERE id = p_share_id
    AND recipient_id = v_uid
    AND status IN ('pending', 'declined');

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.decline_companion_share(text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.handle_companion_share_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_preview jsonb;
  v_sender_name text;
  v_recipient_name text;
  v_item_title text;
  v_declined_log_id text;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_preview := NEW.preview_data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    v_preview := '{}'::jsonb;
  END;

  SELECT NULLIF(trim(name), '') INTO v_sender_name
  FROM public.user_profiles
  WHERE user_id = NEW.sender_id
  LIMIT 1;

  v_sender_name := COALESCE(
    v_sender_name,
    NULLIF(trim(v_preview->>'sender_name'), ''),
    'Companion'
  );

  v_item_title := COALESCE(
    NULLIF(trim(v_preview->>'title'), ''),
    NULLIF(trim(v_preview->>'name'), ''),
    'Shared ' || initcap(NEW.entity_type)
  );

  IF NEW.status IN ('declined', 'cancelled') AND NEW.entity_type = 'task' THEN
    UPDATE public.tasks
    SET tags = public.remove_share_sender_tag(tags, v_sender_name),
        updated_at = now()
    WHERE id = NEW.entity_id
      AND tags IS DISTINCT FROM public.remove_share_sender_tag(tags, v_sender_name);
  END IF;

  IF NEW.status = 'declined' AND OLD.status IS DISTINCT FROM 'declined' THEN
    BEGIN
      SELECT NULLIF(trim(name), '') INTO v_recipient_name
      FROM public.user_profiles
      WHERE user_id = NEW.recipient_id
      LIMIT 1;

      v_recipient_name := COALESCE(v_recipient_name, 'A companion');
      v_declined_log_id := regexp_replace(
        md5('share_declined_' || NEW.id),
        '([0-9a-f]{8})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{12})',
        '\1-\2-\3-\4-\5'
      );

      INSERT INTO public.friend_activity_logs (
        id, user_id, event_type, title, metadata, created_at
      ) VALUES (
        v_declined_log_id,
        NEW.sender_id,
        'shared_item_declined',
        v_recipient_name || ' declined your shared ' || NEW.entity_type || ': ' || v_item_title,
        jsonb_build_object(
          'share_id', NEW.id,
          'entity_type', NEW.entity_type,
          'share_mode', NEW.share_mode,
          'title', v_item_title,
          'declined_by', NEW.recipient_id::text,
          'declined_by_name', v_recipient_name,
          'sender_id', NEW.recipient_id::text
        ),
        now()
      )
      ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_handle_companion_share_status_change ON public.companion_shares;
CREATE TRIGGER trg_handle_companion_share_status_change
  AFTER UPDATE ON public.companion_shares
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_companion_share_status_change();

-- 4. Update sync_collaborative_task & sync_collaborative_task_rpc:
--    - Removing a collaborative task cancels the share & unclassifies the surviving partner task
--      WITHOUT soft-deleting the partner's task.
--    - Active collaborative sync keeps sender's task free of self-tags while keeping recipient's tag.
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
  v_sender_tags text;
  v_recipient_tags text;
  v_target_tags text;
  v_preview jsonb;
  v_now_iso text;
BEGIN
  -- If task was soft-deleted, cancel the collaborative share and strip sender tag
  -- from the surviving partner task WITHOUT soft-deleting the partner's task.
  IF NEW.deleted_at IS NOT NULL THEN
    IF TG_OP = 'UPDATE' AND OLD.deleted_at IS NULL THEN
      FOR v_share IN
        SELECT *
        FROM public.companion_shares
        WHERE entity_type = 'task'
          AND share_mode = 'collaborate'
          AND status IN ('accepted', 'pending')
          AND (entity_id = NEW.id OR accepted_entity_id = NEW.id)
      LOOP
        v_partner_task_id := CASE
          WHEN v_share.entity_id = NEW.id THEN v_share.accepted_entity_id
          ELSE v_share.entity_id
        END;

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

        UPDATE public.companion_shares
        SET status = 'cancelled',
            updated_at = now()
        WHERE id = v_share.id;

        IF v_partner_task_id IS NOT NULL AND v_partner_task_id <> '' THEN
          UPDATE public.tasks
          SET tags = public.remove_share_sender_tag(tags, v_sender_name),
              updated_at = now()
          WHERE id = v_partner_task_id
            AND deleted_at IS NULL
            AND tags IS DISTINCT FROM public.remove_share_sender_tag(tags, v_sender_name);
        END IF;
      END LOOP;
    END IF;
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

    IF v_partner_task_id IS NULL OR v_partner_task_id = '' THEN
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.tasks WHERE id = v_partner_task_id AND deleted_at IS NOT NULL
    ) THEN
      CONTINUE;
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

    v_sender_tags := public.remove_share_sender_tag(NEW.tags, v_sender_name);
    v_recipient_tags := public.merge_share_sender_tag(v_sender_tags, v_sender_name);

    IF v_share.entity_id = NEW.id THEN
      -- NEW is sender's task -> ensure sender's task remains free of self-tag; partner gets merged tag
      IF v_sender_tags IS DISTINCT FROM NEW.tags THEN
        UPDATE public.tasks
        SET tags = v_sender_tags,
            updated_at = now()
        WHERE id = NEW.id AND deleted_at IS NULL;
      END IF;
      v_target_tags := v_recipient_tags;
    ELSE
      -- NEW is recipient's task -> recipient keeps merged tag; sender gets clean tags
      IF v_recipient_tags IS DISTINCT FROM NEW.tags THEN
        UPDATE public.tasks
        SET tags = v_recipient_tags,
            updated_at = now()
        WHERE id = NEW.id AND deleted_at IS NULL;
      END IF;
      v_target_tags := v_sender_tags;
    END IF;

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
      v_target_tags,
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
      'tags', v_sender_tags,
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
  v_sender_tags text;
  v_recipient_tags text;
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

    v_sender_tags := public.remove_share_sender_tag(p_tags, v_sender_name);
    v_recipient_tags := public.merge_share_sender_tag(v_sender_tags, v_sender_name);

    IF NOT EXISTS (
      SELECT 1 FROM public.tasks WHERE id = v_share.entity_id AND deleted_at IS NOT NULL
    ) THEN
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
        v_sender_tags,
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

    IF v_share.accepted_entity_id IS NOT NULL
       AND v_share.accepted_entity_id <> ''
       AND NOT EXISTS (
         SELECT 1 FROM public.tasks WHERE id = v_share.accepted_entity_id AND deleted_at IS NOT NULL
       ) THEN
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
        v_recipient_tags,
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
      'tags', v_sender_tags,
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

NOTIFY pgrst, 'reload schema';
