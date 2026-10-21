-- =============================================================================
-- AXIS: Multi-User Schema, PowerSync Replication & Row-Level Security
-- Connects Supabase Auth (auth.users) with PowerSync client SQLite databases.
-- Follows supabase and supabase-postgres-best-practices guidelines:
--   1. (select auth.uid()) = user_id in policies (avoids per-row execution)
--   2. Explicit indexes on user_id on every table
--   3. Both USING and WITH CHECK on UPDATE policies
--   4. Client UUID primary keys (PowerSync requirement)
--   5. Idempotent publication setup for PowerSync logical replication
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Auto-update updated_at trigger function
CREATE OR REPLACE FUNCTION axis_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- 1. Tasks
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tasks (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz,

  title            text NOT NULL,
  notes            text,
  status           text NOT NULL DEFAULT 'todo',
  priority         integer NOT NULL DEFAULT 0,
  project_id       text,
  tags             text,
  due_date         text,
  due_time         text,
  estimate_min     integer,
  recurrence_rule  text,
  recurrence_mode  text,
  completed_at     timestamptz
);

CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON public.tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);

DROP TRIGGER IF EXISTS tasks_updated_at ON public.tasks;
CREATE TRIGGER tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tasks_select_policy" ON public.tasks;
CREATE POLICY "tasks_select_policy" ON public.tasks
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "tasks_insert_policy" ON public.tasks;
CREATE POLICY "tasks_insert_policy" ON public.tasks
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "tasks_update_policy" ON public.tasks;
CREATE POLICY "tasks_update_policy" ON public.tasks
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "tasks_delete_policy" ON public.tasks;
CREATE POLICY "tasks_delete_policy" ON public.tasks
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- 2. Projects
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.projects (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  name        text NOT NULL,
  color       text NOT NULL DEFAULT '#6366f1'
);

CREATE INDEX IF NOT EXISTS idx_projects_user_id ON public.projects(user_id);

DROP TRIGGER IF EXISTS projects_updated_at ON public.projects;
CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "projects_select_policy" ON public.projects;
CREATE POLICY "projects_select_policy" ON public.projects
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "projects_insert_policy" ON public.projects;
CREATE POLICY "projects_insert_policy" ON public.projects
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "projects_update_policy" ON public.projects;
CREATE POLICY "projects_update_policy" ON public.projects
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "projects_delete_policy" ON public.projects;
CREATE POLICY "projects_delete_policy" ON public.projects
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- 3. Tags
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tags (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  name        text NOT NULL,
  color       text NOT NULL DEFAULT '#6366f1'
);

CREATE INDEX IF NOT EXISTS idx_tags_user_id ON public.tags(user_id);

DROP TRIGGER IF EXISTS tags_updated_at ON public.tags;
CREATE TRIGGER tags_updated_at
  BEFORE UPDATE ON public.tags
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tags_select_policy" ON public.tags;
CREATE POLICY "tags_select_policy" ON public.tags
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "tags_insert_policy" ON public.tags;
CREATE POLICY "tags_insert_policy" ON public.tags
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "tags_update_policy" ON public.tags;
CREATE POLICY "tags_update_policy" ON public.tags
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "tags_delete_policy" ON public.tags;
CREATE POLICY "tags_delete_policy" ON public.tags
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- 4. Habits
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.habits (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  deleted_at     timestamptz,

  name           text NOT NULL,
  icon           text,
  color          text NOT NULL DEFAULT '#10b981',
  kind           text,
  target_value   integer NOT NULL DEFAULT 20,
  unit           text,
  schedule_type  text NOT NULL DEFAULT 'daily',
  remind_time    text,
  sort_order     integer NOT NULL DEFAULT 999
);

CREATE INDEX IF NOT EXISTS idx_habits_user_id ON public.habits(user_id);

DROP TRIGGER IF EXISTS habits_updated_at ON public.habits;
CREATE TRIGGER habits_updated_at
  BEFORE UPDATE ON public.habits
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "habits_select_policy" ON public.habits;
CREATE POLICY "habits_select_policy" ON public.habits
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habits_insert_policy" ON public.habits;
CREATE POLICY "habits_insert_policy" ON public.habits
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habits_update_policy" ON public.habits;
CREATE POLICY "habits_update_policy" ON public.habits
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habits_delete_policy" ON public.habits;
CREATE POLICY "habits_delete_policy" ON public.habits
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- 5. Habit Logs
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.habit_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  habit_id    text NOT NULL,
  log_date    text NOT NULL,
  status      text NOT NULL DEFAULT 'done',
  value       numeric NOT NULL DEFAULT 1,
  note        text
);

CREATE INDEX IF NOT EXISTS idx_habit_logs_user_id ON public.habit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_habit_logs_habit_date ON public.habit_logs(habit_id, log_date);

DROP TRIGGER IF EXISTS habit_logs_updated_at ON public.habit_logs;
CREATE TRIGGER habit_logs_updated_at
  BEFORE UPDATE ON public.habit_logs
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE public.habit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "habit_logs_select_policy" ON public.habit_logs;
CREATE POLICY "habit_logs_select_policy" ON public.habit_logs
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habit_logs_insert_policy" ON public.habit_logs;
CREATE POLICY "habit_logs_insert_policy" ON public.habit_logs
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habit_logs_update_policy" ON public.habit_logs;
CREATE POLICY "habit_logs_update_policy" ON public.habit_logs
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "habit_logs_delete_policy" ON public.habit_logs;
CREATE POLICY "habit_logs_delete_policy" ON public.habit_logs
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- 6. Notes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  title       text NOT NULL DEFAULT '',
  body_md     text NOT NULL DEFAULT '',
  pinned      boolean NOT NULL DEFAULT false,
  category    text NOT NULL DEFAULT 'note',
  mood        text,
  energy      text
);

CREATE INDEX IF NOT EXISTS idx_notes_user_id ON public.notes(user_id);

DROP TRIGGER IF EXISTS notes_updated_at ON public.notes;
CREATE TRIGGER notes_updated_at
  BEFORE UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notes_select_policy" ON public.notes;
CREATE POLICY "notes_select_policy" ON public.notes
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "notes_insert_policy" ON public.notes;
CREATE POLICY "notes_insert_policy" ON public.notes
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "notes_update_policy" ON public.notes;
CREATE POLICY "notes_update_policy" ON public.notes
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "notes_delete_policy" ON public.notes;
CREATE POLICY "notes_delete_policy" ON public.notes
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- 7. Focus Sessions
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.focus_sessions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz,

  task_id      text,
  kind         text NOT NULL DEFAULT 'pomodoro',
  planned_min  integer NOT NULL DEFAULT 25,
  actual_min   integer NOT NULL DEFAULT 25,
  started_at   timestamptz NOT NULL DEFAULT now(),
  ended_at     timestamptz,
  completed    boolean NOT NULL DEFAULT false,
  xp_earned    integer NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_focus_sessions_user_id ON public.focus_sessions(user_id);

DROP TRIGGER IF EXISTS focus_sessions_updated_at ON public.focus_sessions;
CREATE TRIGGER focus_sessions_updated_at
  BEFORE UPDATE ON public.focus_sessions
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE public.focus_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "focus_sessions_select_policy" ON public.focus_sessions;
CREATE POLICY "focus_sessions_select_policy" ON public.focus_sessions
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "focus_sessions_insert_policy" ON public.focus_sessions;
CREATE POLICY "focus_sessions_insert_policy" ON public.focus_sessions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "focus_sessions_update_policy" ON public.focus_sessions;
CREATE POLICY "focus_sessions_update_policy" ON public.focus_sessions
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "focus_sessions_delete_policy" ON public.focus_sessions;
CREATE POLICY "focus_sessions_delete_policy" ON public.focus_sessions
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- 8. Activity / XP Logs
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  task_id     text,
  event_type  text NOT NULL,
  xp_earned   integer NOT NULL DEFAULT 0,
  timestamp   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_logs_user_id ON public.logs(user_id);

DROP TRIGGER IF EXISTS logs_updated_at ON public.logs;
CREATE TRIGGER logs_updated_at
  BEFORE UPDATE ON public.logs
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE public.logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "logs_select_policy" ON public.logs;
CREATE POLICY "logs_select_policy" ON public.logs
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "logs_insert_policy" ON public.logs;
CREATE POLICY "logs_insert_policy" ON public.logs
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "logs_update_policy" ON public.logs;
CREATE POLICY "logs_update_policy" ON public.logs
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "logs_delete_policy" ON public.logs;
CREATE POLICY "logs_delete_policy" ON public.logs
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);


-- -----------------------------------------------------------------------------
-- 9. Grants for Supabase Roles
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;


-- -----------------------------------------------------------------------------
-- 10. PowerSync Logical Replication Publication
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    CREATE PUBLICATION powersync FOR TABLE
      public.tasks,
      public.projects,
      public.tags,
      public.habits,
      public.habit_logs,
      public.notes,
      public.focus_sessions,
      public.logs
    WITH (publish = 'insert, update, delete, truncate');
  ELSE
    ALTER PUBLICATION powersync SET TABLE
      public.tasks,
      public.projects,
      public.tags,
      public.habits,
      public.habit_logs,
      public.notes,
      public.focus_sessions,
      public.logs;
  END IF;
END $$;
