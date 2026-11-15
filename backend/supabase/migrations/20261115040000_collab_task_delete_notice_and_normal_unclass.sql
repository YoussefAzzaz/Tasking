-- Ensure collaborative task deletion preserves the surviving partner's task
-- in normal tasks (stripped of sender/collab tags), marks companion_shares as
-- cancelled with actor metadata, and delivers a collaborative_task_deleted notice.

-- 1. Update handle_companion_share_status_change:
--    - Strip sender tag from both entity_id and accepted_entity_id on collaborative
--      decline/cancel without touching copy-share recipient tags on already-accepted copies
--    - Keep shared_item_declined notification on decline
--    - Also guarantee collaborative_task_deleted notification on collaborative task deletion
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
  v_actor_name text;
  v_cancelled_by_text text;
  v_partner_user_id uuid;
  v_partner_task_id text;
  v_item_title text;
  v_declined_log_id text;
  v_deleted_log_id text;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status
     AND NEW.preview_data IS NOT DISTINCT FROM OLD.preview_data THEN
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
      AND deleted_at IS NULL
      AND tags IS DISTINCT FROM public.remove_share_sender_tag(tags, v_sender_name);

    IF NEW.share_mode = 'collaborate'
       AND NULLIF(trim(COALESCE(NEW.accepted_entity_id, '')), '') IS NOT NULL THEN
      UPDATE public.tasks
      SET tags = public.remove_share_sender_tag(tags, v_sender_name),
          updated_at = now()
      WHERE id = NEW.accepted_entity_id
        AND deleted_at IS NULL
        AND tags IS DISTINCT FROM public.remove_share_sender_tag(tags, v_sender_name);
    END IF;
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

  IF NEW.status = 'cancelled'
     AND NEW.share_mode = 'collaborate'
     AND NEW.entity_type = 'task'
     AND (
       OLD.status = 'accepted'
       OR NULLIF(trim(COALESCE(NEW.accepted_entity_id, '')), '') IS NOT NULL
     )
     AND (
       v_preview->>'cancellation_reason' = 'collaborative_task_deleted'
       OR NULLIF(trim(COALESCE(v_preview->>'cancelled_by', '')), '') IS NOT NULL
     ) THEN
    BEGIN
      v_cancelled_by_text := NULLIF(trim(COALESCE(v_preview->>'cancelled_by', '')), '');
      IF v_cancelled_by_text IS NOT NULL AND v_cancelled_by_text = NEW.sender_id::text THEN
        v_partner_user_id := NEW.recipient_id;
        v_partner_task_id := NULLIF(trim(COALESCE(NEW.accepted_entity_id, '')), '');
      ELSE
        v_partner_user_id := NEW.sender_id;
        v_partner_task_id := NEW.entity_id;
        v_cancelled_by_text := COALESCE(v_cancelled_by_text, NEW.recipient_id::text);
      END IF;

      SELECT NULLIF(trim(name), '') INTO v_actor_name
      FROM public.user_profiles
      WHERE user_id::text = v_cancelled_by_text
      LIMIT 1;

      v_actor_name := COALESCE(
        v_actor_name,
        NULLIF(trim(COALESCE(v_preview->>'cancelled_by_name', '')), ''),
        'A companion'
      );

      v_deleted_log_id := regexp_replace(
        md5('collab_deleted_' || NEW.id),
        '([0-9a-f]{8})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{12})',
        '\1-\2-\3-\4-\5'
      );

      IF v_partner_user_id IS NOT NULL THEN
        INSERT INTO public.friend_activity_logs (
          id, user_id, event_type, title, metadata, created_at
        ) VALUES (
          v_deleted_log_id,
          v_partner_user_id,
          'collaborative_task_deleted',
          v_actor_name || ' deleted collaborative task: ' || v_item_title,
          jsonb_build_object(
            'actor_user_id', v_cancelled_by_text,
            'actor_username', v_actor_name,
            'sender_user_id', NEW.sender_id::text,
            'recipient_user_id', NEW.recipient_id::text,
            'share_id', NEW.id,
            'entity_type', 'task',
            'entity_id', COALESCE(v_partner_task_id, NEW.entity_id),
            'share_mode', NEW.share_mode,
            'item_title', v_item_title,
            'status', 'cancelled',
            'cancellation_reason', 'collaborative_task_deleted',
            'sender_id', v_cancelled_by_text
          ),
          now()
        )
        ON CONFLICT (id) DO NOTHING;
      END IF;
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

-- 2. Update sync_collaborative_task:
--    When a collaborative task is soft-deleted, record cancelled_by + reason in preview_data,
--    unclassify the surviving partner task WITHOUT soft-deleting it, and emit the
--    deterministic collaborative_task_deleted notification to friend_activity_logs.
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
  v_item_title text;
  v_deleted_log_id text;
BEGIN
  v_now_iso := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');

  IF NEW.deleted_at IS NOT NULL THEN
    IF TG_OP = 'UPDATE' AND OLD.deleted_at IS NULL THEN
      SELECT NULLIF(trim(name), '') INTO v_actor_name
      FROM public.user_profiles
      WHERE user_id = NEW.user_id
      LIMIT 1;

      v_actor_name := COALESCE(v_actor_name, 'A companion');

      FOR v_share IN
        SELECT *
        FROM public.companion_shares
        WHERE entity_type = 'task'
          AND share_mode = 'collaborate'
          AND status IN ('accepted', 'pending')
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

        v_item_title := COALESCE(
          NULLIF(trim(NEW.title), ''),
          NULLIF(trim(v_preview->>'title'), ''),
          'Shared Task'
        );

        v_preview := v_preview || jsonb_build_object(
          'sender_id', v_share.sender_id::text,
          'sender_name', v_sender_name,
          'cancelled_by', NEW.user_id::text,
          'cancelled_by_name', v_actor_name,
          'cancellation_reason', 'collaborative_task_deleted',
          'cancelled_at', v_now_iso
        );

        UPDATE public.companion_shares
        SET status = 'cancelled',
            preview_data = v_preview::text,
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

        IF v_partner_user_id IS NOT NULL
           AND (v_share.status = 'accepted'
                OR NULLIF(trim(COALESCE(v_share.accepted_entity_id, '')), '') IS NOT NULL) THEN
          BEGIN
            v_deleted_log_id := regexp_replace(
              md5('collab_deleted_' || v_share.id),
              '([0-9a-f]{8})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{12})',
              '\1-\2-\3-\4-\5'
            );

            INSERT INTO public.friend_activity_logs (
              id, user_id, event_type, title, metadata, created_at
            ) VALUES (
              v_deleted_log_id,
              v_partner_user_id,
              'collaborative_task_deleted',
              v_actor_name || ' deleted collaborative task: ' || v_item_title,
              jsonb_build_object(
                'actor_user_id', NEW.user_id::text,
                'actor_username', v_actor_name,
                'sender_user_id', v_share.sender_id::text,
                'recipient_user_id', v_share.recipient_id::text,
                'share_id', v_share.id,
                'entity_type', 'task',
                'entity_id', COALESCE(NULLIF(trim(v_partner_task_id), ''), v_share.entity_id),
                'share_mode', v_share.share_mode,
                'item_title', v_item_title,
                'status', 'cancelled',
                'cancellation_reason', 'collaborative_task_deleted',
                'sender_id', NEW.user_id::text
              ),
              now()
            )
            ON CONFLICT (id) DO NOTHING;
          EXCEPTION WHEN OTHERS THEN
            NULL;
          END;
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
      IF v_sender_tags IS DISTINCT FROM NEW.tags THEN
        UPDATE public.tasks
        SET tags = v_sender_tags,
            updated_at = now()
        WHERE id = NEW.id AND deleted_at IS NULL;
      END IF;
      v_target_tags := v_recipient_tags;
    ELSE
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

-- 3. Atomic RPC called when a user deletes a collaborative task:
--    Soft-deletes ONLY the caller's task, keeps partner's task alive in normal tasks,
--    strips sender/collab tags from partner's task, updates companion_shares, and logs notification.
CREATE OR REPLACE FUNCTION public.cancel_collaborative_share_on_task_delete(
  p_task_id text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_clean_task_id text := trim(COALESCE(p_task_id, ''));
  v_now_iso text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  v_actor_name text;
  v_share RECORD;
  v_partner_user_id uuid;
  v_partner_task_id text;
  v_sender_name text;
  v_item_title text;
  v_preview jsonb;
  v_deleted_log_id text;
  v_updated_count integer := 0;
BEGIN
  IF v_uid IS NULL OR v_clean_task_id = '' THEN
    RETURN 0;
  END IF;

  SELECT NULLIF(trim(name), '') INTO v_actor_name
  FROM public.user_profiles
  WHERE user_id = v_uid
  LIMIT 1;

  UPDATE public.tasks
  SET deleted_at = now(),
      updated_at = now()
  WHERE id = v_clean_task_id
    AND user_id = v_uid
    AND deleted_at IS NULL;

  FOR v_share IN
    SELECT *
    FROM public.companion_shares
    WHERE entity_type = 'task'
      AND (entity_id = v_clean_task_id OR accepted_entity_id = v_clean_task_id)
      AND (sender_id = v_uid OR recipient_id = v_uid)
      AND status IN ('accepted', 'pending', 'cancelled')
    FOR UPDATE
  LOOP
    -- Leave already-accepted copy shares intact so recipient keeps independent attribution
    IF v_share.share_mode = 'copy'
       AND v_share.status = 'accepted'
       AND NULLIF(trim(COALESCE(v_share.accepted_entity_id, '')), '') IS NOT NULL THEN
      CONTINUE;
    END IF;

    v_updated_count := v_updated_count + 1;

    IF v_share.sender_id = v_uid THEN
      v_partner_user_id := v_share.recipient_id;
    ELSE
      v_partner_user_id := v_share.sender_id;
    END IF;

    IF v_share.entity_id = v_clean_task_id THEN
      v_partner_task_id := NULLIF(trim(COALESCE(v_share.accepted_entity_id, '')), '');
    ELSE
      v_partner_task_id := v_share.entity_id;
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

    v_actor_name := COALESCE(
      v_actor_name,
      CASE
        WHEN v_share.sender_id = v_uid THEN v_sender_name
        ELSE NULL
      END,
      'A companion'
    );

    v_item_title := COALESCE(
      NULLIF(trim(v_preview->>'title'), ''),
      (SELECT NULLIF(trim(title), '') FROM public.tasks WHERE id = v_clean_task_id LIMIT 1),
      'Shared Task'
    );

    IF v_share.share_mode = 'collaborate' THEN
      v_preview := v_preview || jsonb_build_object(
        'sender_id', v_share.sender_id::text,
        'sender_name', v_sender_name,
        'cancelled_by', v_uid::text,
        'cancelled_by_name', v_actor_name,
        'cancellation_reason', 'collaborative_task_deleted',
        'cancelled_at', COALESCE(NULLIF(trim(v_preview->>'cancelled_at'), ''), v_now_iso)
      );
    ELSE
      v_preview := v_preview || jsonb_build_object(
        'cancelled_by', v_uid::text,
        'cancelled_by_name', v_actor_name,
        'cancellation_reason', 'task_deleted',
        'cancelled_at', COALESCE(NULLIF(trim(v_preview->>'cancelled_at'), ''), v_now_iso)
      );
    END IF;

    UPDATE public.companion_shares
    SET status = 'cancelled',
        preview_data = v_preview::text,
        updated_at = now()
    WHERE id = v_share.id;

    UPDATE public.tasks
    SET tags = public.remove_share_sender_tag(tags, v_sender_name),
        updated_at = now()
    WHERE id = v_share.entity_id
      AND deleted_at IS NULL
      AND tags IS DISTINCT FROM public.remove_share_sender_tag(tags, v_sender_name);

    IF v_share.share_mode = 'collaborate'
       AND NULLIF(trim(COALESCE(v_share.accepted_entity_id, '')), '') IS NOT NULL THEN
      UPDATE public.tasks
      SET tags = public.remove_share_sender_tag(tags, v_sender_name),
          updated_at = now()
      WHERE id = v_share.accepted_entity_id
        AND deleted_at IS NULL
        AND tags IS DISTINCT FROM public.remove_share_sender_tag(tags, v_sender_name);
    END IF;

    IF v_share.share_mode = 'collaborate'
       AND v_partner_user_id IS NOT NULL
       AND NULLIF(trim(COALESCE(v_share.accepted_entity_id, '')), '') IS NOT NULL THEN
      v_deleted_log_id := regexp_replace(
        md5('collab_deleted_' || v_share.id),
        '([0-9a-f]{8})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{12})',
        '\1-\2-\3-\4-\5'
      );

      INSERT INTO public.friend_activity_logs (
        id, user_id, event_type, title, metadata, created_at
      ) VALUES (
        v_deleted_log_id,
        v_partner_user_id,
        'collaborative_task_deleted',
        v_actor_name || ' deleted collaborative task: ' || v_item_title,
        jsonb_build_object(
          'actor_user_id', v_uid::text,
          'actor_username', v_actor_name,
          'sender_user_id', v_share.sender_id::text,
          'recipient_user_id', v_share.recipient_id::text,
          'share_id', v_share.id,
          'entity_type', 'task',
          'entity_id', COALESCE(v_partner_task_id, v_share.entity_id),
          'share_mode', v_share.share_mode,
          'item_title', v_item_title,
          'status', 'cancelled',
          'cancellation_reason', 'collaborative_task_deleted',
          'sender_id', v_uid::text
        ),
        now()
      )
      ON CONFLICT (id) DO NOTHING;
    END IF;
  END LOOP;

  RETURN v_updated_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_collaborative_share_on_task_delete(text) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
