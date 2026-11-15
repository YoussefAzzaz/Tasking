-- 20261115021500_prevent_duplicate_shares_and_tasks.sql
-- 1. Removes duplicate companion_shares and duplicate shared/cloned tasks, habits, and notes.
-- 2. Enforces uniqueness so the same task, habit, or note cannot be actively shared twice
--    between the same two companions (in either direction).
-- 3. Ensures accept_companion_share is idempotent and sync_collaborative_task never
--    resurrects soft-deleted tasks or propagates duplicates.

-- Step A: Clean up existing duplicate companion_shares and duplicate cloned rows
DO $$
DECLARE
  v_dup record;
BEGIN
  CREATE TEMP TABLE _duplicate_shares_to_remove ON COMMIT DROP AS
  WITH ranked AS (
    SELECT
      id,
      sender_id,
      recipient_id,
      entity_type,
      entity_id,
      accepted_entity_id,
      status,
      ROW_NUMBER() OVER (
        PARTITION BY sender_id, recipient_id, entity_type, entity_id
        ORDER BY
          CASE
            WHEN status = 'accepted' THEN 0
            WHEN status = 'pending' THEN 1
            ELSE 2
          END,
          CASE WHEN share_mode = 'collaborate' THEN 0 ELSE 1 END,
          updated_at DESC,
          created_at DESC,
          id DESC
      ) AS rn
    FROM public.companion_shares
  )
  SELECT id, entity_type, accepted_entity_id
  FROM ranked
  WHERE rn > 1;

  -- Remove non-canonical duplicate companion_shares
  DELETE FROM public.companion_shares cs
  USING _duplicate_shares_to_remove d
  WHERE cs.id = d.id;

  -- Remove cloned tasks belonging to removed duplicate shares (unless still referenced)
  DELETE FROM public.tasks t
  USING _duplicate_shares_to_remove d
  WHERE d.entity_type = 'task'
    AND d.accepted_entity_id IS NOT NULL
    AND d.accepted_entity_id <> ''
    AND t.id = d.accepted_entity_id
    AND NOT EXISTS (
      SELECT 1 FROM public.companion_shares cs
      WHERE cs.entity_id = t.id OR cs.accepted_entity_id = t.id
    );

  -- Remove cloned habits belonging to removed duplicate shares
  DELETE FROM public.habits h
  USING _duplicate_shares_to_remove d
  WHERE d.entity_type = 'habit'
    AND d.accepted_entity_id IS NOT NULL
    AND d.accepted_entity_id <> ''
    AND h.id = d.accepted_entity_id
    AND NOT EXISTS (
      SELECT 1 FROM public.companion_shares cs
      WHERE cs.entity_id = h.id OR cs.accepted_entity_id = h.id
    );

  -- Remove cloned notes belonging to removed duplicate shares
  DELETE FROM public.notes n
  USING _duplicate_shares_to_remove d
  WHERE d.entity_type = 'note'
    AND d.accepted_entity_id IS NOT NULL
    AND d.accepted_entity_id <> ''
    AND n.id = d.accepted_entity_id
    AND NOT EXISTS (
      SELECT 1 FROM public.companion_shares cs
      WHERE cs.entity_id = n.id OR cs.accepted_entity_id = n.id
    );

  -- Remove cloned projects belonging to removed duplicate shares
  DELETE FROM public.projects p
  USING _duplicate_shares_to_remove d
  WHERE d.entity_type = 'project'
    AND d.accepted_entity_id IS NOT NULL
    AND d.accepted_entity_id <> ''
    AND p.id = d.accepted_entity_id
    AND NOT EXISTS (
      SELECT 1 FROM public.companion_shares cs
      WHERE cs.entity_id = p.id OR cs.accepted_entity_id = p.id
    );

  -- Cancel accepted task shares whose recipient clone or source task was already soft-deleted
  UPDATE public.companion_shares cs
  SET status = 'cancelled',
      updated_at = now()
  WHERE cs.entity_type = 'task'
    AND cs.status = 'accepted'
    AND (
      EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE t.id = cs.entity_id AND t.deleted_at IS NOT NULL
      )
      OR (
        cs.accepted_entity_id IS NOT NULL
        AND cs.accepted_entity_id <> ''
        AND EXISTS (
          SELECT 1 FROM public.tasks t
          WHERE t.id = cs.accepted_entity_id AND t.deleted_at IS NOT NULL
        )
      )
    );

  -- Remove duplicate active tasks per user with identical normalized title & share state
  -- (preserving any task still actively referenced by a kept share)
  WITH ranked_tasks AS (
    SELECT
      t.id,
      ROW_NUMBER() OVER (
        PARTITION BY t.user_id, lower(trim(t.title)), COALESCE(t.due_date, ''), t.status
        ORDER BY
          CASE WHEN EXISTS (
            SELECT 1 FROM public.companion_shares cs
            WHERE cs.status = 'accepted' AND (cs.entity_id = t.id OR cs.accepted_entity_id = t.id)
          ) THEN 0 ELSE 1 END,
          t.updated_at DESC,
          t.created_at DESC,
          t.id DESC
      ) AS rn
    FROM public.tasks t
    WHERE t.deleted_at IS NULL
  )
  DELETE FROM public.tasks t
  USING ranked_tasks rt
  WHERE t.id = rt.id
    AND rt.rn > 1
    AND NOT EXISTS (
      SELECT 1 FROM public.companion_shares cs
      WHERE cs.status IN ('pending', 'accepted')
        AND (cs.entity_id = t.id OR cs.accepted_entity_id = t.id)
    );
END $$;

-- Step B: Partial unique index enforcing one pending/accepted share per directional pair+item
CREATE UNIQUE INDEX IF NOT EXISTS idx_companion_shares_unique_active_pair
  ON public.companion_shares (sender_id, recipient_id, entity_type, entity_id)
  WHERE status IN ('pending', 'accepted');

-- Step C: Trigger function preventing duplicate active shares in either direction
CREATE OR REPLACE FUNCTION public.prevent_duplicate_companion_share()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status NOT IN ('pending', 'accepted') THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.companion_shares cs
    WHERE cs.id <> NEW.id
      AND cs.entity_type = NEW.entity_type
      AND cs.status IN ('pending', 'accepted')
      AND (
        (
          cs.sender_id = NEW.sender_id
          AND cs.recipient_id = NEW.recipient_id
          AND (
            cs.entity_id = NEW.entity_id
            OR (cs.accepted_entity_id IS NOT NULL AND cs.accepted_entity_id = NEW.entity_id)
          )
        )
        OR (
          cs.sender_id = NEW.recipient_id
          AND cs.recipient_id = NEW.sender_id
          AND (
            cs.entity_id = NEW.entity_id
            OR (cs.accepted_entity_id IS NOT NULL AND cs.accepted_entity_id = NEW.entity_id)
          )
        )
      )
  ) THEN
    RAISE EXCEPTION 'This % has already been shared with this companion.', NEW.entity_type
      USING ERRCODE = '23505';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_companion_share ON public.companion_shares;
CREATE TRIGGER trg_prevent_duplicate_companion_share
  BEFORE INSERT OR UPDATE ON public.companion_shares
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_duplicate_companion_share();

-- Step D: Harden accept_companion_share to reuse existing accepted clone IDs cleanly
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
  v_existing_clone_id text;
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

  -- Reuse existing accepted clone if this pair already has an active accepted share for this entity
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
        deleted_at = NULL,
        updated_at = now();
    END IF;

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
      deleted_at = NULL,
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
      deleted_at = NULL,
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

-- Step E: Harden sync_collaborative_task & sync_collaborative_task_rpc against deleted-task resurrection
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
  -- If task was soft-deleted, propagate deletion & cancel the collaborative share
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

        IF v_partner_task_id IS NOT NULL AND v_partner_task_id <> '' THEN
          UPDATE public.tasks
          SET deleted_at = NEW.deleted_at,
              updated_at = now()
          WHERE id = v_partner_task_id
            AND deleted_at IS NULL;
        END IF;

        UPDATE public.companion_shares
        SET status = 'cancelled',
            updated_at = now()
        WHERE id = v_share.id;
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

    -- Never resurrect a soft-deleted counterpart task
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

    v_merged_tags := public.merge_share_sender_tag(NEW.tags, v_sender_name);

    IF v_merged_tags IS DISTINCT FROM NEW.tags THEN
      UPDATE public.tasks
      SET tags = v_merged_tags,
          updated_at = now()
      WHERE id = NEW.id AND deleted_at IS NULL;
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

NOTIFY pgrst, 'reload schema';
