# AXIS — Agent Rules & Engineering Standards

These rules are mandatory for every AI agent, subagent, and contributor working in this repository. Review this file before starting any task, and load any relevant skills from `.agents/skills/` (if present) or user/global agent skills before editing code.

---

## 1. Brand Identity & Domain Alignment

- **Product focus:** AXIS is a local-first cross-platform personal productivity cockpit and Islamic prayer, habit, note, and focus accountability application (Android Kotlin mobile + Linux and Windows desktop), backed by local PowerSync SQLite storage synchronized with Supabase Postgres/Auth/RPCs. Never introduce off-brand concepts, joke copy, or unrelated template terminology.
- **Design tokens (`mobile/lib/core/theme.dart` — `AxisColors` & `AxisTheme`):**
  - Canvas & Surfaces: `#051424` (`canvasBase`), `#010F1F` (`surfaceLowest`), `#0D1C2D` (`surfaceLow`), `#122131` (`surface`), `#1C2B3C` (`surfaceHigh`), `#273647` (`surfaceHighest`)
  - Primary & Semantic Accents: Indigo `#6366F1` (`primary`, soft `#C0C1FF`), Cyan `#0EA5E9` (`secondary`, soft `#7DD3FC`), Emerald `#4EDEA3` / `#10B981` (`tertiary` / `success`), Amber `#F59E0B` (`warning`), Crimson `#EF4444` (`danger` / `priorityHigh`)
  - Text (`dark` Obsidian): `#F8FAFC` (`textHigh`), `#94A3B8` (`textMuted`), `#8292A6` (`textDim`, WCAG AA)
  - Light Theme (`AxisTheme.light`): `#F1F5F9` canvas, `#FFFFFF` surface, `#0F172A` primary text, `#475569` secondary text
  - Typography (`mobile/lib/core/typography.dart` — `AxisFonts` backed natively by offline `.ttf` assets in `mobile/assets/fonts/`): `SpaceGrotesk` headings, `Geist` body & controls, `JetBrainsMono` / `SpaceMono` / `FiraCode` telemetry & tabular metrics. Never reintroduce runtime `google_fonts` HTTP fetching.
  - Shape & Borders: `12px` card radius, `1.5px` subtle/primary rims (`borderSubtle`, `borderPrimary`, `borderEmerald`).
- **No emojis or AI slop:** Never use emojis anywhere in UI copy, buttons, headings, chips, badges, empty states, or code comments. Avoid decorative clutter, ungrounded metrics, hardcoded placeholder IDs (`AX-7842`, `discovered_*`, dummy emails), or buzzword filler. Use Material `Icons.*` (`Rounded` / `Outlined`) with `matchTextDirection: true` where directional.
- **UI change checklist:** Every UI change must follow `AxisColors`, `AxisTheme`, and `AxisFonts` tokens, maintain clear visual hierarchy, respect >= 44dp interactive touch targets, and adapt cleanly from `375px` mobile screens to `1280px+` desktop panes.

---

## 2. User Experience (UX) First

- **UX beats decorative UI:** Prioritize clear user journeys, offline-first reliability, fast visual feedback, scannable layouts, obvious primary actions, and zero dead ends.
- **Skeleton loaders only:** When fetching or waiting on async data for screens or lists, render content-shaped placeholders matching the final layout. Never use centered blocking `CircularProgressIndicator` bubbles for page/list loading (a compact inline spinner inside a disabled action button during an active mutation is acceptable alongside status feedback).
- **Instant / optimistic UI with background sync feedback:**
  - Update local UI state immediately when the user triggers a mutation (completing tasks/habits/prayers, editing notes, toggling alarm settings, responding to companion shares).
  - Persist locally to PowerSync SQLite first and inform the user clearly of background sync / download state via non-blocking indicators (`AxisSnackBar`, sync modal badges, or update download progress bars).
  - If an asynchronous operation fails unrecoverably, roll back optimistic UI state cleanly and show a bilingual actionable error message.

---

## 3. Code Quality, Architecture & Bug-Fix Discipline

- **SOLID principles & design patterns everywhere:** Keep domain logic (`mobile/lib/domain/`, pure Dart with zero UI/DB imports) cleanly decoupled from PowerSync/Supabase repositories (`mobile/lib/data/`), BLoC/Notifier controllers (`mobile/lib/core/bloc/`), UI widgets (`mobile/lib/ui/`), and native Kotlin bridges (`mobile/android/app/src/main/kotlin/com/axis/axis/`). Prefer focused repositories, domain engines, immutable data models, and extracted sub-widgets over monolithic classes.
- **400-line hard file cap:** No new or refactored source code file (`.dart`, `.kt`, `.sql`) may exceed **400 lines of code** (tracked in `.github/workflows/ci.yml` PR checks). When a modified or new file approaches ~300–350 lines, split it proactively into focused domain helpers, repositories, services, or sub-widgets. Pre-existing legacy monoliths > 400 lines must be decomposed incrementally without introducing regressions.
- **Fix root causes, never symptoms:** Never mask defects with arbitrary `Future.delayed`/`Timer` sleeps, silent `catch (_) {}` blocks that discard recoverable/actionable failures, or fallback fake values. Diagnose and eliminate the underlying defect.
- **Document fixes inline:** Whenever fixing a bug, leave a concise `// Root cause: ...` comment directly above the fix explaining why the defect happened and how the change prevents regression.
- **Remove dead code immediately:** When a feature, helper, model, dependency, or asset is replaced or removed, delete unreferenced code, unused packages, and commented-out blocks in the same change.
- **No fake or mock data in production code:** Never ship hardcoded fallback friend codes, dummy accounts, synthetic `'discovered_'` entity prefixes, or mock responses in live `mobile/lib/` code. Test doubles belong strictly under `mobile/test/`.

---

## 4. Security, Vault & Release Integrity

- **Zero secrets in git:** Never commit `.env`, `key.properties`, `*.jks`, `*.keystore`, signing passwords, JWT secrets, or Supabase service-role keys. Only `.env.example` / `backend/powersync/.env.example` templates with placeholders may be tracked.
- **Least privilege & RLS everywhere:** Every Supabase Postgres table and Storage bucket must enable Row Level Security (`RLS`) with explicit ownership or verified companion-relationship policies. Pin `SET search_path = public, pg_temp` and assert `auth.uid()` inside every `SECURITY DEFINER` RPC/trigger, never expose service-role credentials to clients, and scope `backend/powersync/sync-rules.yaml` streams strictly by `auth.user_id()` or verified companion relationships.
- **Hardware-backed credential vault (`SecureCredentialVault`):** Never derive encryption keys from static compile-time secrets. Persist per-installation CSPRNG master keys and salts in Android Keystore (`AxisVaultKeystore.kt`, AES/GCM) or `0600` owner-only local key files, clear cached credentials immediately when `Remember Me` is disabled, and purge prior account SQLite/cache state on account switch or sign-out.
- **OTA update & Android alarm security:** Validate release and checksum URLs strictly over HTTPS on trusted release domains (`github.com`, `*.githubusercontent.com`, `*.supabase.co`), never fall back across OS installer architectures, verify `SHA256SUMS.txt` SHA-256 digests before launching native installers, keep `/debug/*` diagnostic screens gated behind `kDebugMode`, restrict Android lock-screen/screen-wake flags strictly to active Adhan alarm launches, check `canScheduleExactAlarms()` on Android 12+, restore exact alarms on boot (`AdhanBootReceiver` + `AdhanAlarmStore`), and comply with Android 14/15 `foregroundServiceType` declarations.

---

## 5. Workflow, Subagents & Critical Update Gate

- **Feature discovery questions first:** Before implementing a major new feature, clarify target platforms (Android/Linux/Windows), offline/PowerSync sync rules, Supabase schema/RLS impact, alarm/notification behavior, localization needs, and acceptance criteria.
- **Subagent specialization and coordinator review:** Split large multi-layer tasks into focused parallel streams (Supabase/PowerSync Schema, Domain & Repositories, Native Android Kotlin, Mobile & Desktop UI, QA & Testing). Review, integrate, analyze, and test every subagent's output before completion.
- **Critical update gate:** Any change touching database migrations, PowerSync `sync-rules.yaml` or `app_schema.dart`, Auth/Vault, OTA updater, or Android alarm receivers/services must develop cleanly on a dedicated branch, pass `flutter analyze` and `flutter test`, pass CI checks, and undergo manual verification before merging to `main` or tagging a `v*` release.

---

## 6. Testing, Manual QA & Deployment

- **Categorized test suites under `mobile/test/`:** Keep unit, service/integration, regression, widget, and localization tests well structured and independent:
  - Unit tests: pure domain engines (`recurrence_engine`, `auto_scheduler`, `calendar_scheduler`, `update_checker`), `SemanticVersion`, `DateKeyHelper`, formatters.
  - Service & integration tests: `app_schema` / `PayloadSanitizer` parity, `SecureCredentialVault`, repositories, `AppUpdateService`, `FocusSessionService`, `NotificationIds` / Adhan channel consistency.
  - Widget, RTL & regression tests: mobile & desktop UI flows, modal deduplication/version display, controller disposal, `en` LTR / `ar` RTL directionality, and light/dark theme readability.
- **Pre-release verification & manual QA:** After automated checks pass, verify Android cold-boot/reboot Adhan rescheduling and lock-screen alarm UI, offline login/session resilience + PowerSync reconnect sync, desktop multi-pane flows, and Arabic RTL layouts prior to shipping a release.
- **Automated CI & GitHub Release builds:** `.github/workflows/ci.yml` runs `flutter analyze`, `flutter test -r compact`, and modified-file 400-line checks on `push`/`pull_request` to `main`. Pushing a `v*` tag triggers `.github/workflows/release.yml` to build signed Android APK, Linux tarball, Windows ZIP, and `SHA256SUMS.txt` release artifacts automatically.

---

## 7. Additional Engineering Standards

- **Versioned database migrations only:** Never modify production tables directly in the Supabase dashboard. Author every table, column, index, trigger, RPC, and RLS policy in `backend/supabase/migrations/` and keep `mobile/lib/data/powersync/app_schema.dart`, `PayloadSanitizer`, and `backend/powersync/sync-rules.yaml` synchronized.
- **Bilingual & RTL parity (`en` LTR / `ar` RTL):** Keep all user-facing strings localized in `mobile/lib/core/l10n/app_localizations.dart` (no stray untranslated strings in splash/error/settings widgets). Persist language and text direction via `LocaleService`, use `matchTextDirection: true` on Material directional icons without double-flipping, and verify Arabic RTL alignment on every UI change.
- **Strict Local vs UTC date separation:** Always format user-facing calendar days, habit streaks, and daily prayer resets using explicit local `YYYY-MM-DD` date keys (`DateKeyHelper`), reserving ISO-8601 UTC (`toUtc().toIso8601String()`) strictly for replication/audit timestamps (`created_at`, `updated_at`, `deleted_at`, `completed_at`).
- **Accessibility & responsiveness:** Provide semantic labels or tooltips on icon-only controls, avoid hiding interactive subtrees inside `ExcludeSemantics`, maintain WCAG AA contrast ratios on both dark and light surfaces, and test from `375px` mobile widths to `1440px` desktop windows.
- **Axis release cadence & performance discipline:** Follow the `x.y.0` through `x.y.10` patch cadence before rolling `x.(y+1).0`; keep `mobile/pubspec.yaml` (`version` & `msix_version`), `UpdateLogModal`, and `.github/workflows/release.yml` synchronized cleanly on each release; paginate large queries and keep SQLite/sync writes batched.
