/// Utility for sanitizing PowerSync client payloads before sending to Supabase Postgres.
class PayloadSanitizer {
  const PayloadSanitizer();

  /// Sanitize client payload before sending to Supabase Postgres:
  /// 1. Map 0/1 integers to Dart booleans for Postgres boolean columns
  /// 2. Convert empty strings ("") to null for date/time/timestamptz/uuid fields
  /// 3. Replace 'local_guest' or empty user_id with active authenticated UID
  static Map<String, dynamic> sanitize(
    String table,
    Map<String, dynamic> raw,
    String uid,
  ) {
    final data = Map<String, dynamic>.from(raw);

    // 1. Ensure user_id is the active valid UUID (for user-scoped tables)
    if (table != 'friendships' && table != 'companion_shares' && uid.isNotEmpty) {
      final existingUid = data['user_id'];
      if (existingUid == null ||
          existingUid == '' ||
          existingUid == 'local_guest') {
        data['user_id'] = uid;
      }
    }
    if (table == 'friendships' || table == 'companion_shares') {
      data.remove('user_id');
    }

    // 2. Boolean fields conversion
    const boolFields = {
      'pinned',
      'is_done',
      'completed',
      'is_enabled',
      'animations_enabled',
      'sounds_enabled',
      'adhan_notifications_enabled',
      'fajr_alarm_enabled',
      'fajr',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    };
    for (final field in boolFields) {
      if (data.containsKey(field) && data[field] != null) {
        final val = data[field];
        if (val is int) {
          data[field] = (val == 1);
        } else if (val is String) {
          data[field] = (val == '1' || val.toLowerCase() == 'true');
        }
      }
    }

    // 3. Clean empty strings in timestamp/date/time columns
    const nullableDateTimeFields = {
      'due_date',
      'due_time',
      'completed_at',
      'completed_date',
      'deleted_at',
      'started_at',
      'ended_at',
      'remind_at',
      'remind_time',
      'archived_at',
      'archived_date',
      'planned_at',
      'reviewed_at',
      'start_at',
      'end_at',
      'last_sync_date',
    };
    for (final field in nullableDateTimeFields) {
      if (data.containsKey(field) &&
          data[field] is String &&
          (data[field] as String).trim().isEmpty) {
        data[field] = null;
      }
    }

    // 4. Foreign key / UUID fields: convert empty strings to null
    const nullableFkFields = {
      'project_id',
      'task_id',
      'habit_id',
      'parent_task_id',
      'top1_task_id',
      'top2_task_id',
      'top3_task_id',
      'series_id',
    };
    for (final field in nullableFkFields) {
      if (data.containsKey(field) &&
          data[field] is String &&
          (data[field] as String).trim().isEmpty) {
        data[field] = null;
      }
    }

    // 5. Table-specific schema constraint compliance
    if (table == 'habits') {
      data.remove('start_date');
    } else if (table == 'tasks') {
      // Only validate/normalize status when the PATCH/PUT payload explicitly includes it,
      // otherwise partial edits (like renaming or toggling priority) overwrite status with 'todo'.
      if (data.containsKey('status')) {
        if (data['status'] == 'skipped') {
          data['status'] = 'done';
        } else if (data['status'] != 'todo' && data['status'] != 'done' && data['status'] != 'cancelled') {
          data['status'] = 'todo';
        }
      }
      if (data['priority'] is int) {
        data['priority'] = (data['priority'] as int).clamp(0, 3);
      }
      if (data.containsKey('recurrence_mode') && data['recurrence_mode'] != null) {
        final mode = data['recurrence_mode'];
        if (mode != 'fixed' && mode != 'after_completion') {
          data['recurrence_mode'] = 'fixed';
        }
      }
    } else if (table == 'daily_prayer_status') {
      if (!data.containsKey('date') ||
          data['date'] == null ||
          (data['date'] is String && (data['date'] as String).trim().isEmpty)) {
        final created = data['created_at'] as String?;
        data['date'] = (created != null && created.length >= 10)
            ? created.substring(0, 10)
            : DateTime.now().toUtc().toIso8601String().substring(0, 10);
      }
      for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        if (data.containsKey(p) && data[p] != null) {
          data[p] = data[p] == true || data[p] == 1 || data[p] == '1';
        }
      }
      if (data.containsKey('streak_days') && data['streak_days'] is num) {
        data['streak_days'] = (data['streak_days'] as num).toInt();
      }
      if (data.containsKey('habits_done') && data['habits_done'] is num) {
        data['habits_done'] = (data['habits_done'] as num).toInt();
      }
      if (data.containsKey('habits_total') && data['habits_total'] is num) {
        data['habits_total'] = (data['habits_total'] as num).toInt();
      }
    }

    return data;
  }
}

