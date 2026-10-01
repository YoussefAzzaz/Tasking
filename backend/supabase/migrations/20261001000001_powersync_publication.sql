-- =============================================================================
-- AXIS: PowerSync Replication Setup
-- Sprint 2 – PowerSync Setup & Sync Rules
--
-- Creates the Postgres logical replication publication that PowerSync reads.
-- Must be applied AFTER the initial schema migration (20261001000000).
--
-- PowerSync replicates all rows through logical replication. We create a
-- publication that covers every synced table. Tables that must never reach
-- clients (calendar_secrets, and the local-only local_files which has no
-- Postgres table) are intentionally excluded.
--
-- The replication slot is created by PowerSync itself on first connect; we
-- record the expected slot name here for documentation purposes only.
-- Slot name: powersync_axis
-- =============================================================================

-- Create the publication for PowerSync.
-- Covers every public table that appears in sync-rules.yaml.
-- calendar_secrets is deliberately excluded.
CREATE PUBLICATION powersync FOR TABLE
  -- §4.1 Core
  user_settings,
  projects,
  tasks,
  tags,
  task_tags,
  saved_filters,
  -- §4.2 Planning
  daily_plans,
  time_blocks,
  focus_sessions,
  -- §4.3 Habits
  habits,
  habit_logs,
  routines,
  routine_steps,
  routine_runs,
  -- §4.4 Notes/mood/voice
  notes,
  journal_entries,
  mood_logs,
  voice_notes,
  -- §4.5 Gamification
  xp_events,
  badge_unlocks,
  rewards,
  reward_redemptions,
  -- §4.6 Calendar (read-only for clients; server-written)
  calendar_connections,
  calendar_events
  -- Excluded: calendar_secrets (never synced)
  -- Excluded: local_files (SQLite-only, no Postgres table)
WITH (publish = 'insert, update, delete, truncate');

-- Grant replication permissions to the authenticator role used by PowerSync.
-- In Supabase, the connection uses the postgres superuser locally; on production
-- a dedicated replication user should be created.
-- GRANT REPLICATION ON DATABASE postgres TO <replication_user>;
-- (Handled by Supabase when using the connection string from the dashboard)
