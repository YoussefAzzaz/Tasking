import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/core/config/app_config.dart';

/// PowerSync backend connector bridging local SQLite CRUD mutations to Supabase REST / Postgres
class SupabaseConnector extends PowerSyncBackendConnector {
  final String Function()? getCurrentUserId;

  SupabaseConnector({this.getCurrentUserId}) : super();

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final client = Supabase.instance.client;
    var session = client.auth.currentSession;
    if (session == null || session.isExpired) {
      try {
        final res = await client.auth.refreshSession();
        session = res.session;
      } catch (e) {
        debugPrint('[PowerSync SupabaseConnector] fetchCredentials session refresh error: $e');
      }
    }
    if (session == null) {
      return null;
    }
    final token = session.accessToken;

    return PowerSyncCredentials(
      endpoint: AppConfig.powerSyncUrl,
      token: token,
      userId: session.user.id,
    );
  }

  /// Sanitize client payload before sending to Supabase Postgres:
  /// 1. Map 0/1 integers to Dart booleans for Postgres boolean columns
  /// 2. Convert empty strings ("") to null for date/time/timestamptz/uuid fields
  /// 3. Replace 'local_guest' or empty user_id with active authenticated UID
  Map<String, dynamic> _sanitizePayload(
    String table,
    Map<String, dynamic> raw,
    String uid,
  ) {
    final data = Map<String, dynamic>.from(raw);

    // 1. Ensure user_id is the active valid UUID
    if (uid.isNotEmpty) {
      final existingUid = data['user_id'];
      if (existingUid == null ||
          existingUid == '' ||
          existingUid == 'local_guest') {
        data['user_id'] = uid;
      }
    }

    // 2. Boolean fields conversion (Postgres strictly expects boolean, SQLite stores 0/1)
    const boolFields = {
      'pinned',
      'is_done',
      'completed',
      'animations_enabled',
      'sounds_enabled',
      'adhan_notifications_enabled',
      'fajr_alarm_enabled',
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

    // 3. Clean empty strings in timestamp/date/time columns (convert "" to null)
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
      // Supabase habits table: start_date is NOT NULL
      if (!data.containsKey('start_date') ||
          data['start_date'] == null ||
          (data['start_date'] is String && (data['start_date'] as String).isEmpty)) {
        final created = data['created_at'] as String?;
        data['start_date'] = (created != null && created.length >= 10)
            ? created.substring(0, 10)
            : DateTime.now().toUtc().toIso8601String().substring(0, 10);
      }
      // Supabase habits table: CHECK (kind IN ('boolean','numeric'))
      final kind = data['kind'];
      if (kind != 'boolean' && kind != 'numeric') {
        final target = data['target_value'];
        data['kind'] = (target != null && target is num && target > 1) ? 'numeric' : 'boolean';
      }
      // Supabase habits table: CHECK (schedule_type IN ('daily','weekdays','times_per_week','every_n_days'))
      const validSchedules = {'daily', 'weekdays', 'times_per_week', 'every_n_days'};
      if (!validSchedules.contains(data['schedule_type'])) {
        data['schedule_type'] = 'daily';
      }
    } else if (table == 'tasks') {
      // Supabase tasks table: CHECK (status IN ('todo','done','cancelled'))
      if (data['status'] == 'skipped') {
        data['status'] = 'done';
      } else if (data['status'] != 'todo' && data['status'] != 'done' && data['status'] != 'cancelled') {
        data['status'] = 'todo';
      }
      // Supabase tasks table: CHECK (priority BETWEEN 0 AND 3)
      if (data['priority'] is int) {
        data['priority'] = (data['priority'] as int).clamp(0, 3);
      }
      // Supabase tasks table: CHECK (recurrence_mode IN ('fixed','after_completion'))
      if (data.containsKey('recurrence_mode') && data['recurrence_mode'] != null) {
        final mode = data['recurrence_mode'];
        if (mode != 'fixed' && mode != 'after_completion') {
          data['recurrence_mode'] = 'fixed';
        }
      }
    }

    return data;
  }

  /// Executes an upsert or update with self-healing retry logic:
  /// - Strips columns that do not exist on Supabase (error 42703)
  /// - Fixes boolean type mismatches (error 42804)
  /// - Recovers from foreign key violations (error 23503)
  Future<void> _upsertWithRetry({
    required String tableName,
    required Map<String, dynamic> initialData,
    required bool isPatch,
    required String recordId,
  }) async {
    final table = Supabase.instance.client.from(tableName);
    final data = Map<String, dynamic>.from(initialData);

    const int maxRetries = 6;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        if (isPatch) {
          final updated = await table.update(data).eq('id', recordId).select('id');
          if (updated.isEmpty) {
            // Row didn't exist remotely; fall back to upsert to ensure insertion
            data['id'] = recordId;
            await table.upsert(data);
          }
        } else {
          data['id'] = recordId;
          await table.upsert(data);
        }
        return; // Success!
      } on PostgrestException catch (e) {
        final code = e.code ?? '';
        final msg = e.message;
        debugPrint('[PowerSync SupabaseConnector] Attempt $attempt failed on $tableName: [$code] $msg');

        // Case 1: Column does not exist on Supabase (Error 42703)
        if (code == '42703' ||
            msg.contains('column') && msg.contains('does not exist') ||
            msg.contains('Could not find the') && msg.contains('column')) {
          final missingColMatch = RegExp(r'''column "([^"]+)" of relation''', caseSensitive: false).firstMatch(msg) ??
              RegExp(r'''Could not find the '([^']+)' column''', caseSensitive: false).firstMatch(msg) ??
              RegExp(r'''column "([^"]+)" does not exist''', caseSensitive: false).firstMatch(msg);
          if (missingColMatch != null) {
            final colName = missingColMatch.group(1);
            if (colName != null && data.containsKey(colName)) {
              debugPrint('[PowerSync SupabaseConnector] Self-healing: removing missing column "$colName" from payload and retrying...');
              data.remove(colName);
              continue;
            }
          }
          // Fallback: check known columns that might be missing on older schemas
          final knownOptionalCols = ['tags', 'category', 'mood', 'energy', 'avatar_url'];
          bool removedAny = false;
          for (final col in knownOptionalCols) {
            if (data.containsKey(col) && msg.contains(col)) {
              data.remove(col);
              removedAny = true;
              break;
            }
          }
          if (removedAny) continue;
        }

        // Case 2: Boolean type mismatch (Error 42804)
        if (code == '42804' || msg.contains('is of type boolean but expression is of type integer')) {
          final boolColMatch = RegExp(r'''column "([^"]+)" is of type boolean''', caseSensitive: false).firstMatch(msg);
          if (boolColMatch != null) {
            final colName = boolColMatch.group(1);
            if (colName != null && data.containsKey(colName)) {
              final val = data[colName];
              data[colName] = (val == 1 || val == '1' || val == true);
              debugPrint('[PowerSync SupabaseConnector] Self-healing: converted "$colName" to boolean and retrying...');
              continue;
            }
          }
          // Convert all numeric 0/1 fields to bool as fallback
          for (final key in data.keys.toList()) {
            final val = data[key];
            if (val == 0 || val == 1) {
              data[key] = (val == 1);
            }
          }
          continue;
        }

        // Case 3: Foreign key violation (Error 23503), e.g., missing project_id or parent_task_id
        if (code == '23503' || msg.contains('violates foreign key constraint')) {
          if (data.containsKey('project_id') && data['project_id'] != null) {
            debugPrint('[PowerSync SupabaseConnector] Self-healing: removing invalid foreign key "project_id" and retrying...');
            data['project_id'] = null;
            continue;
          }
          if (data.containsKey('parent_task_id') && data['parent_task_id'] != null) {
            data['parent_task_id'] = null;
            continue;
          }
          if (data.containsKey('task_id') && data['task_id'] != null) {
            data['task_id'] = null;
            continue;
          }
        }

        // Rethrow any unhandled PostgrestException to outer handler
        rethrow;
      }
    }
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    final client = Supabase.instance.client;

    // 1. Ensure authenticated session
    var session = client.auth.currentSession;
    if (session == null || session.isExpired) {
      try {
        final res = await client.auth.refreshSession();
        session = res.session;
      } catch (e) {
        debugPrint('[PowerSync SupabaseConnector] Token refresh error before upload: $e');
      }
    }

    final user = client.auth.currentUser;
    final uid = user?.id ?? (getCurrentUserId != null ? getCurrentUserId!() : '');

    // If still not authenticated, defer upload without completing transaction
    if (session == null || user == null || uid.isEmpty) {
      debugPrint('[PowerSync SupabaseConnector] No authenticated user; deferring upload transaction.');
      return;
    }

    try {
      for (var op in transaction.crud) {
        final tableName = op.table;
        final rawData = op.opData != null ? Map<String, dynamic>.from(op.opData!) : <String, dynamic>{};
        final sanitizedData = _sanitizePayload(tableName, rawData, uid);

        if (op.op == UpdateType.put) {
          await _upsertWithRetry(
            tableName: tableName,
            initialData: sanitizedData,
            isPatch: false,
            recordId: op.id,
          );
        } else if (op.op == UpdateType.patch) {
          await _upsertWithRetry(
            tableName: tableName,
            initialData: sanitizedData,
            isPatch: true,
            recordId: op.id,
          );
        } else if (op.op == UpdateType.delete) {
          final table = client.from(tableName);
          if (uid.isNotEmpty) {
            await table.delete().eq('id', op.id).eq('user_id', uid);
          } else {
            await table.delete().eq('id', op.id);
          }
        }
      }
      // Successfully pushed all operations in this transaction to Supabase!
      await transaction.complete();
    } on AuthException catch (e) {
      debugPrint('[PowerSync SupabaseConnector] AuthException [${e.statusCode}]: ${e.message}');
      if (e.statusCode == '401' || e.statusCode == '403') {
        try {
          await client.auth.refreshSession();
        } catch (_) {}
      }
      // Do NOT complete transaction; let PowerSync retry
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint('[PowerSync SupabaseConnector] PostgrestException [${e.code}]: ${e.message}');
      final code = e.code ?? '';
      final msg = e.message.toLowerCase();

      final isAuthError = code == '401' ||
          code == '403' ||
          code == '42501' || // RLS policy violation
          code == 'PGRST301' ||
          msg.contains('jwt') ||
          msg.contains('token') ||
          msg.contains('unauthorized') ||
          msg.contains('forbidden') ||
          msg.contains('row-level security');

      if (isAuthError) {
        try {
          await client.auth.refreshSession();
        } catch (_) {}
        // Do NOT complete transaction! Keep queued until auth succeeds
        rethrow;
      }

      // Truly unrecoverable schema errors (e.g., table does not exist at all, or foreign key constraint violation)
      final isTrulyFatal = code == '42P01' || // undefined table
          code == '23503' || // foreign key violation
          code == '23505';   // unique violation that couldn't be upserted

      if (isTrulyFatal) {
        debugPrint('[PowerSync SupabaseConnector] CRITICAL: Discarding unrecoverable transaction [Code: $code]: ${e.message} (ops: ${transaction.crud.map((o) => "${o.table}:${o.id}").join(",")})');
        await transaction.complete();
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('[PowerSync SupabaseConnector] Unexpected upload error: $e');
      rethrow;
    }
  }
}
