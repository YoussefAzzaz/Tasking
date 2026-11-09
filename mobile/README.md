# Axis (Flutter App)

The unified Flutter application powering **Axis Mobile** (Android & iOS) and **Axis Desktop Command Center** (Windows, macOS, Linux).

---

## 🚀 Running the App

### Mobile
```bash
flutter run
```

### Desktop (Windows)
```bash
flutter run -d windows
```

### Build Windows MSIX
```bash
flutter pub run msix:create
```

---

## 🧪 Testing

```bash
flutter test
flutter analyze
```

---

## 📁 Architecture Overview

* **`lib/core/`**: Obsidian Kinetic design tokens, global themes, audio/cache services, and atomic UI widgets.
* **`lib/data/`**: Repositories, models, PowerSync SQLite database definitions, and Supabase client integration.
* **`lib/domain/`**: Pure algorithmic engines (AutoScheduler, QuickAddParser, Gamification, Badges).
* **`lib/ui/shell/`**: Responsive application shell routing between mobile bottom-navigation and desktop sidebar.
* **`lib/ui/desktop/`**: High-density desktop command center layout, screens, omnibar, and widgets.
* **`lib/ui/`**: Feature-specific mobile screens (Today, Tasks, Habits, Focus, Notes).
