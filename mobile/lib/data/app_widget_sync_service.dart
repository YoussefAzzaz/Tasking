import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/hijri_date.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/data/location_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/habit_repository.dart';

/// Centralized service to keep Android Home Screen widgets synchronized
/// with local database changes in real time.
class AppWidgetSyncService {
  static final AppWidgetSyncService _instance = AppWidgetSyncService._();
  factory AppWidgetSyncService() => _instance;
  AppWidgetSyncService._();

  /// Only Android and iOS provide native home screen widget frameworks supported by home_widget
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const List<String> _arabicGregorianMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> _emptyTaskQuotes = [
    'Clean slate for today — stay focused',
    'Plan one meaningful win to build momentum',
    'Small consistent steps compound fast',
    'Clarity precedes execution — add your next priority',
    'Protect your focus and own the day',
  ];

  static const List<String> _habitZeroStreakQuotes = [
    'Start your first streak today • Tap to open',
    'One completed habit starts the chain • Tap to open',
    'Consistency creates mastery • Tap to open',
    'Show up once today to spark momentum • Tap to open',
  ];

  static const List<String> _habitActiveStreakQuotes = [
    'days strong — keep the chain unbroken',
    'day streak active • Momentum is compounding',
    'days in motion • Excellence is a daily rhythm',
    'day streak • Stay locked in today',
  ];

  StreamSubscription? _tasksSub;
  StreamSubscription? _habitsSub;
  StreamSubscription? _habitLogsSub;
  StreamSubscription? _habitStateSub;
  StreamSubscription? _prayersSub;
  StreamSubscription? _prayerSettingsSub;
  Timer? _tasksDebounceTimer;
  Timer? _habitsDebounceTimer;
  Timer? _prayersDebounceTimer;

  /// Formats Gregorian date in Arabic, e.g. `24 نوفمبر`.
  static String formatArabicGregorianDate(DateTime date) {
    final monthName = _arabicGregorianMonths[(date.month - 1).clamp(0, 11)];
    return '${date.day} $monthName';
  }

  /// Parses `HH:mm` or `h:mm a` strings into minutes from midnight (`0..1439`), or null.
  static int? parseTimeToMinutes(String? rawTime) {
    if (rawTime == null) return null;
    final clean = rawTime.trim();
    if (clean.isEmpty) return null;
    try {
      if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
        final dt = DateFormat('h:mm a').parse(clean);
        return dt.hour * 60 + dt.minute;
      }
      final parts = clean.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0].trim());
        final minute = int.tryParse(parts[1].trim().replaceAll(RegExp(r'[^0-9]'), ''));
        if (hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          return hour * 60 + minute;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Formats a valid time string into `HH:mm`, returning empty string if invalid.
  static String formatTime24OrEmpty(String? rawTime) {
    final mins = parseTimeToMinutes(rawTime);
    if (mins == null) return '';
    final h = (mins ~/ 60).toString().padLeft(2, '0');
    final m = (mins % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Filters out toggled-off, paused, deleted, non-daily, or prayer habit rows.
  static List<Map<String, dynamic>> filterActiveDailyHabitRows(
    List<Map<String, dynamic>> rows, {
    Set<String> pausedOrDisabledIds = const {},
  }) {
    return rows.where((row) {
      final id = (row['id'] as String? ?? '').trim();
      if (id.isEmpty) return false;
      final deletedAt = (row['deleted_at'] as String? ?? '').trim();
      if (deletedAt.isNotEmpty) return false;

      final rawEnabled = row['is_enabled'];
      final dbEnabled = rawEnabled == null ||
          rawEnabled == 1 ||
          rawEnabled == true ||
          rawEnabled == '1' ||
          rawEnabled == 'true';
      if (!dbEnabled) return false;
      if (pausedOrDisabledIds.contains(id) || HabitStateManager.isHabitPaused(id)) {
        return false;
      }

      final sched = ((row['schedule_type'] as String?) ?? 'daily').trim().toLowerCase();
      if (sched != 'daily') return false;
      final kind = ((row['kind'] as String?) ?? '').trim().toLowerCase();
      if (kind == 'prayers' || id.startsWith('habit_prayer_')) return false;
      return true;
    }).toList();
  }

  /// Builds structured display items for Today Tasks widget, including priority and overdue flags.
  static List<Map<String, dynamic>> buildTodayTaskItems({
    required List<Map<String, dynamic>> todayRows,
    List<Map<String, dynamic>> pastOverdueRows = const [],
    required DateTime now,
    int limit = 5,
  }) {
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final nowMinutes = now.hour * 60 + now.minute;

    bool isOverdueRow(Map<String, dynamic> row) {
      final status = (row['status'] as String? ?? 'todo').trim().toLowerCase();
      if (status == 'done' || status == 'completed') return false;
      final dueDate = (row['due_date'] as String? ?? '').trim();
      if (dueDate.isNotEmpty) {
        final dateOnly = dueDate.length >= 10 ? dueDate.substring(0, 10) : dueDate;
        if (dateOnly.compareTo(todayStr) < 0) return true;
        if (dateOnly == todayStr) {
          final dueMin = parseTimeToMinutes(row['due_time'] as String?);
          if (dueMin != null && dueMin < nowMinutes) return true;
        }
      }
      return false;
    }

    Map<String, dynamic> toItem(Map<String, dynamic> row) {
      final status = (row['status'] as String? ?? 'todo').trim().toLowerCase();
      final isDone = status == 'done' || status == 'completed';
      final priority = (row['priority'] as num?)?.toInt() ?? 0;
      final overdue = isOverdueRow(row);
      final dueDate = (row['due_date'] as String? ?? '').trim();
      final dateOnly = dueDate.length >= 10 ? dueDate.substring(0, 10) : dueDate;
      final isPastDay = overdue && dateOnly.isNotEmpty && dateOnly.compareTo(todayStr) < 0;
      final timeLabel = formatTime24OrEmpty(row['due_time'] as String?);

      String badgeText = timeLabel;
      if (overdue) {
        if (isPastDay) {
          badgeText = timeLabel.isNotEmpty ? '⚠ $timeLabel' : '⚠ OVERDUE';
        } else {
          badgeText = timeLabel.isNotEmpty ? '⚠ $timeLabel' : '⚠ DUE';
        }
      }

      return <String, dynamic>{
        'title': (row['title'] as String? ?? '').replaceAll('\n', ' ').trim(),
        'done': isDone,
        'priority': priority,
        'time': badgeText,
        'overdue': overdue,
      };
    }

    final pastItems = pastOverdueRows.take(2).map(toItem).toList();
    final todayPending = todayRows
        .where((r) {
          final s = (r['status'] as String? ?? 'todo').trim().toLowerCase();
          return s != 'done' && s != 'completed';
        })
        .map(toItem)
        .toList()
      ..sort((a, b) {
        final aOver = (a['overdue'] as bool) ? 0 : 1;
        final bOver = (b['overdue'] as bool) ? 0 : 1;
        if (aOver != bOver) return aOver.compareTo(bOver);
        final aPri = (a['priority'] as int) > 0 ? (a['priority'] as int) : 99;
        final bPri = (b['priority'] as int) > 0 ? (b['priority'] as int) : 99;
        return aPri.compareTo(bPri);
      });
    final todayDone = todayRows
        .where((r) {
          final s = (r['status'] as String? ?? 'todo').trim().toLowerCase();
          return s == 'done' || s == 'completed';
        })
        .map(toItem)
        .toList();

    return <Map<String, dynamic>>[
      ...pastItems,
      ...todayPending,
      ...todayDone,
    ].take(limit).toList();
  }

  /// Selects a deterministic rotating motivational quote for the habit widget.
  static String selectHabitQuote({
    required int totalHabits,
    required int doneCount,
    required int streak,
    required DateTime now,
  }) {
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    if (totalHabits == 0) {
      return _habitZeroStreakQuotes[dayOfYear % _habitZeroStreakQuotes.length];
    }
    if (streak > 0 && doneCount == totalHabits) {
      return '🔥 $streak-day streak locked in • Great work';
    }
    if (streak > 0) {
      final suffix = _habitActiveStreakQuotes[dayOfYear % _habitActiveStreakQuotes.length];
      return '$streak $suffix';
    }
    return _habitZeroStreakQuotes[dayOfYear % _habitZeroStreakQuotes.length];
  }

  /// Starts listening to real-time database changes and keeps widgets synchronized
  void startAutoSync() {
    if (!isSupportedPlatform || !isDatabaseInitialized) return;
    stopAutoSync();

    try {
      _tasksSub = db
          .watch('SELECT * FROM tasks')
          .listen((_) => _debouncedSyncTasks());
      _habitsSub = db
          .watch('SELECT * FROM habits')
          .listen((_) => _debouncedSyncHabits());
      _habitLogsSub = db
          .watch('SELECT * FROM habit_logs')
          .listen((_) => _debouncedSyncHabits());
      _prayersSub = db
          .watch('SELECT * FROM prayers')
          .listen((_) {
        _debouncedSyncHabits();
        _debouncedSyncPrayers();
      });

      try {
        _habitStateSub = db
            .watch('SELECT * FROM local_habit_state')
            .listen((_) => _debouncedSyncHabits());
      } catch (_) {}

      try {
        _prayerSettingsSub = db
            .watch('SELECT * FROM prayer_settings')
            .listen((_) => _debouncedSyncPrayers());
      } catch (_) {}
    } catch (e) {
      debugPrint('Error starting AppWidget auto-sync listeners: $e');
    }
  }

  void stopAutoSync() {
    _tasksSub?.cancel();
    _habitsSub?.cancel();
    _habitLogsSub?.cancel();
    _habitStateSub?.cancel();
    _prayersSub?.cancel();
    _prayerSettingsSub?.cancel();
    _tasksDebounceTimer?.cancel();
    _habitsDebounceTimer?.cancel();
    _prayersDebounceTimer?.cancel();
  }

  void _debouncedSyncTasks() {
    _tasksDebounceTimer?.cancel();
    _tasksDebounceTimer =
        Timer(const Duration(milliseconds: 250), () => syncTodayTasks());
  }

  void _debouncedSyncHabits() {
    _habitsDebounceTimer?.cancel();
    _habitsDebounceTimer =
        Timer(const Duration(milliseconds: 250), () => syncHabitStreak());
  }

  void _debouncedSyncPrayers() {
    _prayersDebounceTimer?.cancel();
    _prayersDebounceTimer =
        Timer(const Duration(milliseconds: 250), () => syncPrayerTimes());
  }

  Future<void> syncAll() async {
    if (!isSupportedPlatform || !isDatabaseInitialized) return;
    await Future.wait([
      syncTodayTasks(),
      syncHabitStreak(),
      syncPrayerTimes(),
    ]);
  }

  Future<String> _resolveCityName() async {
    String cityName = '';
    try {
      final loc = await LocationService().getLocation();
      if (loc.city.isNotEmpty &&
          loc.city != 'Local' &&
          loc.city != 'Auto' &&
          loc.city != 'GPS Location') {
        cityName = loc.city;
      }
    } catch (_) {}

    if (cityName.isEmpty) {
      final prayerCity = PrayerTimeService().currentCity;
      if (prayerCity.isNotEmpty &&
          prayerCity != 'Local' &&
          prayerCity != 'Auto' &&
          prayerCity != 'GPS Location') {
        cityName = prayerCity;
      }
    }

    return cityName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  }

  Future<void> syncTodayTasks() async {
    if (!isSupportedPlatform || !isDatabaseInitialized) return;
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final hijri = HijriDate.fromGregorian(now);
      final gregorianLabel = DateFormat('EEE, MMM d').format(now).toUpperCase();
      final hijriLabel = hijri.formatEnglish(includeYear: false).toUpperCase();
      final dateWithHijri = '$gregorianLabel • $hijriLabel';

      final uid = currentUserId;
      final todayPattern = '$todayStr%';
      final taskQuery = uid.isNotEmpty
          ? "SELECT id, title, status, due_date, due_time, priority FROM tasks WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND (deleted_at IS NULL OR deleted_at = '') AND (due_date = ? OR due_date LIKE ?) ORDER BY CASE WHEN status = 'done' THEN 1 ELSE 0 END, CASE WHEN priority IS NULL THEN 4 ELSE priority END ASC, created_at DESC"
          : "SELECT id, title, status, due_date, due_time, priority FROM tasks WHERE (deleted_at IS NULL OR deleted_at = '') AND (due_date = ? OR due_date LIKE ?) ORDER BY CASE WHEN status = 'done' THEN 1 ELSE 0 END, CASE WHEN priority IS NULL THEN 4 ELSE priority END ASC, created_at DESC";
      final taskParams =
          uid.isNotEmpty ? [uid, todayStr, todayPattern] : [todayStr, todayPattern];
      final todayTasks = await db.getAll(taskQuery, taskParams);

      final pastOverdueQuery = uid.isNotEmpty
          ? "SELECT id, title, status, due_date, due_time, priority FROM tasks WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND (deleted_at IS NULL OR deleted_at = '') AND status != 'done' AND due_date IS NOT NULL AND due_date != '' AND substr(due_date, 1, 10) < ? ORDER BY due_date ASC, CASE WHEN priority IS NULL THEN 4 ELSE priority END ASC LIMIT 2"
          : "SELECT id, title, status, due_date, due_time, priority FROM tasks WHERE (deleted_at IS NULL OR deleted_at = '') AND status != 'done' AND due_date IS NOT NULL AND due_date != '' AND substr(due_date, 1, 10) < ? ORDER BY due_date ASC, CASE WHEN priority IS NULL THEN 4 ELSE priority END ASC LIMIT 2";
      final pastOverdueParams = uid.isNotEmpty ? [uid, todayStr] : [todayStr];
      final pastOverdueTasks = await db.getAll(pastOverdueQuery, pastOverdueParams);

      final displayItems = buildTodayTaskItems(
        todayRows: todayTasks,
        pastOverdueRows: pastOverdueTasks,
        now: now,
      );

      final total = todayTasks.length;
      final done = todayTasks.where((r) => r['status'] == 'done').length;
      final percent = total > 0 ? ((done / total) * 100).round().clamp(0, 100) : 0;
      final remaining = total - done;
      final overdueCount = displayItems.where((e) => e['overdue'] == true).length;

      final lines = displayItems.map((item) {
        final symbol = (item['done'] as bool) ? '✓' : '○';
        return '$symbol ${item['title']}';
      }).toList();

      final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
      final emptyQuote = _emptyTaskQuotes[dayOfYear % _emptyTaskQuotes.length];
      final content = lines.isEmpty ? emptyQuote : lines.join('\n');

      String nextUpcomingTime = '';
      for (final item in displayItems) {
        if (item['done'] == false &&
            item['overdue'] == false &&
            (item['time'] as String).isNotEmpty) {
          nextUpcomingTime = item['time'] as String;
          break;
        }
      }

      final String footerSummary;
      if (overdueCount > 0) {
        footerSummary = '⚠ $overdueCount overdue • ${remaining > 0 ? '$remaining left' : 'check list'}';
      } else if (total > 0 && remaining == 0) {
        footerSummary = 'All $total tasks done ✓';
      } else if (nextUpcomingTime.isNotEmpty) {
        footerSummary = 'Next: $nextUpcomingTime • $remaining left';
      } else if (remaining > 0) {
        footerSummary = '$remaining ${remaining == 1 ? 'task' : 'tasks'} remaining';
      } else {
        footerSummary = 'All clear for today';
      }

      final cleanCity = await _resolveCityName();

      await HomeWidget.saveWidgetData<String>(
          'today_tasks_title', 'AXIS • TODAY');
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_date', dateWithHijri);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_date_gregorian', gregorianLabel);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_date_hijri', hijriLabel);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_sync_date', todayStr);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_city', cleanCity.toUpperCase());
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_count', '$done/$total DONE');
      await HomeWidget.saveWidgetData<int>('today_tasks_percent', percent);
      await HomeWidget.saveWidgetData<int>(
          'today_tasks_overdue_count', overdueCount);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_footer_summary', footerSummary);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_empty_quote', emptyQuote);
      await HomeWidget.saveWidgetData<String>('today_tasks_content', content);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_items_json', jsonEncode(displayItems));

      await HomeWidget.updateWidget(
        name: 'TodayTasksWidgetProvider',
        androidName: 'TodayTasksWidgetProvider',
        qualifiedAndroidName: 'com.axis.axis.TodayTasksWidgetProvider',
      );
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('Error syncing today tasks widget: $e');
      }
    }
  }

  Future<void> syncHabitStreak() async {
    if (!isSupportedPlatform || !isDatabaseInitialized) return;
    try {
      await HabitRepository.ensureStateLoaded();

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final hijri = HijriDate.fromGregorian(now);
      final hijriShort = hijri.formatEnglish(includeYear: false).toUpperCase();
      final uid = currentUserId;

      final habitQuery = uid.isNotEmpty
          ? "SELECT id, name, icon, color, kind, schedule_type, is_enabled, deleted_at FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND (deleted_at IS NULL OR deleted_at = '') AND COALESCE(is_enabled, 1) != 0 AND LOWER(COALESCE(schedule_type, 'daily')) = 'daily' AND LOWER(COALESCE(kind, '')) != 'prayers' AND id NOT LIKE 'habit_prayer_%' ORDER BY COALESCE(sort_order, 999) ASC, created_at ASC"
          : "SELECT id, name, icon, color, kind, schedule_type, is_enabled, deleted_at FROM habits WHERE (deleted_at IS NULL OR deleted_at = '') AND COALESCE(is_enabled, 1) != 0 AND LOWER(COALESCE(schedule_type, 'daily')) = 'daily' AND LOWER(COALESCE(kind, '')) != 'prayers' AND id NOT LIKE 'habit_prayer_%' ORDER BY COALESCE(sort_order, 999) ASC, created_at ASC";
      final habitParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      final rawHabitRows = await db.getAll(habitQuery, habitParams);

      final disabledIds = <String>{};
      try {
        final stateRows = await db.getAll(
          'SELECT habit_id, is_enabled FROM local_habit_state WHERE is_enabled = 0',
        );
        for (final r in stateRows) {
          final hId = (r['habit_id'] as String? ?? '').trim();
          if (hId.isNotEmpty) disabledIds.add(hId);
        }
      } catch (_) {}

      final habitRows = filterActiveDailyHabitRows(
        rawHabitRows,
        pausedOrDisabledIds: disabledIds,
      );

      final habitLogQuery = uid.isNotEmpty
          ? "SELECT habit_id FROM habit_logs WHERE log_date = ? AND status = 'done' AND (user_id = ? OR user_id IS NULL OR user_id = '')"
          : "SELECT habit_id FROM habit_logs WHERE log_date = ? AND status = 'done'";
      final habitLogParams = uid.isNotEmpty ? [todayStr, uid] : [todayStr];
      final habitLogRows = await db.getAll(habitLogQuery, habitLogParams);

      final streakLogs = await HabitRepository().getDailyStreakLogs();
      final streak =
          StreakEngine.calculateStreak('daily', streakLogs, todayStr);

      final todayDoneHabitIds = habitLogRows
          .map((r) => r['habit_id'] as String)
          .toSet();

      final totalHabits = habitRows.length;
      final todayDoneCount = habitRows
          .where((h) => todayDoneHabitIds.contains(h['id'] as String))
          .length;
      final percent = totalHabits > 0
          ? ((todayDoneCount / totalHabits) * 100).round().clamp(0, 100)
          : 0;

      final items = <Map<String, dynamic>>[];
      final lines = <String>[];
      for (final h in habitRows.take(5)) {
        final isDone = todayDoneHabitIds.contains(h['id'] as String);
        final symbol = isDone ? '✓' : '○';
        final name = (h['name'] as String? ?? '').replaceAll('\n', ' ').trim();
        final color = (h['color'] as String? ?? '#10B981').trim();
        lines.add('$symbol $name');
        items.add({
          'name': name,
          'color': color.isNotEmpty ? color : '#10B981',
          'done': isDone,
        });
      }

      final content = lines.isEmpty
          ? 'Start your first streak today'
          : lines.join('\n');
      final quote = selectHabitQuote(
        totalHabits: totalHabits,
        doneCount: todayDoneCount,
        streak: streak,
        now: now,
      );

      await HomeWidget.saveWidgetData<String>(
        'habit_streak_days',
        '$streak ${streak == 1 ? 'DAY' : 'DAYS'}',
      );
      await HomeWidget.saveWidgetData<int>('habit_streak_num', streak);
      await HomeWidget.saveWidgetData<String>(
        'habit_streak_badge',
        '$todayDoneCount/$totalHabits DONE',
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_streak_progress',
        totalHabits > 0
            ? '$todayDoneCount of $totalHabits habits completed today ($percent%)'
            : 'No active daily habits',
      );
      await HomeWidget.saveWidgetData<String>('habit_streak_hijri', hijriShort);
      await HomeWidget.saveWidgetData<String>('habit_streak_sync_date', todayStr);
      await HomeWidget.saveWidgetData<String>('habit_streak_content', content);
      await HomeWidget.saveWidgetData<String>(
          'habit_streak_items_json', jsonEncode(items));
      await HomeWidget.saveWidgetData<String>('habit_streak_quote', quote);
      await HomeWidget.saveWidgetData<int>('habit_streak_percent', percent);

      await HomeWidget.updateWidget(
        name: 'HabitStreakWidgetProvider',
        androidName: 'HabitStreakWidgetProvider',
        qualifiedAndroidName: 'com.axis.axis.HabitStreakWidgetProvider',
      );
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('Error syncing habit streak widget: $e');
      }
    }
  }

  /// Synchronizes today's 5 Islamic prayer times, astronomical Sunrise,
  /// Arabic Gregorian date, and Arabic Hijri date to the horizontal Prayer widget.
  Future<void> syncPrayerTimes() async {
    if (!isSupportedPlatform || !isDatabaseInitialized) return;
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final uid = currentUserId;
      final prayerService = PrayerTimeService();
      const calculator = PrayerCalculator();

      final todayItems = await prayerService.calculatePrayersForDate(now);
      final tomorrowItems = await prayerService.calculatePrayersForDate(
        now.add(const Duration(days: 1)),
      );
      final sunriseDt = await prayerService.calculateSunriseForDate(now);
      final sunrise24 = DateFormat('HH:mm').format(sunriseDt);

      final Map<String, bool> doneMap = {
        'fajr': false,
        'dhuhr': false,
        'asr': false,
        'maghrib': false,
        'isha': false,
      };

      try {
        final prayerQuery = uid.isNotEmpty
            ? "SELECT id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at FROM prayers WHERE (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest') ORDER BY sort_order ASC"
            : 'SELECT id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at FROM prayers ORDER BY sort_order ASC';
        final prayerParams = uid.isNotEmpty ? [uid] : <dynamic>[];
        final rows = await db.getAll(prayerQuery, prayerParams);
        for (final row in rows) {
          final parsed = Prayer.fromRow(row);
          final code = parsed.prayerCode.trim().toLowerCase();
          if (doneMap.containsKey(code)) {
            doneMap[code] = parsed.isDone;
          }
        }
      } catch (_) {}

      final timeByCode = <String, String>{};
      for (final item in todayItems) {
        timeByCode[item.id] = DateFormat('HH:mm').format(item.time);
      }
      final tomorrowFajrTime = tomorrowItems.isNotEmpty
          ? DateFormat('HH:mm').format(tomorrowItems.first.time)
          : (timeByCode['fajr'] ?? '05:30');

      final hijri = HijriDate.fromGregorian(now);
      final hijriAr = hijri.formatArabic(includeYear: true, includeSuffix: false);
      final gregorianAr = formatArabicGregorianDate(now);
      final cleanCity = await _resolveCityName();

      await HomeWidget.saveWidgetData<String>(
          'prayer_widget_date_key', todayStr);
      await HomeWidget.saveWidgetData<String>(
          'prayer_widget_gregorian', gregorianAr);
      await HomeWidget.saveWidgetData<String>('prayer_widget_hijri', hijriAr);
      await HomeWidget.saveWidgetData<String>(
          'prayer_widget_sunrise', sunrise24);
      await HomeWidget.saveWidgetData<String>(
          'prayer_widget_city', cleanCity);

      for (final code in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        await HomeWidget.saveWidgetData<String>(
          'prayer_widget_${code}_time',
          timeByCode[code] ?? calculator.formatPrayerTime24(
            PrayerRepository.defaultPrayers()
                .firstWhere((p) => p.prayerCode == code)
                .time,
          ),
        );
        await HomeWidget.saveWidgetData<bool>(
          'prayer_widget_${code}_done',
          doneMap[code] ?? false,
        );
      }
      await HomeWidget.saveWidgetData<String>(
          'prayer_widget_fajr_tomorrow_time', tomorrowFajrTime);

      await HomeWidget.updateWidget(
        name: 'PrayerTimesWidgetProvider',
        androidName: 'PrayerTimesWidgetProvider',
        qualifiedAndroidName: 'com.axis.axis.PrayerTimesWidgetProvider',
      );
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('Error syncing prayer times widget: $e');
      }
    }
  }
}
