# Axis — Personal Operating System for Discipline & Focus

<p align="center">
  <strong>Unified Offline-First Productivity Suite for Mobile & Desktop</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/PowerSync-Offline--First-059669" alt="PowerSync">
  <img src="https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase" alt="Supabase">
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-blueviolet" alt="Platforms">
  <img src="https://img.shields.io/badge/Tests-311%20Passed-brightgreen" alt="Tests">
</p>

---

## ⚡ Overview

**Axis** is an offline-first personal productivity and discipline operating system. It unifies high-density task management, flexible habit tracking, prayer telemetry, focus sprints, markdown journaling, and RPG gamification into a single high-performance **Flutter** application for both mobile and desktop.

Axis operates on a disciplined daily cadence:
$$\text{Capture} \longrightarrow \text{Plan} \longrightarrow \text{Focus} \longrightarrow \text{Review} \longrightarrow \text{Reflect}$$

---

## 🖥️ Cross-Platform Architecture

Axis is engineered as a **single, unified Flutter codebase** providing dedicated, layout-tailored experiences based on display resolution and platform:

```
┌────────────────────────────────────────────────────────┐
│                      AXIS APP                          │
├───────────────────────────┬────────────────────────────┤
│      Mobile Layout        │  Desktop Command Center    │
│  (Phones & Small Screens) │  (Windows, macOS, Linux)   │
├───────────────────────────┴────────────────────────────┤
│             Core Domain & Gamification Engine          │
│   (Quick-Add, Streaks, Recurrence, Auto-Scheduler, XP) │
├────────────────────────────────────────────────────────┤
│           Local SQLite Database (PowerSync)            │
└───────────────────────────┬────────────────────────────┘
                            │  Streaming Replication
                            ▼
          Supabase Backend (PostgreSQL + RLS)
```

### 📱 Mobile Experience
* Optimized for one-thumb speed with bottom navigation rails and quick actions.
* Natural language Quick-Add sheet (`"Submit PR tmr at 5pm #work p1 @code 45m every weekday"`).
* Home-screen widgets for instant today's task checklist and prayer timings.
* Native system notifications and alarms for Adhan and time blocks.

### 💻 Desktop Command Center
* **Command Deck Dashboard:** Real-time telemetry, live ticking clock, active focus sprint, daily milestone gauge, and top priorities.
* **Projects & Tasks Matrix:** High-density table with interactive status rails, priority chips, tags, and inline scheduling.
* **3-Column Notes Vault:** Category sidebar, searchable note list stream, and live Markdown editor with tag backlinks.
* **Focus Timers Cockpit:** Fullscreen Zen Pomodoro timer with ambient soundscapes and session logs.
* **Prayer & Habits Telemetry:** 5-daily prayer board, habit streak heatmaps, and companion accountability feed.
* **Desktop Omnibar (`Ctrl + K`):** Global keyboard shortcut search and instant task/habit creation modal.
* **Native Windows MSIX:** Integrated titlebar controls, window state management, and MSIX packaging.

---

## ✨ Core Modules

| Module | Features |
|---|---|
| **Tasks & Projects** | 3-tier priority matrix (P1 High, P2 Medium, P3 Low), subtasks, estimate minutes, recurring RRULE intervals, auto-scheduler, tag filtering, and soft deletes. |
| **Daily Rhythm** | Morning plan flow, Top 3 focus tasks, evening retrospective review, and automated day schedule recommendations. |
| **Habits & Streaks** | Boolean and numeric habits, daily/weekly/interval frequencies, consecutive day streaks, freeze allowances, and completion heatmaps. |
| **Prayer & Telemetry** | Local GPS & astronomical calculation for Fajr, Dhuhr, Asr, Maghrib, and Isha; companion accountability; real-time streak broadcasts. |
| **Deep Work Focus** | Customizable Pomodoro intervals (work / short break / long reboot), linked task session tracking, and ambient noise generators. |
| **Notes & Journal** | Obsidian Kinetic design, Markdown editor, daily journal reflection prompts, mood/energy rating check-ins, and audio voice logs. |
| **Gamification Engine** | Deterministic XP awards (on-time bonus, high-priority multipliers), levels with quadratic progression, unlockable badge tiers, and custom reward shop. |
| **Offline-First Sync** | Local SQLite storage via PowerSync SDK with automatic bi-directional streaming synchronization to Supabase Postgres. |

---

## 🛠️ Tech Stack

* **UI Framework:** [Flutter](https://flutter.dev) (Dart 3.x)
* **Local Database:** SQLite via [PowerSync Flutter SDK](https://docs.powersync.com)
* **Backend:** [Supabase](https://supabase.com) (PostgreSQL 15+, Row-Level Security, Auth, Storage, RPC functions)
* **State Management & Routing:** Flutter ChangeNotifier & ValueNotifier patterns, `go_router`
* **Desktop Packaging:** [msix](https://pub.dev/packages/msix) for Windows Store & Enterprise deployment
* **Audio & Media:** `just_audio`, `record`
* **Local Notifications:** `flutter_local_notifications`, `timezone`

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.47.0`, bundling Dart `^3.13.4`)
* For Windows Desktop: Visual Studio 2022 C++ build tools & Windows 10/11 SDK

### 1. Clone the Repository
```bash
git clone https://github.com/YoussefAzzaz/Tasking.git
cd Tasking
```

### 2. Configure Backend & Environment
Copy the example environment file and apply Supabase database migrations:

```bash
# Copy environment configuration from repository root:
cp mobile/.env.example mobile/.env

# Apply Supabase database migrations (from repository root where backend/supabase/ lives):
supabase db push
```

### 3. Run the App

Navigate into the `mobile/` directory:
```bash
cd mobile
flutter pub get
```

#### Mobile (Android / iOS):
```bash
flutter run
```

#### Desktop (Windows):
```bash
flutter run -d windows
```

### 4. Build Windows MSIX Package
```bash
flutter pub run msix:create
```
The generated `.msix` bundle will be created in `mobile/build/windows/x64/runner/Release/`.

---

## 🧪 Testing & Code Quality

Run the comprehensive unit, widget, and integration test suite:

```bash
cd mobile
flutter test
```

Run static analysis:
```bash
cd mobile
flutter analyze
```

---

## 📁 Repository Structure

```
.
├── backend/
│   ├── powersync/           # PowerSync sync rules & schema configuration
│   └── supabase/            # Postgres migrations, RLS policies, and RPC functions
├── contract/                # Frozen JSON test vectors for core domain logic
├── Design/                  # Stitch UI designs & design system documentation
├── mobile/                  # Unified Flutter application (Mobile & Desktop)
│   ├── android/             # Android native platform configuration & widgets
│   ├── ios/                 # iOS native platform configuration
│   ├── windows/             # Windows native runner & window initialization
│   ├── lib/
│   │   ├── core/            # Theme, localizations, cache, and common widgets
│   │   ├── data/            # Repositories, models, PowerSync DB, and Supabase client
│   │   ├── domain/          # Domain engines (AutoScheduler, QuickAddParser, Gamification)
│   │   └── ui/
│   │       ├── desktop/     # Desktop Command Center screens, shell, and widgets
│   │       ├── shell/       # Responsive application shell router
│   │       └── ...          # Mobile screens (Today, Tasks, Habits, Focus, Notes)
│   └── test/                # Unit and widget test suite (310+ test cases)
└── SPEC.md                  # Detailed product & technical specification
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
