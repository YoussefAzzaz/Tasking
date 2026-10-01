-- =============================================================================
-- AXIS: Initial Schema Migration
-- Sprint 1 – Repository & Database Schema
-- SPEC.md §4 is the authoritative source; column names must be identical
-- in Postgres, Dart, and C#.
--
-- Conventions (SPEC.md §3.1):
--   • Primary key : id  text  (UUID stored as text)
--   • Every synced table has: id, user_id, created_at, updated_at, deleted_at
--   • Soft delete only: deleted_at IS NULL to select live rows
--   • Timestamps: ISO-8601 UTC (timestamptz in Postgres)
--   • Dates      : text 'YYYY-MM-DD' in user's timezone
--   • Times      : text 'HH:MM' 24h local
--   • Booleans   : boolean in Postgres, 0/1 integer locally in SQLite
--   • Priority   : integer 0=none 1=low 2=medium 3=high
--   • sort_order : real (fractional inserts)
--   • RLS        : select/insert/update/delete where user_id = auth.uid()
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Helper: common columns macro (applied manually per table below)
-- ---------------------------------------------------------------------------
-- id          text PRIMARY KEY
-- user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
-- created_at  timestamptz NOT NULL DEFAULT now()
-- updated_at  timestamptz NOT NULL DEFAULT now()
-- deleted_at  timestamptz

-- ---------------------------------------------------------------------------
-- Trigger function: auto-update updated_at
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION axis_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- §4.1  Core tables
-- ---------------------------------------------------------------------------

-- user_settings (id = user_id per §4.7)
CREATE TABLE user_settings (
  id                         text PRIMARY KEY,
  user_id                    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  deleted_at                 timestamptz,

  timezone                   text NOT NULL DEFAULT 'UTC',
  week_starts_on             integer NOT NULL DEFAULT 1 CHECK (week_starts_on BETWEEN 1 AND 7),
  work_start                 text NOT NULL DEFAULT '09:00',
  work_end                   text NOT NULL DEFAULT '17:30',
  default_estimate_min       integer NOT NULL DEFAULT 30,
  buffer_min                 integer NOT NULL DEFAULT 5,
  focus_work_min             integer NOT NULL DEFAULT 25,
  focus_break_min            integer NOT NULL DEFAULT 5,
  focus_long_break_min       integer NOT NULL DEFAULT 15,
  focus_cycles_before_long   integer NOT NULL DEFAULT 4,
  morning_plan_time          text NOT NULL DEFAULT '08:30',
  evening_review_time        text NOT NULL DEFAULT '21:00',
  theme                      text NOT NULL DEFAULT 'system' CHECK (theme IN ('system','light','dark')),
  animations_enabled         boolean NOT NULL DEFAULT true,
  sounds_enabled             boolean NOT NULL DEFAULT true
);

CREATE TRIGGER user_settings_updated_at
  BEFORE UPDATE ON user_settings
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_settings_select ON user_settings FOR SELECT USING (user_id = auth.uid());
CREATE POLICY user_settings_insert ON user_settings FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY user_settings_update ON user_settings FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY user_settings_delete ON user_settings FOR DELETE USING (user_id = auth.uid());

-- projects
CREATE TABLE projects (
  id          text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  name        text NOT NULL,
  color       text NOT NULL DEFAULT '#6366f1',  -- hex
  icon        text,                              -- emoji
  sort_order  real NOT NULL DEFAULT 0,
  archived_at timestamptz
);

CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY projects_select ON projects FOR SELECT USING (user_id = auth.uid());
CREATE POLICY projects_insert ON projects FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY projects_update ON projects FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY projects_delete ON projects FOR DELETE USING (user_id = auth.uid());

-- tasks
CREATE TABLE tasks (
  id               text PRIMARY KEY,
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz,

  project_id       text REFERENCES projects(id),          -- null = Inbox
  parent_task_id   text REFERENCES tasks(id),
  title            text NOT NULL,
  notes            text,
  status           text NOT NULL DEFAULT 'todo' CHECK (status IN ('todo','done','cancelled')),
  priority         integer NOT NULL DEFAULT 0 CHECK (priority BETWEEN 0 AND 3),
  due_date         text,                                   -- YYYY-MM-DD
  due_time         text,                                   -- HH:MM
  estimate_min     integer,
  recurrence_rule  text,                                   -- RRULE string without DTSTART
  recurrence_mode  text DEFAULT 'fixed' CHECK (recurrence_mode IN ('fixed','after_completion')),
  series_id        text,
  remind_at        timestamptz,
  completed_at     timestamptz,
  completed_date   text,                                   -- YYYY-MM-DD
  sort_order       real NOT NULL DEFAULT 0
);

CREATE TRIGGER tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY tasks_select ON tasks FOR SELECT USING (user_id = auth.uid());
CREATE POLICY tasks_insert ON tasks FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY tasks_update ON tasks FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY tasks_delete ON tasks FOR DELETE USING (user_id = auth.uid());

-- tags
CREATE TABLE tags (
  id         text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,

  name       text NOT NULL,
  color      text NOT NULL DEFAULT '#94a3b8'
);

CREATE TRIGGER tags_updated_at
  BEFORE UPDATE ON tags
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY tags_select ON tags FOR SELECT USING (user_id = auth.uid());
CREATE POLICY tags_insert ON tags FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY tags_update ON tags FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY tags_delete ON tags FOR DELETE USING (user_id = auth.uid());

-- task_tags (junction)
CREATE TABLE task_tags (
  id         text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,

  task_id    text NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id     text NOT NULL REFERENCES tags(id) ON DELETE CASCADE
);

CREATE TRIGGER task_tags_updated_at
  BEFORE UPDATE ON task_tags
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE task_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY task_tags_select ON task_tags FOR SELECT USING (user_id = auth.uid());
CREATE POLICY task_tags_insert ON task_tags FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY task_tags_update ON task_tags FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY task_tags_delete ON task_tags FOR DELETE USING (user_id = auth.uid());

-- saved_filters
CREATE TABLE saved_filters (
  id         text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,

  name       text NOT NULL,
  query_json text NOT NULL,   -- JSON string per §6.3
  sort_order real NOT NULL DEFAULT 0
);

CREATE TRIGGER saved_filters_updated_at
  BEFORE UPDATE ON saved_filters
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE saved_filters ENABLE ROW LEVEL SECURITY;

CREATE POLICY saved_filters_select ON saved_filters FOR SELECT USING (user_id = auth.uid());
CREATE POLICY saved_filters_insert ON saved_filters FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY saved_filters_update ON saved_filters FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY saved_filters_delete ON saved_filters FOR DELETE USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- §4.2  Planning tables
-- ---------------------------------------------------------------------------

-- daily_plans
CREATE TABLE daily_plans (
  id            text PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz,

  plan_date     text NOT NULL,                        -- YYYY-MM-DD
  top1_task_id  text REFERENCES tasks(id),
  top2_task_id  text REFERENCES tasks(id),
  top3_task_id  text REFERENCES tasks(id),
  planned_at    timestamptz,
  reviewed_at   timestamptz,
  reflection    text,

  UNIQUE (user_id, plan_date)
);

CREATE TRIGGER daily_plans_updated_at
  BEFORE UPDATE ON daily_plans
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE daily_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY daily_plans_select ON daily_plans FOR SELECT USING (user_id = auth.uid());
CREATE POLICY daily_plans_insert ON daily_plans FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY daily_plans_update ON daily_plans FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY daily_plans_delete ON daily_plans FOR DELETE USING (user_id = auth.uid());

-- time_blocks
CREATE TABLE time_blocks (
  id                text PRIMARY KEY,
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,

  task_id           text REFERENCES tasks(id),
  title             text,                               -- for non-task blocks
  start_at          timestamptz NOT NULL,
  end_at            timestamptz NOT NULL,
  source            text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','auto')),
  external_event_id text                                -- written by gcal-push Edge Function
);

CREATE TRIGGER time_blocks_updated_at
  BEFORE UPDATE ON time_blocks
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE time_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY time_blocks_select ON time_blocks FOR SELECT USING (user_id = auth.uid());
CREATE POLICY time_blocks_insert ON time_blocks FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY time_blocks_update ON time_blocks FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY time_blocks_delete ON time_blocks FOR DELETE USING (user_id = auth.uid());

-- focus_sessions
CREATE TABLE focus_sessions (
  id          text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  task_id     text REFERENCES tasks(id),
  kind        text NOT NULL DEFAULT 'work' CHECK (kind IN ('work','break')),
  planned_min integer NOT NULL,
  actual_min  integer,
  started_at  timestamptz NOT NULL,
  ended_at    timestamptz,                  -- null while running
  completed   boolean NOT NULL DEFAULT false
);

CREATE TRIGGER focus_sessions_updated_at
  BEFORE UPDATE ON focus_sessions
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE focus_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY focus_sessions_select ON focus_sessions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY focus_sessions_insert ON focus_sessions FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY focus_sessions_update ON focus_sessions FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY focus_sessions_delete ON focus_sessions FOR DELETE USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- §4.3  Habit tables
-- ---------------------------------------------------------------------------

-- habits
CREATE TABLE habits (
  id              text PRIMARY KEY,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz,

  name            text NOT NULL,
  icon            text,
  color           text NOT NULL DEFAULT '#6366f1',
  kind            text NOT NULL DEFAULT 'boolean' CHECK (kind IN ('boolean','numeric')),
  target_value    real,
  unit            text,
  schedule_type   text NOT NULL DEFAULT 'daily'
                    CHECK (schedule_type IN ('daily','weekdays','times_per_week','every_n_days')),
  schedule_days   text,           -- CSV of ISO weekday numbers e.g. '1,3,5'
  schedule_n      integer,        -- N for times_per_week or every_n_days
  start_date      text NOT NULL,  -- YYYY-MM-DD
  remind_time     text,           -- HH:MM
  sort_order      real NOT NULL DEFAULT 0,
  archived_at     timestamptz
);

CREATE TRIGGER habits_updated_at
  BEFORE UPDATE ON habits
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE habits ENABLE ROW LEVEL SECURITY;

CREATE POLICY habits_select ON habits FOR SELECT USING (user_id = auth.uid());
CREATE POLICY habits_insert ON habits FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY habits_update ON habits FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY habits_delete ON habits FOR DELETE USING (user_id = auth.uid());

-- habit_logs
CREATE TABLE habit_logs (
  id         text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,

  habit_id   text NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  log_date   text NOT NULL,                     -- YYYY-MM-DD
  status     text NOT NULL CHECK (status IN ('done','skipped')),
  value      real,
  note       text,

  UNIQUE (user_id, habit_id, log_date)
);

CREATE TRIGGER habit_logs_updated_at
  BEFORE UPDATE ON habit_logs
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE habit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY habit_logs_select ON habit_logs FOR SELECT USING (user_id = auth.uid());
CREATE POLICY habit_logs_insert ON habit_logs FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY habit_logs_update ON habit_logs FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY habit_logs_delete ON habit_logs FOR DELETE USING (user_id = auth.uid());

-- routines
CREATE TABLE routines (
  id          text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  name        text NOT NULL,
  kind        text NOT NULL DEFAULT 'custom' CHECK (kind IN ('morning','evening','custom')),
  remind_time text,           -- HH:MM
  sort_order  real NOT NULL DEFAULT 0,
  archived_at timestamptz
);

CREATE TRIGGER routines_updated_at
  BEFORE UPDATE ON routines
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE routines ENABLE ROW LEVEL SECURITY;

CREATE POLICY routines_select ON routines FOR SELECT USING (user_id = auth.uid());
CREATE POLICY routines_insert ON routines FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY routines_update ON routines FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY routines_delete ON routines FOR DELETE USING (user_id = auth.uid());

-- routine_steps
CREATE TABLE routine_steps (
  id           text PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz,

  routine_id   text NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  title        text NOT NULL,
  duration_min integer,
  sort_order   real NOT NULL DEFAULT 0
);

CREATE TRIGGER routine_steps_updated_at
  BEFORE UPDATE ON routine_steps
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE routine_steps ENABLE ROW LEVEL SECURITY;

CREATE POLICY routine_steps_select ON routine_steps FOR SELECT USING (user_id = auth.uid());
CREATE POLICY routine_steps_insert ON routine_steps FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY routine_steps_update ON routine_steps FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY routine_steps_delete ON routine_steps FOR DELETE USING (user_id = auth.uid());

-- routine_runs
CREATE TABLE routine_runs (
  id           text PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz,

  routine_id   text NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  run_date     text NOT NULL,          -- YYYY-MM-DD
  started_at   timestamptz NOT NULL,
  completed_at timestamptz,
  steps_done   integer NOT NULL DEFAULT 0,
  steps_total  integer NOT NULL DEFAULT 0
);

CREATE TRIGGER routine_runs_updated_at
  BEFORE UPDATE ON routine_runs
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE routine_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY routine_runs_select ON routine_runs FOR SELECT USING (user_id = auth.uid());
CREATE POLICY routine_runs_insert ON routine_runs FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY routine_runs_update ON routine_runs FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY routine_runs_delete ON routine_runs FOR DELETE USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- §4.4  Notes, mood, voice
-- ---------------------------------------------------------------------------

-- notes
CREATE TABLE notes (
  id         text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,

  title      text NOT NULL DEFAULT '',
  body_md    text NOT NULL DEFAULT '',
  pinned     boolean NOT NULL DEFAULT false,
  project_id text REFERENCES projects(id),
  task_id    text REFERENCES tasks(id)
);

CREATE TRIGGER notes_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY notes_select ON notes FOR SELECT USING (user_id = auth.uid());
CREATE POLICY notes_insert ON notes FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY notes_update ON notes FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY notes_delete ON notes FOR DELETE USING (user_id = auth.uid());

-- journal_entries
CREATE TABLE journal_entries (
  id           text PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz,

  entry_date   text NOT NULL,      -- YYYY-MM-DD
  body_md      text NOT NULL DEFAULT '',
  template_key text,

  UNIQUE (user_id, entry_date)
);

CREATE TRIGGER journal_entries_updated_at
  BEFORE UPDATE ON journal_entries
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY journal_entries_select ON journal_entries FOR SELECT USING (user_id = auth.uid());
CREATE POLICY journal_entries_insert ON journal_entries FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY journal_entries_update ON journal_entries FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY journal_entries_delete ON journal_entries FOR DELETE USING (user_id = auth.uid());

-- mood_logs
CREATE TABLE mood_logs (
  id         text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,

  logged_at  timestamptz NOT NULL,
  log_date   text NOT NULL,     -- YYYY-MM-DD
  mood       integer NOT NULL CHECK (mood BETWEEN 1 AND 5),
  energy     integer NOT NULL CHECK (energy BETWEEN 1 AND 5),
  note       text
);

CREATE TRIGGER mood_logs_updated_at
  BEFORE UPDATE ON mood_logs
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE mood_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY mood_logs_select ON mood_logs FOR SELECT USING (user_id = auth.uid());
CREATE POLICY mood_logs_insert ON mood_logs FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY mood_logs_update ON mood_logs FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY mood_logs_delete ON mood_logs FOR DELETE USING (user_id = auth.uid());

-- voice_notes
CREATE TABLE voice_notes (
  id                 text PRIMARY KEY,
  user_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  deleted_at         timestamptz,

  recorded_at        timestamptz NOT NULL,
  duration_sec       real,
  storage_path       text,
  upload_status      text NOT NULL DEFAULT 'local'
                       CHECK (upload_status IN ('local','uploading','uploaded','failed')),
  transcript         text,
  transcript_status  text NOT NULL DEFAULT 'none'
                       CHECK (transcript_status IN ('none','pending','done','failed')),
  task_id            text REFERENCES tasks(id),
  note_id            text REFERENCES notes(id)
);

CREATE TRIGGER voice_notes_updated_at
  BEFORE UPDATE ON voice_notes
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE voice_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY voice_notes_select ON voice_notes FOR SELECT USING (user_id = auth.uid());
CREATE POLICY voice_notes_insert ON voice_notes FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY voice_notes_update ON voice_notes FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY voice_notes_delete ON voice_notes FOR DELETE USING (user_id = auth.uid());

-- local_files: local-only, never synced (no user_id RLS needed; kept purely on device)
-- NOTE: This table exists only in the local SQLite schema, NOT in Postgres.
-- It is documented here for reference only. The sync rules must exclude it.
-- CREATE TABLE local_files (
--   id            text PRIMARY KEY,
--   voice_note_id text NOT NULL,
--   path          text NOT NULL
-- );

-- ---------------------------------------------------------------------------
-- §4.5  Gamification
-- ---------------------------------------------------------------------------

-- xp_events
CREATE TABLE xp_events (
  id          text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  source_type text NOT NULL,
  source_id   text NOT NULL,
  event_date  text NOT NULL,  -- YYYY-MM-DD
  xp          integer NOT NULL CHECK (xp >= 0),
  reason      text
);

CREATE TRIGGER xp_events_updated_at
  BEFORE UPDATE ON xp_events
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE xp_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY xp_events_select ON xp_events FOR SELECT USING (user_id = auth.uid());
CREATE POLICY xp_events_insert ON xp_events FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY xp_events_update ON xp_events FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY xp_events_delete ON xp_events FOR DELETE USING (user_id = auth.uid());

-- badge_unlocks
CREATE TABLE badge_unlocks (
  id           text PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz,

  badge_key    text NOT NULL,
  unlocked_at  timestamptz NOT NULL DEFAULT now(),

  UNIQUE (user_id, badge_key)
);

CREATE TRIGGER badge_unlocks_updated_at
  BEFORE UPDATE ON badge_unlocks
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE badge_unlocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY badge_unlocks_select ON badge_unlocks FOR SELECT USING (user_id = auth.uid());
CREATE POLICY badge_unlocks_insert ON badge_unlocks FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY badge_unlocks_update ON badge_unlocks FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY badge_unlocks_delete ON badge_unlocks FOR DELETE USING (user_id = auth.uid());

-- rewards
CREATE TABLE rewards (
  id          text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,

  name        text NOT NULL,
  description text,
  cost_xp     integer NOT NULL CHECK (cost_xp > 0),
  active      boolean NOT NULL DEFAULT true
);

CREATE TRIGGER rewards_updated_at
  BEFORE UPDATE ON rewards
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY rewards_select ON rewards FOR SELECT USING (user_id = auth.uid());
CREATE POLICY rewards_insert ON rewards FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY rewards_update ON rewards FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY rewards_delete ON rewards FOR DELETE USING (user_id = auth.uid());

-- reward_redemptions
CREATE TABLE reward_redemptions (
  id           text PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz,

  reward_id    text NOT NULL REFERENCES rewards(id) ON DELETE CASCADE,
  xp_spent     integer NOT NULL CHECK (xp_spent > 0),
  redeemed_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER reward_redemptions_updated_at
  BEFORE UPDATE ON reward_redemptions
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY reward_redemptions_select ON reward_redemptions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY reward_redemptions_insert ON reward_redemptions FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY reward_redemptions_update ON reward_redemptions FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY reward_redemptions_delete ON reward_redemptions FOR DELETE USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- §4.6  Calendar (server-written; clients are READ-ONLY)
-- ---------------------------------------------------------------------------

-- calendar_connections
CREATE TABLE calendar_connections (
  id                    text PRIMARY KEY,
  user_id               uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  deleted_at            timestamptz,

  provider              text NOT NULL DEFAULT 'google' CHECK (provider = 'google'),
  email                 text NOT NULL,
  status                text NOT NULL DEFAULT 'active' CHECK (status IN ('active','error','revoked')),
  selected_calendar_ids text,       -- JSON text array of calendar IDs
  push_calendar_id      text,       -- the dedicated "Axis" Google Calendar id
  last_synced_at        timestamptz
);

CREATE TRIGGER calendar_connections_updated_at
  BEFORE UPDATE ON calendar_connections
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE calendar_connections ENABLE ROW LEVEL SECURITY;

-- Clients may SELECT their own connections; INSERT/UPDATE/DELETE are server-side only
-- EXCEPTION: selected_calendar_ids may be written via an Edge Function call (not directly)
CREATE POLICY calendar_connections_select ON calendar_connections FOR SELECT USING (user_id = auth.uid());
-- No client INSERT/UPDATE/DELETE policies — server uses service role

-- calendar_events
CREATE TABLE calendar_events (
  id              text PRIMARY KEY,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz,

  connection_id   text NOT NULL REFERENCES calendar_connections(id) ON DELETE CASCADE,
  external_id     text NOT NULL,
  calendar_name   text,
  title           text NOT NULL,
  start_at        timestamptz NOT NULL,
  end_at          timestamptz NOT NULL,
  all_day         boolean NOT NULL DEFAULT false
);

CREATE TRIGGER calendar_events_updated_at
  BEFORE UPDATE ON calendar_events
  FOR EACH ROW EXECUTE FUNCTION axis_set_updated_at();

ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

-- Clients SELECT only; server writes via service role
CREATE POLICY calendar_events_select ON calendar_events FOR SELECT USING (user_id = auth.uid());
-- No client INSERT/UPDATE/DELETE policies

-- calendar_secrets: server-only, NEVER synced to clients, no client policies
CREATE TABLE calendar_secrets (
  id                     text PRIMARY KEY,
  -- No user_id FK here — accessed only by service role Edge Functions
  connection_id          text NOT NULL REFERENCES calendar_connections(id) ON DELETE CASCADE,
  encrypted_refresh_token text NOT NULL,
  sync_tokens            text         -- JSON text
  -- No RLS needed: zero client access policies; service role bypasses RLS
);

-- Explicitly do NOT enable RLS so that only the service role can ever reach this table.
-- If RLS were enabled with no policies, no one (including service role without bypass)
-- could read it, which would break Edge Functions. We intentionally leave it unprotected
-- at the Postgres level and rely on the Supabase secret + Edge Function boundary.

-- ---------------------------------------------------------------------------
-- Indexes (query performance)
-- ---------------------------------------------------------------------------

-- Tasks: common lookups
CREATE INDEX tasks_user_status       ON tasks (user_id, status)       WHERE deleted_at IS NULL;
CREATE INDEX tasks_user_project      ON tasks (user_id, project_id)   WHERE deleted_at IS NULL;
CREATE INDEX tasks_user_due_date     ON tasks (user_id, due_date)     WHERE deleted_at IS NULL;
CREATE INDEX tasks_user_series       ON tasks (user_id, series_id)    WHERE deleted_at IS NULL;
CREATE INDEX tasks_parent            ON tasks (parent_task_id)        WHERE deleted_at IS NULL;

-- Habit logs
CREATE INDEX habit_logs_habit_date   ON habit_logs (habit_id, log_date)  WHERE deleted_at IS NULL;
CREATE INDEX habit_logs_user_date    ON habit_logs (user_id, log_date)   WHERE deleted_at IS NULL;

-- Focus sessions
CREATE INDEX focus_sessions_task     ON focus_sessions (task_id)         WHERE deleted_at IS NULL;
CREATE INDEX focus_sessions_date     ON focus_sessions (user_id, started_at) WHERE deleted_at IS NULL;

-- XP events
CREATE INDEX xp_events_user_date     ON xp_events (user_id, event_date)  WHERE deleted_at IS NULL;
CREATE INDEX xp_events_source        ON xp_events (user_id, source_type, source_id, event_date)
                                                                          WHERE deleted_at IS NULL;

-- Calendar events
CREATE INDEX calendar_events_user_range ON calendar_events (user_id, start_at, end_at)
                                                                          WHERE deleted_at IS NULL;

-- Time blocks
CREATE INDEX time_blocks_user_start  ON time_blocks (user_id, start_at)  WHERE deleted_at IS NULL;

-- Daily plans
CREATE INDEX daily_plans_user_date   ON daily_plans (user_id, plan_date) WHERE deleted_at IS NULL;

-- Journal entries
CREATE INDEX journal_entries_user_date ON journal_entries (user_id, entry_date) WHERE deleted_at IS NULL;

-- Mood logs
CREATE INDEX mood_logs_user_date     ON mood_logs (user_id, log_date)    WHERE deleted_at IS NULL;
