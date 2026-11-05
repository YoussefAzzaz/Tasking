import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/core/config/app_config.dart';
import 'payload_sanitizer.dart';

/// PowerSync backend connector bridging local SQLite CRUD mutations to Supabase REST / Postgres
class SupabaseConnector extends PowerSyncBackendConnector {
  final PowerSyncDatabase? Function()? getDatabase;
  final String Function()? getCurrentUserId;

  SupabaseConnector({this.getDatabase, this.getCurrentUserId}) : super();

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final client = Supabase.instance.client;
    var session = client.auth.currentSession;
    if (session != null && session.isExpired && session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      try {
        final res = await client.auth.refreshSession();
        session = res.session;
      } catch (e) {
        debugPrint('[PowerSync SupabaseConnector] fetchCredentials session refresh error: $e');
      }
    }

    // 1. Guard against unauthenticated session on startup
    if (session == null || (session.isExpired && (session.refreshToken == null || session.refreshToken!.isEmpty))) {
      debugPrint('[PowerSync SupabaseConnector] fetchCredentials: No authenticated session. Pausing sync until auth is active.');
      return null;
    }

    // 2. Validate endpoint configuration
    final endpoint = AppConfig.powerSyncUrl.trim();
    if (endpoint.isEmpty || endpoint.contains('your-instance') || endpoint.contains('placeholder')) {
      debugPrint('[PowerSync SupabaseConnector] Invalid or unconfigured POWERSYNC_URL: "$endpoint". Pausing sync.');
      return null;
    }

    // 3. Validate access token
    final token = session.accessToken;
    if (token.isEmpty) {
      debugPrint('[PowerSync SupabaseConnector] Empty access token for user ${session.user.id}. Pausing sync.');
      return null;
    }

    debugPrint('[PowerSync SupabaseConnector] Supplying credentials for user: ${session.user.id} -> $endpoint');

    return PowerSyncCredentials(
      endpoint: endpoint,
      token: token,
      userId: session.user.id,
    );
  }

  Map<String, dynamic> _sanitizePayload(
    String table,
    Map<String, dynamic> raw,
    String uid,
  ) {
    return PayloadSanitizer.sanitize(table, raw, uid);
  }

  static final Set<String> _missingRemoteColumns = {};

  /// Executes an upsert or update with self-healing retry logic:
  /// - Strips columns that do not exist on Supabase (error 42703)
  /// - Fixes boolean type mismatches (error 42804)
  /// - Recovers from foreign key violations (error 23503)
  Future<void> _upsertWithRetry({
    required String tableName,
    required Map<String, dynamic> initialData,
    required bool isPatch,
    required String recordId,
    PowerSyncDatabase? database,
  }) async {
    final table = Supabase.instance.client.from(tableName);
    final data = Map<String, dynamic>.from(initialData);

    // Strip known missing remote columns upfront to avoid unnecessary retry delays
    for (final missingCol in _missingRemoteColumns) {
      if (missingCol.startsWith('$tableName.')) {
        final colName = missingCol.substring('$tableName.'.length);
        data.remove(colName);
      }
    }

    const int maxRetries = 6;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        if (tableName == 'friendships') {
          // For friendships, an existing record might have been created by the other participant.
          // Attempt an UPDATE first so the addressee can update status without triggering INSERT policy evaluations.
          final updated = await table.update(data).eq('id', recordId).select('id');
          if (updated.isEmpty) {
            data['id'] = recordId;
            await table.upsert(data);
          }
        } else if (isPatch) {
          if (tableName == 'daily_prayer_status' && database != null) {
            try {
              final local = await database.getOptional('SELECT * FROM daily_prayer_status WHERE id = ?', [recordId]);
              if (local != null) {
                for (final key in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'streak_days', 'habits_done', 'habits_total', 'user_id', 'date']) {
                  if (!data.containsKey(key) && local.containsKey(key) && local[key] != null) {
                    data[key] = local[key];
                  }
                }
              }
            } catch (_) {}
          }
          var updated = await table.update(data).eq('id', recordId).select('id');
          if (updated.isEmpty && tableName == 'daily_prayer_status') {
            final uidVal = data['user_id']?.toString() ?? '';
            final dateVal = data['date']?.toString() ?? DateTime.now().toUtc().toIso8601String().substring(0, 10);
            if (uidVal.isNotEmpty) {
              updated = await table
                  .update(data)
                  .eq('user_id', uidVal)
                  .eq('date', dateVal)
                  .select('id');
              if (updated.isNotEmpty) {
                return;
              }
            }
          }
          if (updated.isEmpty && tableName == 'prayers') {
            final prayerCode = data['prayer_code']?.toString() ??
                RegExp(r'(fajr|dhuhr|asr|maghrib|isha)', caseSensitive: false).firstMatch(recordId)?.group(1)?.toLowerCase();
            final uidVal = data['user_id']?.toString() ?? '';
            if (prayerCode != null && uidVal.isNotEmpty) {
              updated = await table
                  .update(data)
                  .eq('user_id', uidVal)
                  .eq('prayer_code', prayerCode)
                  .select('id');
              if (updated.isNotEmpty) {
                return; // Successfully updated remote prayer row by (user_id, prayer_code)
              }
            }
          }
          if (updated.isEmpty) {
            // Row didn't exist remotely; fall back to upsert to ensure insertion
            data['id'] = recordId;
            if (tableName == 'daily_prayer_status' &&
                (!data.containsKey('date') || data['date'] == null || (data['date'] is String && (data['date'] as String).trim().isEmpty))) {
              data['date'] = DateTime.now().toUtc().toIso8601String().substring(0, 10);
            }
            if (tableName == 'daily_prayer_status') {
              if (database != null) {
                try {
                  final local = await database.getOptional('SELECT * FROM daily_prayer_status WHERE id = ?', [recordId]);
                  if (local != null) {
                    for (final key in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'streak_days', 'habits_done', 'habits_total']) {
                      if (!data.containsKey(key) && local.containsKey(key) && local[key] != null) {
                        data[key] = local[key];
                      }
                    }
                  }
                } catch (_) {}
              }
              await table.upsert(data, onConflict: 'user_id,date');
            } else if (tableName == 'prayers') {
              final prayerCode = data['prayer_code']?.toString() ??
                  RegExp(r'(fajr|dhuhr|asr|maghrib|isha)', caseSensitive: false).firstMatch(recordId)?.group(1)?.toLowerCase() ??
                  'fajr';
              data['prayer_code'] = prayerCode;
              data['name'] ??= prayerCode[0].toUpperCase() + prayerCode.substring(1);
              data['icon'] ??= prayerCode;
              data['time'] ??= '12:00 PM';
              data['sort_order'] ??= ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].indexOf(prayerCode) + 1;
              final uidVal = data['user_id']?.toString() ?? '';
              if (uidVal.isNotEmpty) {
                data['id'] = 'prayer_${uidVal}_$prayerCode';
                await table.upsert(data, onConflict: 'user_id,prayer_code');
              } else {
                await table.upsert(data);
              }
            } else {
              await table.upsert(data);
            }
          }
        } else {
          data['id'] = recordId;
          if (tableName == 'daily_prayer_status' &&
              (!data.containsKey('date') || data['date'] == null || (data['date'] is String && (data['date'] as String).trim().isEmpty))) {
            data['date'] = DateTime.now().toUtc().toIso8601String().substring(0, 10);
          }
          if (tableName == 'daily_prayer_status') {
            if (database != null) {
              try {
                final local = await database.getOptional('SELECT * FROM daily_prayer_status WHERE id = ?', [recordId]);
                if (local != null) {
                  for (final key in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'streak_days', 'habits_done', 'habits_total']) {
                    if (!data.containsKey(key) && local.containsKey(key) && local[key] != null) {
                      data[key] = local[key];
                    }
                  }
                }
              } catch (_) {}
            }
            await table.upsert(data, onConflict: 'user_id,date');
          } else if (tableName == 'prayers') {
            final prayerCode = data['prayer_code']?.toString() ??
                RegExp(r'(fajr|dhuhr|asr|maghrib|isha)', caseSensitive: false).firstMatch(recordId)?.group(1)?.toLowerCase() ??
                'fajr';
            data['prayer_code'] = prayerCode;
            data['name'] ??= prayerCode[0].toUpperCase() + prayerCode.substring(1);
            data['icon'] ??= prayerCode;
            data['time'] ??= '12:00 PM';
            data['sort_order'] ??= ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].indexOf(prayerCode) + 1;
            final uidVal = data['user_id']?.toString() ?? '';
            if (uidVal.isNotEmpty) {
              data['id'] = 'prayer_${uidVal}_$prayerCode';
              await table.upsert(data, onConflict: 'user_id,prayer_code');
            } else {
              await table.upsert(data);
            }
          } else {
            await table.upsert(data);
          }
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
              _missingRemoteColumns.add('$tableName.$colName');
              data.remove(colName);
              continue;
            }
          }
          // Fallback: check known columns that might be missing on older schemas
          final knownOptionalCols = ['tags', 'category', 'mood', 'energy', 'avatar_url', 'start_date', 'is_enabled'];
          bool removedAny = false;
          for (final col in knownOptionalCols) {
            if (data.containsKey(col) && msg.contains(col)) {
              _missingRemoteColumns.add('$tableName.$col');
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

        // Case 4: RLS policy violation (Error 42501)
        if (code == '42501' ||
            msg.contains('row-level security') ||
            msg.contains('violates row-level security policy') ||
            msg.contains('forbidden') ||
            (e.details != null && e.details.toString().toLowerCase().contains('forbidden'))) {
          debugPrint('[PowerSync SupabaseConnector] RLS policy violation for "$tableName" [Code: 42501]: ${e.message}. Discarding unauthorizable mutation.');
          return;
        }

        // Case 5: Not-null constraint violation (Error 23502), e.g. missing date on daily_prayer_status or prayer_code on prayers
        if (code == '23502' || msg.contains('violates not-null constraint')) {
          final missingColMatch = RegExp(r'''column "([^"]+)" of relation''', caseSensitive: false).firstMatch(msg) ??
              RegExp(r'''null value in column "([^"]+)"''', caseSensitive: false).firstMatch(msg);
          final colName = missingColMatch?.group(1);
          if (colName == 'date' && tableName == 'daily_prayer_status') {
            final todayIso = DateTime.now().toUtc().toIso8601String().substring(0, 10);
            data['date'] = todayIso;
            debugPrint('[PowerSync SupabaseConnector] Self-healing: supplied missing "date" ($todayIso) on daily_prayer_status and retrying...');
            continue;
          }
          if (colName == 'prayer_code' && tableName == 'prayers') {
            final pCode = RegExp(r'(fajr|dhuhr|asr|maghrib|isha)', caseSensitive: false).firstMatch(recordId)?.group(1)?.toLowerCase() ?? 'fajr';
            data['prayer_code'] = pCode;
            data['name'] ??= pCode[0].toUpperCase() + pCode.substring(1);
            data['icon'] ??= pCode;
            data['time'] ??= '12:00 PM';
            data['sort_order'] ??= ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].indexOf(pCode) + 1;
            final uidVal = data['user_id']?.toString() ?? '';
            if (uidVal.isNotEmpty) {
              data['id'] = 'prayer_${uidVal}_$pCode';
            }
            debugPrint('[PowerSync SupabaseConnector] Self-healing: supplied missing "prayer_code" ($pCode) on prayers and retrying...');
            continue;
          }
        }

        // Case 6: Unique constraint violation (Error 23505), e.g. duplicate (user_id, prayer_code)
        if (code == '23505' || msg.contains('duplicate key value violates unique constraint')) {
          if (tableName == 'daily_prayer_status') {
            return;
          }

        if (tableName == 'prayers') {
            final pCode = data['prayer_code']?.toString() ??
                RegExp(r'(fajr|dhuhr|asr|maghrib|isha)', caseSensitive: false).firstMatch(recordId)?.group(1)?.toLowerCase();
            final uidVal = data['user_id']?.toString() ?? '';
            if (pCode != null && uidVal.isNotEmpty) {
              debugPrint('[PowerSync SupabaseConnector] Self-healing: resolving duplicate prayer by (user_id, prayer_code) update...');
              await table.update(data).eq('user_id', uidVal).eq('prayer_code', pCode);
              return;
            }
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
    if (session != null && session.isExpired && session.refreshToken != null && session.refreshToken!.isNotEmpty) {
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

        // Determine the record's true user_id owner.
        // For patch operations, op.opData often contains only changed columns and omits user_id.
        var recordOwner = rawData['user_id'] as String?;
        if ((recordOwner == null || recordOwner.isEmpty) &&
            tableName != 'friendships' &&
            op.op != UpdateType.delete) {
          try {
            final row = await database.getOptional(
              'SELECT user_id FROM $tableName WHERE id = ?',
              [op.id],
            );
            if (row != null && row['user_id'] != null) {
              final localOwner = row['user_id'] as String?;
              if (localOwner != null && localOwner.isNotEmpty) {
                recordOwner = localOwner;
              }
            }
          } catch (_) {
            // Table might not have user_id column
          }
        }

        // Strictly skip attempting to push other users' records to Supabase
        if (tableName != 'friendships' &&
            recordOwner != null &&
            recordOwner != uid &&
            recordOwner.isNotEmpty &&
            recordOwner != 'local_guest') {
          debugPrint('[PowerSync SupabaseConnector] Skipping foreign mutation on "$tableName" for user_id=$recordOwner (active uid is $uid)');
          continue;
        }

        final sanitizedData = _sanitizePayload(tableName, rawData, uid);

        if (tableName == 'prayers') {
          final pCode = sanitizedData['prayer_code']?.toString() ??
              RegExp(r'(fajr|dhuhr|asr|maghrib|isha)', caseSensitive: false).firstMatch(op.id)?.group(1)?.toLowerCase();
          if (pCode != null) {
            sanitizedData['prayer_code'] = pCode;
            sanitizedData['name'] ??= pCode[0].toUpperCase() + pCode.substring(1);
            sanitizedData['icon'] ??= pCode;
          }
        }

        if (op.op == UpdateType.put) {
          await _upsertWithRetry(
            tableName: tableName,
            initialData: sanitizedData,
            isPatch: false,
            recordId: op.id,
            database: database,
          );
        } else if (op.op == UpdateType.patch) {
          await _upsertWithRetry(
            tableName: tableName,
            initialData: sanitizedData,
            isPatch: true,
            recordId: op.id,
            database: database,
          );
        } else if (op.op == UpdateType.delete) {
          final table = client.from(tableName);
          if (tableName == 'friendships') {
            await table.delete().eq('id', op.id);
          } else if (uid.isNotEmpty) {
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
        if (client.auth.currentSession?.refreshToken != null) {
          try {
            await client.auth.refreshSession();
          } catch (_) {}
        }
      }
      // Do NOT complete transaction; let PowerSync retry
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint('[PowerSync SupabaseConnector] PostgrestException [${e.code}]: ${e.message}');
      final code = e.code ?? '';
      final msg = e.message.toLowerCase();

      final isRlsViolation = code == '42501' ||
          msg.contains('row-level security') ||
          msg.contains('violates row-level security policy');

      if (isRlsViolation) {
        debugPrint('[PowerSync SupabaseConnector] Discarding RLS-blocked transaction [Code: 42501]: ${e.message}');
        await transaction.complete();
        return;
      }

      final isAuthError = code == '401' ||
          code == '403' ||
          code == 'PGRST301' ||
          msg.contains('jwt') ||
          msg.contains('token') ||
          msg.contains('unauthorized') ||
          msg.contains('forbidden');

      if (isAuthError) {
        if (client.auth.currentSession?.refreshToken != null) {
          try {
            await client.auth.refreshSession();
          } catch (_) {}
        }
        // Do NOT complete transaction! Keep queued until auth succeeds
        rethrow;
      }

      // Truly unrecoverable schema errors (e.g., table does not exist at all, foreign key or unhealable constraint violation)
      final isTrulyFatal = code == '42P01' || // undefined table
          code == '23503' || // foreign key violation
          code == '23505' || // unique violation that couldn't be upserted
          code == '23502';   // not-null violation that couldn't be healed

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
