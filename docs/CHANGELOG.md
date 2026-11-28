# AXIS: Changelog

## Versioning Policy (10-Patch Rollover)
- Minor version increments only after reaching patch `.10`: `x.y.0` through `x.y.10` increment the patch digit, then roll over to `x.(y+1).0` (e.g., `1.2.10` -> `1.3.0`, staying on `1.3.x` until `1.3.10`, then `1.4.0`), encoded in `SemanticVersion.nextAxisReleaseVersion()`.
- UI labels display only the semantic version (`v1.3.0`) without internal build numbers.

## v1.3.2: Weekly Repeating Tasks & Non-Blocking Prayer/Habit Scheduling
- Fixed task collision and scheduling in [CalendarScheduler](mobile/lib/domain/calendar_scheduler.dart), [CreateTaskSheet](mobile/lib/ui/tasks/create_task_sheet.dart), and [TaskFormService](mobile/lib/ui/tasks/services/task_form_service.dart) so habits and prayers never block, displace, or reschedule tasks away from their scheduled time.
- Added weekly repeating tasks (`RRULE:FREQ=WEEKLY;BYDAY=...`) with interactive weekday pills in [TaskRecurrenceSelector](mobile/lib/ui/tasks/widgets/task_recurrence_selector.dart), `90m`/`120m` quick duration presets, multi-week calendar projection across mobile & desktop calendars, and automatic next-occurrence generation on completion in [TaskRepository](mobile/lib/data/task_repository.dart).

## v1.3.1: Wi-Fi OTA Downloader & Prayer Widget Routing Fix
- Added [NativeUpdateDownloader.kt](mobile/android/app/src/main/kotlin/com/axis/axis/NativeUpdateDownloader.kt) using Android's OS active network (`ConnectivityManager` + `HttpURLConnection`) with explicit connect/read timeouts, `Connection: close`, `Accept-Encoding: identity`, and retry fallback so update checks and APK downloads no longer stall over Wi-Fi.
- Added per-chunk stream inactivity timeouts in [AppUpdateService](mobile/lib/data/updates/app_update_service.dart) and surfaced failed network checks in mobile/desktop update cards.
- Fixed [PrayerTimesWidgetProvider.kt](mobile/android/app/src/main/kotlin/com/axis/axis/PrayerTimesWidgetProvider.kt) launch URI (`axis://widget/today`) and added `/prayers` + `onException` fallback in [router.dart](mobile/lib/core/router.dart) so tapping the prayer widget never hits a router error.

## v1.3.0: Widget Speed, Prayer Strip Layout & Me Screen Redesign
- Sped up home-screen widget launches by removing the native splash immediately on widget entry, deferring background cleanup after DB/auth initialization, and bypassing `/splash` when an active session exists.
- Updated prayer countdown logic (`computeNextPrayer`) to advance immediately once a prayer is marked prayed, sorted the 4x1 prayer strip left-to-right from Fajr (`الفجر`) to Isha (`العشاء`), formatted the Gregorian date in English (`Tue, 24 Nov`), and added separators between Chourok/Hijri and between prayers/next-prayer countdown.
- Moved the Sign Out / Sign In action into the mobile Me screen top app bar (replacing the cloud icon) and placed the cloud connection status card directly beneath the user profile card.
- Redesigned the mobile update card, update log modal, and OTA notice modal buttons to avoid cramping and hide internal build numbers.

## S12: Unified Flutter Desktop Command Center & C# Deprecation
- Implemented high-density Desktop Command Center natively in Flutter (`mobile/lib/ui/desktop/`).
- Added Command Deck, Projects & Tasks Matrix, 3-Column Notes Vault, Focus Timers Cockpit, Prayer & Habits Telemetry, and Omnibar (`Ctrl+K`).
- Configured native Windows MSIX packaging (`msix: ^3.16.8`) and custom desktop window frame sizing.
- Deprecated and removed legacy C# desktop solution (`desktop/`), establishing Flutter as the single unified cross-platform client.

## S10: Mobile UI — Habits, Notes & Gamification
- Added `HabitsScreen` displaying top streak status (Streak Hero Cockpit Card) and Habit Lists.
- Added `NotesScreen` with Journaling component and Recent Notes listing.
- Added `MeScreen` with User Profile, Gamification stats (Mastery Badges), and sync status.

## S09: Mobile UI — Today Plan & Focus
- Implemented `TodayScreen` using the Smart Auto-Scheduler UI and Gamification HUD.
- Displayed AI insights and timeline slot UI matched to Obsidian Kinetic design language.
- Mapped screens to the GoRouter app shell.

## S08: Mobile UI — Tasks & Navigation

- Created `core/theme.dart` encoding the full **Obsidian Kinetic** design system from `DESIGN.md` — Space Grotesk headlines, Geist body, Space Mono labels, all color tokens.
- Created `core/widgets.dart` with atomic components: `AxisCard` (glass tier 1/2 with backdrop blur), `AxisChip`/`PriorityChip` (pill badges), `XpBar` (emerald→cyan animated gradient), `StreakBadge`, `AxisCheckbox` (spring animation), `AxisButton`.
- Built `TaskCard` with lead checkbox, Geist title, pill tag cluster, and Space Mono trailing estimate — matches DESIGN.md §Task Cards spec.
- Built `QuickAddButton` orb (indigo→cyan gradient) + bottom sheet with live parser chips that extract metadata as-you-type.
- Built `TasksScreen` with 4-segment pill TabBar (Inbox / Upcoming / Projects / Filters) backed by PowerSync stream.
- Built `TaskDetailSheet` — draggable, glass tier 2, metadata rows with icons, delete action.
- Configured GoRouter `ShellRoute` + custom `AppShell` with a 5-slot bottom nav: Today | Tasks | **[+]** | Habits | Notes.

## S07: Mobile Infrastructure & Data Layer

- Added Flutter dependencies: `supabase_flutter`, `powersync`, `sqlite_async`, `flutter_riverpod`, `go_router`, `rrule`, `google_fonts`.
- Implemented `powersync_db.dart` initializing local SQLite database and mapping SPEC.md entities to PowerSync schemas.
- Implemented `SupabaseConnector` to handle JWT authentication and syncing data.
- Built `TaskRepository` to map local SQLite rows directly to Dart domain models.
- Set up global `DomainEvents` stream bus for cross-feature reactivity.

## S06: Gamification, Streaks & Filters Logic

- Generated `contract/filters.json`, `contract/streaks.json`, and `contract/xp.json` outlining core business rules.
- Implemented `GamificationEngine`, `StreakEngine`, and `FilterEngine` in C# (`desktop/Axis.Core`).
- Implemented `GamificationEngine`, `StreakEngine`, and `FilterEngine` in Dart (`mobile/lib/domain`).
- All tests pass, successfully concluding Phase 2 (Core Domain Logic & Shared Contracts).

## S05: Recurrence & Auto-Scheduler Logic

- Generated `contract/recurrence.json` for RRULE parsing edge-cases (`fixed` vs `after_completion` evaluation).
- Generated `contract/scheduler.json` for deterministic greedy time block allocation.
- Implemented `RecurrenceEngine` and `AutoScheduler` in C# (`desktop/Axis.Core`).
- Implemented `RecurrenceEngine` and `AutoScheduler` in Dart (`mobile/lib/domain`).
- All tests pass, guaranteeing identical offline auto-scheduling on both platforms.

## S04: Task Quick-Add Parser

- Generated `contract/quickadd.json` with multi-case parsing vectors
- Implemented `QuickAddParser.cs` in `Axis.Core` parsing priority, project, tags, estimate, recurrence, time, and dates with fallback logic
- Implemented `quick_add_parser.dart` in Flutter app with identical natural language extractions
- Both implementations successfully passed test vectors, extracting clean metadata while removing tokens from the title

## S03: Deterministic IDs & Global Constants

- Generated `contract/ids.json` with UUIDv5 deterministic ID test vectors using namespace `3f2b8c1e-6d4a-4e7b-9a52-1c8d0f7e4b11`
- Created Flutter mobile project in `mobile/` and implemented `IdGenerator` in Dart
- Created C# library `Axis.Core` in `desktop/` and implemented `IdGenerator` in C# (with custom endian-swap logic to match standard network-byte order UUIDs)
- Both Dart and C# implementations pass tests against `ids.json`

## S02: PowerSync Setup & Sync Rules

- Wrote `backend/powersync/sync-rules.yaml` — per-user bucket covering all 24 synced tables; `calendar_connections` + `calendar_events` read-only; `calendar_secrets` and `local_files` explicitly excluded
- Wrote `backend/powersync/powersync.yaml` — self-hosted PowerSync service config (env-var driven, SSL disabled)
- Wrote `backend/powersync/docker-compose.yml` — local dev stack (PowerSync + MongoDB configured as replica set)
- Wrote `backend/powersync/.env.example` — template for local dev secrets (`PS_` prefixed)
- Migration `20261001000001_powersync_publication.sql` — creates `powersync` Postgres publication covering the 24 synced tables, including truncate support

## S01: Repository & Database Schema

- Created root repository structure: `docs/`, `contract/`, `backend/`, `mobile/`, `desktop/`
- Initialized Supabase project under `backend/supabase/`
- Wrote initial SQL migration `20261001000000_initial_schema.sql` covering all tables from SPEC.md §4
- Applied Row Level Security (RLS) on every synced table
- Created placeholder docs: `QUESTIONS.md`, `CHANGELOG.md`, `DEPENDENCIES.md`, `IDEAS.md`
- Created `contract/README.md` describing the contract-vector approach
