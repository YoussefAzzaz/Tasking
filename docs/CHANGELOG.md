# AXIS: Changelog

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
