# AXIS: Product & Technical Specification (v1)

> Working name: **Axis**. This document is the single source of truth. If code and this spec disagree, the spec wins. If the spec is ambiguous, write the question in `docs/QUESTIONS.md`, pick the simplest option that fits the spec, and continue.

---

## 1. Product summary

Axis is a **personal, offline-first productivity app** for one user (no collaboration). It helps the user be more disciplined by running one loop every day:

**Capture → Plan the day → Do (focus) → Review → Reflect**

It runs as a **unified cross-platform Flutter application**:
- **Mobile** (Android & iOS)
- **Desktop Command Center** (Windows, macOS, Linux)

Both platforms share the same core domain engine and local SQLite database, syncing automatically through **PowerSync** to a **Supabase (Postgres)** backend. Everything works completely offline.

### Feature modules
| # | Module | Summary |
|---|---|---|
| 1 | Tasks | Inbox, projects, subtasks, due date/time, 3 priorities, estimates, recurrence, reminders, tags, saved filters, quick-add with natural-language parsing |
| 2 | Daily planning | Top 3, morning plan flow, evening review, day timeline with time blocks, auto-scheduler, workload warning |
| 3 | Calendar sync | Two-way Google Calendar sync done server-side (events shown on timeline; time blocks pushed to a dedicated "Axis" calendar) |
| 4 | Habits & routines | Boolean/numeric habits, flexible schedules, streaks, skip, heatmap, routines (ordered steps) with run mode |
| 5 | Focus | Pomodoro timer linked to a task, sessions logged |
| 6 | Notes & journal | Markdown notes, daily journal with prompts, mood/energy check-in, voice notes with automatic transcription |
| 7 | Gamification | XP, levels, badges, user-defined rewards bought with XP |
| 8 | Insights | One weekly review screen |
| 9 | Widgets | Android home-screen widget (iOS optional) |

### Explicit non-goals (do NOT build, even if tempting)
Collaboration/sharing, Kanban, Gantt, task dependencies, goal/OKR hierarchy, AI chat assistant, finance/health/grocery modules, location reminders, app/website blocking, desktop widgets, email-to-task, third-party integrations other than Google Calendar.

---

## 2. Tech stack

| Layer | Choice |
|---|---|
| Client (Unified) | Flutter (stable), Dart, `go_router`, `powersync` (Flutter SDK), `supabase_flutter`, `flutter_local_notifications` + `timezone`, `rrule`, `record`, `just_audio`, `home_widget`, `flutter_markdown`, `uuid`, `msix` |
| Local DB | **SQLite**, managed by the PowerSync Flutter SDK (no other local DB layer) |
| Sync | **PowerSync** (client SQLite ⇄ Postgres) |
| Backend | **Supabase**: Postgres, Auth (email + password), Storage, Edge Functions (Deno/TypeScript), `pg_cron`, Vault |
| External | Google Calendar API (via Edge Functions only), a speech-to-text API for voice notes (via Edge Function only) |

**Why SQLite locally and Postgres on the server:** PowerSync's design is a SQLite replica of Postgres. No other embedded database syncs to Postgres this way, so this pairing is the optimal one for this app. Do not introduce Drift, Isar, Realm, Hive, or EF Core.

Rule: before adding any package, verify its current name, version, and API in its official docs, pin the version, and record it in `docs/DEPENDENCIES.md`.

---

## 3. Architecture

```
Flutter (Mobile: Android / iOS)      Flutter (Desktop: Windows / macOS / Linux)
      \                                        /
       └────────────── PowerSync ─────────────┘
                         │
           Supabase Postgres (RLS on every table)
                         │
      Edge Functions: gcal-*, transcribe       Storage: voice-notes
```

- **Local-first:** all reads and writes go to local SQLite. UI never waits on network.
- **Writes upload** through the PowerSync connector's `uploadData`, which applies each CRUD op to Supabase (PUT→upsert, PATCH→update, DELETE→delete). Error handling: network/5xx errors = retry; Postgres errors in class 22/23 or code 42501 (bad data / constraint / RLS) = log, then complete the transaction so the queue is never blocked.
- **Conflicts:** last-write-wins per row (PowerSync default). Design data so this is safe (see deterministic IDs §4.7).
- **Network calls from UI are allowed only for:** auth, calendar-connect/sync-now function calls, and the voice-note upload queue.
- **Business logic that must behave identically on both platforms** (parser, recurrence, filters, streaks, scheduler, XP/levels, IDs) is specified in §6 and verified by shared JSON test vectors in `/contract` (see §11).
- **Google Calendar and transcription run server-side only**, so they are implemented once.

### 3.1 Global data conventions
| Concept | Convention |
|---|---|
| Primary key | `id` text UUID. Random v4 unless §4.7 says deterministic |
| Ownership | every synced table has `user_id` (uuid, equals `auth.uid()`); RLS: select/insert/update/delete only where `user_id = auth.uid()` |
| Common columns | `id`, `user_id`, `created_at`, `updated_at`, `deleted_at` on every table (unless noted) |
| Deletion | **soft delete only** (`deleted_at` set). Every query filters `deleted_at IS NULL` |
| Timestamps (`ts`) | ISO-8601 UTC string with `Z`, e.g. `2026-10-05T14:30:00Z` |
| Dates (`date`) | `YYYY-MM-DD` in the **user's timezone** (`user_settings.timezone`) |
| Times (`time`) | `HH:MM` 24h local time |
| Booleans | integer `0`/`1` locally, `boolean` in Postgres |
| Ordering | `sort_order` real number (fractional insert between neighbours) |
| "Today" | computed from an injectable `Clock` + user timezone. Never call `DateTime.now()` / `DateTime.Now` directly in logic |
| Priority | integer: `0` none, `1` low, `2` medium, `3` high |

---

## 4. Data model (schema is law)

Column names are snake_case and **identical** in Postgres, the Dart schema, and the SQLite schema. `+common` means the five common columns from §3.1.

### 4.1 Core tables
| Table | Columns (besides +common) |
|---|---|
| `user_settings` (id = user_id) | timezone, week_starts_on (1=Mon..7=Sun, default 1), work_start (`09:00`), work_end (`17:30`), default_estimate_min (30), buffer_min (5), focus_work_min (25), focus_break_min (5), focus_long_break_min (15), focus_cycles_before_long (4), morning_plan_time (`08:30`), evening_review_time (`21:00`), theme (`system`/`light`/`dark`), animations_enabled (1), sounds_enabled (1) |
| `projects` | name, color (hex), icon (emoji), sort_order, archived_at |
| `tasks` | project_id (null = Inbox), parent_task_id, title, notes, status (`todo`/`done`/`cancelled`), priority, due_date, due_time, estimate_min, recurrence_rule (RRULE string without DTSTART), recurrence_mode (`fixed`/`after_completion`), series_id, remind_at (ts), completed_at (ts), completed_date (date), sort_order |
| `tags` | name, color |
| `task_tags` | task_id, tag_id |
| `saved_filters` | name, query_json, sort_order |

### 4.2 Planning tables
| Table | Columns |
|---|---|
| `daily_plans` | plan_date, top1_task_id, top2_task_id, top3_task_id, planned_at (ts), reviewed_at (ts), reflection |
| `time_blocks` | task_id (nullable), title (nullable, for non-task blocks), start_at (ts), end_at (ts), source (`manual`/`auto`), external_event_id (server-written) |
| `focus_sessions` | task_id (nullable), kind (`work`/`break`), planned_min, actual_min, started_at (ts), ended_at (ts, null while running), completed (bool) |

### 4.3 Habit tables
| Table | Columns |
|---|---|
| `habits` | name, icon, color, kind (`boolean`/`numeric`), target_value, unit, schedule_type (`daily`/`weekdays`/`times_per_week`/`every_n_days`), schedule_days (CSV of ISO weekdays, e.g. `1,3,5`), schedule_n (N for times_per_week or every_n_days), start_date, remind_time, sort_order, archived_at |
| `habit_logs` | habit_id, log_date, status (`done`/`skipped`), value (real), note |
| `routines` | name, kind (`morning`/`evening`/`custom`), remind_time, sort_order, archived_at |
| `routine_steps` | routine_id, title, duration_min (nullable), sort_order |
| `routine_runs` | routine_id, run_date, started_at (ts), completed_at (ts), steps_done, steps_total |

### 4.4 Notes, mood, voice
| Table | Columns |
|---|---|
| `notes` | title, body_md, pinned (bool), project_id, task_id |
| `journal_entries` | entry_date, body_md, template_key |
| `mood_logs` | logged_at (ts), log_date, mood (1–5), energy (1–5), note |
| `voice_notes` | recorded_at (ts), duration_sec, storage_path, upload_status (`local`/`uploading`/`uploaded`/`failed`), transcript, transcript_status (`none`/`pending`/`done`/`failed`), task_id, note_id |
| `local_files` (**local-only**, never synced) | id, voice_note_id, path |

### 4.5 Gamification
| Table | Columns |
|---|---|
| `xp_events` | source_type, source_id, event_date, xp (int ≥ 0), reason |
| `badge_unlocks` | badge_key, unlocked_at (ts) |
| `rewards` | name, description, cost_xp, active (bool) |
| `reward_redemptions` | reward_id, xp_spent, redeemed_at (ts) |

### 4.6 Calendar (server-written; clients are **read-only**)
| Table | Columns |
|---|---|
| `calendar_connections` | provider (`google`), email, status (`active`/`error`/`revoked`), selected_calendar_ids (JSON text), push_calendar_id, last_synced_at (ts) |
| `calendar_events` | connection_id, external_id, calendar_name, title, start_at (ts), end_at (ts), all_day (bool) |
| `calendar_secrets` (**server-only**, never in sync rules, no client policies) | connection_id, encrypted_refresh_token, sync_tokens (JSON) |

The upload connector must **skip** writes to `calendar_connections` and `calendar_events` except the `selected_calendar_ids` field, which is written via an Edge Function, not directly.

### 4.7 Deterministic IDs (prevents duplicates when two devices act on the same thing)
ID = UUIDv5(namespace `3f2b8c1e-6d4a-4e7b-9a52-1c8d0f7e4b11`, name). Verified by `contract/ids.json`.

| Row | Name string |
|---|---|
| `user_settings` | the user's id (use the id itself) |
| `daily_plans` | `plan:{plan_date}` |
| `journal_entries` | `journal:{entry_date}` |
| `habit_logs` | `habit:{habit_id}:{log_date}` |
| `xp_events` | `xp:{source_type}:{source_id}:{event_date}` |
| `badge_unlocks` | `badge:{badge_key}` |
| next recurring task instance | `task:{series_id}:{due_date}` |

Re-doing an action (e.g. un-complete then complete) must **revive** the same row (`deleted_at = null`), not create a second one.

---

## 5. Domain events (decouples features from XP/badges/widgets)

A global in-process `DomainEvents` bus exists from the first task sprint. Features **emit**; later modules **subscribe**. Until subscribed, emits are no-ops.

`TaskCompleted(taskId, date, priority, isSubtask, dueDate)`, `TaskUncompleted(taskId, date)`, `HabitDone(habitId, date, streakAfter)`, `HabitUndone(habitId, date)`, `RoutineCompleted(runId, date)`, `FocusCompleted(sessionId, date, minutes)`, `MorningPlanSet(planId, date)`, `Top3AllDone(planId, date)`, `EveningReviewDone(planId, date)`, `JournalSaved(entryId, date, length)`, `MoodLogged(date)`.

---

## 6. Business rules (must be implemented identically on both platforms)

### 6.1 Quick-add grammar (`parse(text, now, tz, projects, tags)`)
Returns `{title, due_date, due_time, priority, project_id, tag_names, estimate_min, recurrence_rule, recurrence_mode}`. Tokens are case-insensitive, removed from the title, and can appear anywhere. Anything unrecognised stays in the title. Collapse multiple spaces; trim.

| Token | Meaning |
|---|---|
| `p1` / `p2` / `p3` | priority high(3) / medium(2) / low(1) |
| `#name` | project whose name matches case-insensitively (no match → token stays in title) |
| `@name` | tag (created on save if it doesn't exist) |
| `today`, `tod` | today |
| `tomorrow`, `tmr` | today + 1 |
| `mon`..`sun` (also full names) | the next such weekday strictly after today (if today is Monday, `mon` = +7 days) |
| `in N days` / `in N weeks` | today + N days / weeks |
| `YYYY-MM-DD` | that date |
| `at 6pm`, `at 6:30pm`, `at 18:00`, `18:00` | due_time (24h `HH:MM`). A time without a date implies today |
| `30m`, `1h`, `1h30m` | estimate_min |
| `every day` | `FREQ=DAILY`; `every weekday` | `FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR`; `every mon` | `FREQ=WEEKLY;BYDAY=MO`; `every N days/weeks/months` | `FREQ=…;INTERVAL=N`; `every month` | `FREQ=MONTHLY`. A recurrence without a date sets due_date = today (or next matching day for `every mon`) |
| `after completion` / `ac` suffix after an `every` phrase | recurrence_mode = `after_completion` (default `fixed`) |

Example: `Call mom tmr at 6pm #family p1 @phone 15m` → title `Call mom`, due tomorrow, 18:00, project Family, priority 3, tag phone, estimate 15.

### 6.2 Recurrence
- Store only the RRULE string (no DTSTART); anchor is the task's `due_date`.
- `fixed`: next date = next occurrence of the rule strictly after the **current due_date**; if that is still in the past, keep advancing until it is ≥ today.
- `after_completion`: next date = completed_date shifted by the rule's interval (`INTERVAL` × `FREQ`); for weekly-by-weekday rules, use next matching weekday after completed_date.
- Monthly on day 29–31 clamps to the last day of shorter months.
- **On completing** a recurring task: mark done, then insert the next instance (copy of title, notes, project, priority, estimate, recurrence fields, tags, series_id; subtasks copied unchecked; `remind_at` shifted by the same delta). If `series_id` is empty, set it to the task's own id first. Next-instance id is deterministic (§4.7). If it already exists and isn't deleted, do nothing.
- The UI "Undo" snackbar right after completing reverts completion **and** soft-deletes the generated instance.

### 6.3 Filters
`query_json`:
```json
{"op":"and","conditions":[
  {"field":"priority","cmp":"gte","value":2},
  {"field":"tag","cmp":"in","value":["<tag_id>"]},
  {"field":"due","cmp":"within_days","value":7},
  {"op":"or","conditions":[ ... ]}
]}
```
Fields and comparators: `status` (`eq`,`in`), `priority` (`eq`,`gte`,`lte`), `project` (`eq`,`in`,`none`), `tag` (`in`,`none`), `due` (`overdue`,`today`,`within_days`,`none`,`before`,`after`), `has_estimate` (`eq` true/false), `text` (`contains`, case-insensitive on title+notes). Filters are evaluated **in memory** over loaded, non-deleted tasks (subtasks excluded unless `include_subtasks:true` at root).

### 6.4 Streaks
A log is `done` or `skipped`. **No log on a scheduled day = missed.** `done` for numeric habits means `value >= target_value`.

- **Scheduled days:** `daily` = every day from start_date; `weekdays` = days in `schedule_days`; `every_n_days` = start_date + k·N.
- **Current streak (day-based):** walk backwards through scheduled days starting at the most recent scheduled day ≤ today. If that day is **today** and has no log, skip it (neither counts nor breaks). Then: `done` → +1; `skipped` → continue without counting; missed → stop.
- **times_per_week (N):** weeks start on `week_starts_on`. A week succeeds if it has ≥ N `done` logs. Streak = consecutive successful weeks ending at the last *finished* week, plus the current week if it already has ≥ N.
- **Best streak:** maximum run found with the same rules over the full history.

### 6.5 Auto-scheduler (pure function, deterministic, no AI)
Input: `date`, `now`, `work_start`, `work_end`, `buffer_min`, `default_estimate_min`, `busy` (calendar_events + existing time_blocks as intervals), `tasks` (candidates). Output: `{proposed: [{task_id,start,end}], unplaced: [{task_id,reason}], available_min, planned_min}`.

1. Free windows = `[max(work_start, now rounded UP to next 15 min if date is today), work_end]` minus `busy` intervals; discard windows shorter than 15 min. All-day events are ignored.
2. Candidates sorted by: Top-3 tasks first (in slot order) → overdue → earlier due_date → higher priority → shorter estimate → earlier created_at.
3. Duration = `estimate_min` or `default_estimate_min`, rounded up to 15 min.
4. Place each task greedily in the **earliest** free window that fits `duration`; after placing, consume `duration + buffer_min`. Tasks are never split. A task that doesn't fit → `unplaced` with reason `no_room`.
5. If a task has `due_time` earlier than the slot found, still place it but it is reported with reason `after_due_time` in a `warnings` list.
6. `available_min` = total free minutes (before placing). `planned_min` = sum of durations of all candidates. **Workload warning** when `planned_min > available_min`.

### 6.6 XP, levels, badges, rewards
**XP awards** (all are idempotent via deterministic `xp_events` ids; revoking sets `deleted_at`):

| Event | XP |
|---|---|
| Task completed | none/low = 5, medium = 10, high = 20; **+5** if `due_date` set and completed_date ≤ due_date |
| Subtask completed | 2 flat (no bonus) |
| Habit done | 10 + min(streakAfter, 10) |
| Routine completed (all steps done) | 15 |
| Focus session completed (work, ≥ 10 min) | 1 per minute |
| Morning plan set (≥ 1 top task) | 5 |
| All Top 3 completed in a day | 25 |
| Evening review done | 10 |
| Journal saved (≥ 20 chars), once/day | 5 |
| Mood logged, once/day | 2 |

**Daily caps (anti-farming):** max 25 task XP events per day, max 120 focus XP per day. Beyond the cap, no event is written.

**Levels:** `xp_to_reach(n) = 50·n·(n−1)` (L1=0, L2=100, L3=300, L4=600, …). Level = largest n with `xp_to_reach(n) ≤ total_earned`. `total_earned` = sum of non-deleted `xp_events.xp`. **Balance** = total_earned − sum(`reward_redemptions.xp_spent`). Level uses total_earned only (spending never lowers level).

**Badges** (key → unlock rule; evaluated after each XP award and on app start; id deterministic so no duplicates):
`first_task` (1 task done), `tasks_100`, `tasks_1000`, `streak_7`, `streak_30`, `streak_100` (any habit's best/current streak), `first_focus`, `focus_10h` (600 min total), `focus_100h`, `level_5`, `level_10`, `top3_week` (Top 3 all done on 5 different days in one week), `review_7` (7 consecutive evening reviews), `journal_7` (7 consecutive days with entries), `voice_first` (first transcribed voice note).

**Rewards:** user creates rewards with `cost_xp`. Redeem is allowed only if balance ≥ cost; it inserts a `reward_redemptions` row. Rewards are honour-system treats; no automation.

---

## 7. Screens & navigation

**Mobile:** bottom bar with 5 tabs + a floating Quick-Add button available on Today/Tasks.
**Desktop:** left sidebar with the same 5 sections + global Quick-Add (Ctrl+N in app, Ctrl+Alt+Space anywhere).

| Tab | Content |
|---|---|
| **Today** | Date + counts; morning-plan card; **Top 3**; Overdue + Today tasks; habits due today; routines for today; mood check-in card; focus minutes; evening-review card (after review time); toggle **List \| Timeline** |
| **Tasks** | Segments: **Inbox \| Upcoming \| Projects \| Filters** |
| **Habits** | Segments: **Habits \| Routines** |
| **Notes** | Segments: **Notes \| Journal \| Voice** |
| **Me** | Level + XP bar, badges, rewards, weekly review, settings (account, timezone, work hours, focus, notifications, calendars, tags, theme, export/delete data), sync status |

Task detail (sheet on mobile, right panel on desktop): title, notes, due date/time, priority, estimate, project, tags, recurrence, reminder, subtasks, linked notes, "Start focus", time block chip.

Global UI states: a sync-status indicator (`synced` / `syncing` / `offline` / `error`) is always reachable.

---

## 8. Backend functions (Supabase Edge Functions)

| Function | Trigger | Job |
|---|---|---|
| `gcal-oauth-start` | called by client with user JWT | returns Google consent URL (offline access; scopes: calendar.events, calendar.readonly; `state` = signed JWT containing user_id) |
| `gcal-oauth-callback` | Google redirect | exchanges code, stores encrypted refresh token in `calendar_secrets` (Vault), upserts `calendar_connections`, creates secondary calendar "Axis" and saves `push_calendar_id` |
| `gcal-sync` | `pg_cron` every 5 min + client "Sync now" | pulls events (−7…+60 days) from selected calendars using incremental `syncToken`; upserts/deletes `calendar_events`; handles 410 by full resync; ignores events tagged `axis_block_id` |
| `gcal-push` | DB webhook on `time_blocks` insert/update/delete | creates/updates/deletes the event in the Axis calendar (private extended property `axis_block_id`), writes back `external_event_id`; idempotent |
| `gcal-disconnect` | client call | revokes token, deletes secrets and the connection's events |
| `transcribe` | DB webhook when `voice_notes.upload_status = 'uploaded'` and `transcript_status = 'pending'` | downloads audio (service role), calls the configured speech-to-text API, writes `transcript` + `transcript_status` (`done`/`failed`) |

Secrets live only in Supabase secrets/Vault and local `.env` files that are git-ignored.

---

## 9. Notifications

- Mobile: `flutter_local_notifications` with exact alarms; a `ReminderScheduler` reconciles pending notifications whenever relevant data changes or the app starts (task reminders, habit reminders, morning plan, evening review, focus-end).
- Desktop: toasts while the app is running (tray keeps it alive). On startup, show reminders missed in the last 24 h.
- Notification id = stable hash of the source row id.

---

## 10. Design guidelines

- Calm, minimal, lots of whitespace. One accent colour, plus priority colours (high = red, medium = amber, low = blue).
- Light + dark theme from day one; follow system by default.
- Every list has an empty state with one clear action.
- Completing something gives a subtle response (checkbox animation; "+XP" float once gamification exists); respects `animations_enabled`.
- Never shame the user: missed habits/overdue use neutral wording ("Pending", "Missed", not "Failed").
- Touch targets ≥ 44 px on mobile; keyboard-first on desktop (Enter to save, Esc to close).

---

## 11. Repository & agent rules

```
axis/
  docs/        SPEC.md  SPRINTS.md  QUESTIONS.md  CHANGELOG.md  DEPENDENCIES.md  IDEAS.md
  contract/    ids.json quickadd.json recurrence.json filters.json streaks.json scheduler.json xp.json  (+ README.md)
  backend/     supabase/{migrations,functions,config.toml}   powersync/sync-rules.yaml
  mobile/      Unified Flutter app (lib/core, lib/data, lib/domain, lib/ui/{desktop, shell, ...})
```

**Rules for every agent session**
1. Work on **exactly one sprint**. Do not start the next one.
2. Do not build anything not in the sprint. Good ideas go to `docs/IDEAS.md`.
3. The schema in §4 is law. Never rename or add columns without stopping and asking; schema changes need a new migration and updates to the client schema in the same commit.
4. UI never touches the database or network directly: Views → ViewModels/Notifiers → Repositories/Services.
5. Pure logic (parser, recurrence, filters, streaks, scheduler, XP, IDs) has **no UI, DB, or clock dependencies** (clock is injected) and lives in `lib/domain` (Dart).
6. **Contract vectors** (`/contract/*.json`) are written from this spec by the first platform that implements the logic, then reviewed by the human and frozen. Never edit a vector to make a test pass without human approval. The second platform must pass the same files unchanged.
7. Soft delete only; always filter `deleted_at IS NULL`.
8. No silent `catch`. Show a user-facing message and write to the local log file.
9. Never commit secrets. Use `.env` / `--dart-define` / user-secrets.
10. Definition of done for every sprint: builds clean, linter clean, tests pass, the "Done when" checklist is manually verified, and a commit named `S##: title` is made.
11. Final report format: *files changed*, *how to run*, *how to test*, *Done-when checklist with ✅/❌*, *questions/assumptions*.
