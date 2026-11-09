# AXIS (Flutter App)

The unified cross-platform application powering **AXIS Mobile** (Android & iOS) and **AXIS Desktop Command Center** (Windows, macOS, Linux).

---

## 🚀 Quick Start

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.24.0`, bundling Dart `^3.5.0`)
- Visual Studio 2022 with C++ desktop tools (for Windows desktop builds)
- Android Studio / Xcode (for mobile builds)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Development Mode
```bash
# Mobile (Android / iOS)
flutter run

# Windows Desktop
flutter run -d windows

# macOS Desktop
flutter run -d macos

# Linux Desktop
flutter run -d linux
```

### 4. Build Release Binaries
```bash
# Android APK
flutter build apk --release

# Android App Bundle (Google Play)
flutter build appbundle --release

# iOS IPA
flutter build ipa --release

# Windows Executable
flutter build windows --release

# Windows MSIX Package
dart run msix:create
```

---

## 🧪 Testing

Axis includes **380+ unit, widget, and stress benchmark tests**:

```bash
# Run all tests
flutter test

# Run static analysis
flutter analyze
```

---

## 📁 Architecture Overview

- **`lib/core/`**: Theme tokens, bilingual localizations (English & Arabic), TTL caching, and common cyber widgets.
- **`lib/data/`**: Repositories with pagination (`limit` & `offset`), models, PowerSync SQLite database, and Supabase client integration.
- **`lib/domain/`**: Pure algorithmic engines (AutoScheduler, QuickAddParser, RecurrenceEngine, StreakEngine, GamificationEngine).
- **`lib/ui/shell/`**: Responsive application shell routing between mobile bottom-navigation (<900px) and desktop sidebar (≥900px).
- **`lib/ui/desktop/`**: High-density desktop command center layout, screens, Omnibar (`Ctrl+K`), and kanban widgets.
- **`lib/ui/`**: Feature-specific mobile screens (Today, Tasks, Habits, Focus, Notes, Friends, Me).

For full technical specifications, architecture diagrams, and system features, refer to the [root README.md](../README.md).
