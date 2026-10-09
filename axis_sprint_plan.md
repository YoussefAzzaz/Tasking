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

### Sprint 9: Mobile UI - Today Plan & Focus
*   **Tasks:**
    *   Build the Today tab featuring the date, morning-plan card, Top 3 tasks, and overdue tasks.
    *   Implement the List and Timeline view toggle for the Today tab.
    *   Integrate the auto-scheduler (from Sprint 5) into the morning plan flow.
    *   Build the Focus module featuring a Pomodoro timer linked to a task, logging sessions to `focus_sessions`.
*   **Done When:** A user can select Top 3 tasks, run the auto-scheduler to fill the timeline, and complete a focus session.

### Sprint 10: Mobile UI - Habits, Notes & Gamification
*   **Tasks:**
    *   Build the Habits tab with segments for Habits and Routines (ordered steps).
    *   Build the Notes tab with segments for Markdown notes, Journal (daily prompts, mood/energy log), and Voice.
    *   Build the Me tab displaying the Level + XP bar, badges, rewards, and sync status indicator (`synced`/`syncing`/`offline`/`error`).
*   **Done When:** Users can log a habit, save a markdown journal entry, view their XP level, and check sync status.

## Phase 4: Desktop Client (WPF)

### Sprint 11: Desktop Infrastructure & Data Layer
*   **Tasks:**
    *   Initialize a .NET 8 WPF project in `desktop/Axis.sln` using `CommunityToolkit.Mvvm`, `WPF-UI`, and `Microsoft.Extensions.DependencyInjection`.
    *   Integrate the `PowerSync.Common` beta SDK and `supabase-csharp` for authentication.
    *   Implement the base repositories mapping SQLite rows to C# models, ensuring dependency injection setup.
    *   Implement the in-process `DomainEvents` bus in C#.
*   **Done When:** The WPF app authenticates, writes to local SQLite, and syncs data to Supabase.

### Sprint 12: Desktop UI - Shell & Task Management
*   **Tasks:**
    *   Build the primary window shell with a left sidebar for the 5 sections (Today, Tasks, Habits, Notes, Me).
    *   Implement global hotkeys using `NHotkey.Wpf` (Ctrl+N in app, Ctrl+Alt+Space globally) to open the Quick-Add parser.
    *   Build the Task management views and the right-panel Task Detail view.
*   **Done When:** Users can invoke global quick-add, parse a task, and edit it in the right panel.

### Sprint 13: Desktop UI - Planning, Habits & Focus
*   **Tasks:**
    *   Build the Today view with Top 3 selection, morning/evening review cards, and timeline.
    *   Build the Habits view and Routine runner.
    *   Build the Focus timer view.
*   **Done When:** Desktop users can schedule their day, run a routine, and complete a focus session matching the mobile experience.

### Sprint 14: Desktop UI - Notes, Gamification & Settings
*   **Tasks:**
    *   Implement the Markdown note editor using `Markdig`.
    *   Build the Me tab (XP, levels, badges, rewards) and settings view (theme, timezone, work hours).
    *   Configure the tray icon using `H.NotifyIcon.Wpf` to keep the app alive for background reminders.
*   **Done When:** Users can write markdown notes, view gamification stats, and minimize the app to the system tray.

## Phase 5: Cloud Functions & Integration

### Sprint 15: Google Calendar Sync (Edge Functions)
*   **Tasks:**
    *   Create Supabase Edge Functions: `gcal-oauth-start` (returns consent URL) and `gcal-oauth-callback` (exchanges code, saves encrypted refresh token to Vault).
    *   Write `gcal-sync` triggered by `pg_cron` (every 5 min) to pull events from selected calendars and upsert into `calendar_events`.
    *   Write `gcal-push` as a DB webhook to push `time_blocks` to the dedicated "Axis" calendar.
    *   Write `gcal-disconnect` to revoke tokens and clean up `calendar_secrets`.
*   **Done When:** Calendar events flow into the local database automatically, and time blocks push to Google Calendar.

### Sprint 16: Voice Notes Transcription (Edge Functions)
*   **Tasks:**
    *   Create the `transcribe` Edge Function triggered by a DB webhook on `voice_notes` when `upload_status = 'uploaded'`.
    *   Configure the function to download the audio from Supabase Storage and call a designated speech-to-text API.
    *   Update the `voice_notes` table with the `transcript` and set `transcript_status` to `done`.
*   **Done When:** Uploading an audio file to Supabase triggers the function and populates the text transcript in the database.

### Sprint 17: Notifications & Final Polish
*   **Tasks:**
    *   Implement `ReminderScheduler` on mobile using `flutter_local_notifications` for exact alarms based on `remind_at` timestamps and routines.
    *   Implement desktop toasts using `Microsoft.Toolkit.Uwp.Notifications` for active and missed reminders on startup.
    *   Wire UI components to emit and react to `DomainEvents` (e.g., `TaskCompleted`, `HabitDone`) to trigger XP and badge unlocks.
*   **Done When:** Scheduled tasks and habits trigger notifications reliably on both platforms, and completing tasks visibly updates user XP.