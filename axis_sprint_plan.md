# AXIS: Detailed Sprint Plan

This document outlines the step-by-step sprint plan for building the Axis application. Agents must complete exactly one sprint at a time, ensuring the "Done When" criteria are met before proceeding.

## Phase 1: Architecture & Backend Foundation

### Sprint 1: Repository & Database Schema
*   **Tasks:**
    *   Create the root repository structure: `docs/`, `contract/`, `backend/`, `mobile/`, `desktop/`.
    *   Initialize a Supabase project and write the initial SQL migration in `backend/supabase/migrations/`.
    *   Implement the exact schema detailed in `SPEC.md`, including `user_settings`, `projects`, `tasks`, `tags`, `task_tags`, and `saved_filters`.
    *   Add the five common columns (`id`, `user_id`, `created_at`, `updated_at`, `deleted_at`) to all relevant tables.
    *   Configure Row Level Security (RLS) on every table to restrict operations to `user_id = auth.uid()`.
*   **Done When:** Supabase local environment runs successfully, migrations apply without errors, and RLS policies are active.

### Sprint 2: PowerSync Setup & Sync Rules (DONE)
*   **Tasks:**
    *   Configure the PowerSync connector within the `backend/powersync/` directory.
    *   Write `sync-rules.yaml` to ensure all core, planning, habit, note, and gamification tables sync to the local SQLite database.
    *   Exclude `local_files` from sync rules.
    *   Restrict `calendar_connections` and `calendar_events` sync rules to read-only for clients, excluding secrets entirely.
    *   Set up docker-compose and local config for PowerSync to connect successfully.
*   **Done When:** PowerSync instance connects to Supabase, and sync rules validate successfully. (COMPLETED)

## Phase 2: Core Domain Logic & Shared Contracts

### Sprint 3: Deterministic IDs & Global Constants (DONE)
*   **Tasks:**
    *   Implement UUIDv5 generation using the namespace `3f2b8c1e-6d4a-4e7b-9a52-1c8d0f7e4b11` in both Dart (`lib/domain`) and C# (`Axis.Core`).
    *   Create deterministic ID logic for `user_settings`, `daily_plans`, `journal_entries`, `habit_logs`, `xp_events`, `badge_unlocks`, and recurring task instances.
    *   Generate the shared `contract/ids.json` test vector file to verify ID generation.
*   **Done When:** Dart and C# implementations pass the `contract/ids.json` test vectors identically. (COMPLETED)

### Sprint 4: Task Quick-Add Parser (DONE)
*   **Tasks:**
    *   Implement the natural-language parsing pure function: `parse(text, now, tz, projects, tags)` in both Dart and C#.
    *   Parse priority (`p1`, `p2`, `p3`), projects (`#name`), tags (`@name`), dates (`today`, `tmr`, `mon`, `YYYY-MM-DD`), times (`at 6pm`, `18:00`), estimates (`30m`, `1h`), and recurrence rules (`every day`, `ac`).
    *   Generate `contract/quickadd.json` with comprehensive edge cases.
*   **Done When:** Both platforms successfully extract metadata, remove tokens from the title, and pass all `quickadd.json` tests. (COMPLETED)

### Sprint 5: Recurrence & Auto-Scheduler Logic (DONE)
*   **Tasks:**
    *   Implement RRULE parsing (without `DTSTART`) and calculation for `fixed` and `after_completion` modes in both languages.
    *   Implement the auto-scheduler pure function in Dart and C# using the inputs: `date`, `now`, `work_start`, `work_end`, `buffer_min`, `default_estimate_min`, `busy`, and `tasks`.
    *   Apply greedy placement logic ensuring tasks fit into available 15-minute windows, outputting `{proposed, unplaced, available_min, planned_min}`.
    *   Generate `contract/recurrence.json` and `contract/scheduler.json`.
*   **Done When:** Recurrence advancement and schedule generation pass all contract tests on both platforms. (COMPLETED)

### Sprint 6: Gamification, Streaks & Filters Logic (DONE)
*   **Tasks:**
    *   Implement filter logic evaluation over in-memory tasks using the defined JSON query structure (fields like `priority`, `tag`, `due`).
    *   Implement streak calculation for `daily`, `weekdays`, `times_per_week`, and `every_n_days` schedules, tracking `done` and `skipped` logs.
    *   Implement XP calculation, daily caps (25 task events, 120 focus events), level logic (`xp_to_reach(n) = 50·n·(n−1)`), and badge unlock rules.
    *   Generate `contract/filters.json`, `contract/streaks.json`, and `contract/xp.json`.
*   **Done When:** All business rules execute identically on Dart and C# against the contract vectors. (COMPLETED)

## Phase 3: Mobile Client (Flutter)

### Sprint 7: Mobile Infrastructure & Data Layer (DONE)
*   **Tasks:**
    *   Initialize the Flutter app in `mobile/` using `flutter_riverpod` and `go_router`.
    *   Implement the PowerSync local SQLite database integration and Supabase Auth (email + password).
    *   Build the base repository classes mapping local SQLite rows to Dart models for tasks, projects, and tags.
    *   Implement the global `DomainEvents` bus using Dart streams.
*   **Done When:** The app successfully authenticates, writes a task to local SQLite, and syncs it to Supabase via PowerSync. (COMPLETED)

### Sprint 8: Mobile UI - Tasks & Navigation (DONE)
*   **Tasks:**
    *   Build the bottom navigation bar with 5 tabs: Today, Tasks, Habits, Notes, Me.
    *   Implement the global floating Quick-Add button utilizing the parser from Sprint 4.
    *   Build the Tasks tab segments: Inbox, Upcoming, Projects, and Filters.
    *   Create the Task detail bottom sheet containing title, notes, due date, priority, project, and subtasks.
*   **Done When:** Users can navigate tabs, parse a quick-add task, view it in the inbox, and open its detail sheet. (COMPLETED)

### Sprint 9: Mobile UI - Today Plan & Focus (DONE)
*   **Tasks:**
    *   Build the Today tab featuring the date, morning-plan card, Top 3 tasks, and overdue tasks.
    *   Implement the List and Timeline view toggle for the Today tab.
    *   Integrate the auto-scheduler (from Sprint 5) into the morning plan flow.
    *   Build the Focus module featuring a Pomodoro timer linked to a task, logging sessions to `focus_sessions`.
*   **Done When:** A user can select Top 3 tasks, run the auto-scheduler to fill the timeline, and complete a focus session. (COMPLETED)

### Sprint 10: Mobile UI - Habits, Notes & Gamification (DONE)
*   **Tasks:**
    *   Build the Habits tab with segments for Habits and Routines (ordered steps).
    *   Build the Notes tab with segments for Markdown notes, Journal (daily prompts, mood/energy log), and Voice.
    *   Build the Me tab displaying the Level + XP bar, badges, rewards, and sync status indicator (`synced`/`syncing`/`offline`/`error`).
*   **Done When:** Users can log a habit, save a markdown journal entry, view their XP level, and check sync status. (COMPLETED)

## Phase 4: Cloud Functions & Integration

### Sprint 11: Google Calendar Sync (Edge Functions)
*   **Tasks:**
    *   Create Supabase Edge Functions: `gcal-oauth-start` (returns consent URL) and `gcal-oauth-callback` (exchanges code, saves encrypted refresh token to Vault).
    *   Write `gcal-sync` triggered by `pg_cron` (every 5 min) to pull events from selected calendars and upsert into `calendar_events`.
    *   Write `gcal-push` as a DB webhook to push `time_blocks` to the dedicated "Axis" calendar.
    *   Write `gcal-disconnect` to revoke tokens and clean up `calendar_secrets`.
*   **Done When:** Calendar events flow into the local database automatically, and time blocks push to Google Calendar.
