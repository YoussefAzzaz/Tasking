import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'friend_models.dart';

/// Repository managing activity logs, companion reminders, and nudges.
class FriendActivityRepository {
  static final FriendActivityRepository _instance = FriendActivityRepository._();
  factory FriendActivityRepository() => _instance;
  FriendActivityRepository._();

  final Set<String> _dismissedLogIds = {};
  bool _dismissedLoaded = false;

  Future<void> _ensureDismissedLoaded() async {
    if (_dismissedLoaded) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dismissed_notifications.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = (jsonDecode(content) as List?)?.cast<String>();
        if (list != null) {
          _dismissedLogIds.addAll(list);
        }
      }
      _dismissedLoaded = true;
    } catch (_) {
      _dismissedLoaded = true;
    }
  }

  Future<void> _persistDismissedLogIds() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dismissed_notifications.json');
      await file.writeAsString(jsonEncode(_dismissedLogIds.toList()));
    } catch (_) {}
  }

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isRemoteAuthenticated {
    final client = _supabaseClient;
    if (client == null) return false;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    if (session != null && user != null && user.id.isNotEmpty && user.id != 'local_guest') {
      return true;
    }
    final savedUid = AuthService().currentUserId;
    return savedUid != null && savedUid.isNotEmpty && savedUid != 'local_guest';
  }

  bool _hasPurgedOldLogsThisSession = false;

  void clearSessionState() {
    _hasPurgedOldLogsThisSession = false;
    _dismissedLogIds.clear();
    _dismissedLoaded = false;
  }

  @visibleForTesting
  Set<String> get dismissedLogIdsForTesting => _dismissedLogIds;

  @visibleForTesting
  void resetDismissedForTesting() {
    _dismissedLogIds.clear();
    _dismissedLoaded = false;
  }

  String get currentUserId {
    if (isSigningOut) return '';
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    return AuthService().currentUserId ?? '';
  }

  String get currentUserName {
    try {
      final profileName = UserProfileRepository().profileNotifier.value.name;
      if (profileName.trim().isNotEmpty && profileName != 'Commander') {
        return profileName;
      }
    } catch (_) {}
    try {
      final authName = Supabase.instance.client.auth.currentUser?.userMetadata?['name']?.toString();
      if (authName != null && authName.trim().isNotEmpty) return authName;
    } catch (_) {}
    final authServiceDisplayName = AuthService().displayName;
    if (authServiceDisplayName.trim().isNotEmpty) {
      return authServiceDisplayName;
    }
    return 'Companion';
  }

  /// Watches in-app friend activity notifications and reminders for the current user.
  Stream<List<FriendActivityLog>> watchFriendActivityLogs() {
    if (!isDatabaseInitialized) {
      return Stream.value(const []);
    }

    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    const query = '''
      SELECT 
        l.id,
        l.user_id,
        l.event_type,
        l.title,
        l.metadata,
        l.created_at,
        COALESCE(p.name, 'Companion') AS sender_name,
        COALESCE(p.avatar_color, '#6366F1') AS sender_avatar_color
      FROM friend_activity_logs l
      LEFT JOIN user_profiles p ON p.user_id = json_extract(l.metadata, '\$.sender_id')
      WHERE l.user_id = ?
      ORDER BY l.created_at DESC
      LIMIT 30
    ''';

    return db.watch(query, parameters: [uid]).asyncMap((rows) async {
      await _ensureDismissedLoaded();
      return rows
          .map((r) => FriendActivityLog.fromRow(r))
          .where((log) => !_dismissedLogIds.contains(log.id))
          .toList();
    });
  }

  /// Dismisses a single notification by id permanently.
  Future<void> dismissNotification(String logId) async {
    if (logId.isEmpty) return;
    await _ensureDismissedLoaded();
    _dismissedLogIds.add(logId);
    await _persistDismissedLogIds();

    if (isDatabaseInitialized) {
      try {
        await db.execute('DELETE FROM friend_activity_logs WHERE id = ?', [logId]);
      } catch (e) {
        debugPrint('[FriendActivityRepository] Error deleting log locally: $e');
      }
    }

    if (isRemoteAuthenticated) {
      try {
        await AuthService().ensureAuthenticatedSession();
        await _supabaseClient?.from('friend_activity_logs').delete().eq('id', logId);
      } catch (e) {
        debugPrint('[FriendActivityRepository] Notice dismissing notification on Supabase: $e');
      }
    }
  }

  /// Clears notifications for the current user permanently across launches.
  Future<void> clearFriendNotifications() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    await _ensureDismissedLoaded();

    if (isDatabaseInitialized) {
      try {
        final rows = await db.getAll('SELECT id FROM friend_activity_logs WHERE user_id = ?', [uid]);
        for (final row in rows) {
          final id = row['id']?.toString();
          if (id != null && id.isNotEmpty) {
            _dismissedLogIds.add(id);
          }
        }
        await _persistDismissedLogIds();
        await db.execute('DELETE FROM friend_activity_logs WHERE user_id = ?', [uid]);
      } catch (e) {
        debugPrint('[FriendActivityRepository] Error clearing logs locally: $e');
      }
    }

    if (isRemoteAuthenticated) {
      try {
        await AuthService().ensureAuthenticatedSession();
        await _supabaseClient?.from('friend_activity_logs').delete().eq('user_id', uid);
      } catch (e) {
        debugPrint('[FriendActivityRepository] Notice clearing notifications on Supabase: $e');
      }
    }
  }

  /// Purges transient friend activity logs older than 15 days in both Supabase and local SQLite.
  /// Note: Never purges the `logs` table, which stores persistent user XP and gamification history.
  Future<void> purgeOldLogs({bool force = false}) async {
    if (isSigningOut) return;
    if (!force && _hasPurgedOldLogsThisSession) return;
    _hasPurgedOldLogsThisSession = true;

    final cutoff = DateTime.now().subtract(const Duration(days: 15)).toUtc().toIso8601String();

    // 1. Purge local SQLite
    if (isDatabaseInitialized && !isSigningOut) {
      try {
        await db.execute('DELETE FROM friend_activity_logs WHERE created_at < ?', [cutoff]);
      } catch (e) {
        debugPrint('[LogCleanup] Local purge error: $e');
      }
    }

    // 2. Purge Supabase
    if (!isSigningOut && isRemoteAuthenticated && _supabaseClient != null) {
      try {
        await _supabaseClient!
            .from('friend_activity_logs')
            .delete()
            .lt('created_at', cutoff);
      } catch (e) {
        debugPrint('[LogCleanup] Supabase friend_activity_logs purge notice: $e');
      }

      try {
        await _supabaseClient!.rpc('clean_expired_logs');
      } catch (_) {}
    }
  }

  /// Pulls friend activity logs and notifications from Supabase
  Future<void> syncActivityLogsFromRemote() async {
    if (isSigningOut) return;
    unawaited(purgeOldLogs());
    await AuthService().ensureAuthenticatedSession();
    if (isSigningOut) return;
    final client = _supabaseClient;
    final uid = currentUserId;
    if (!isRemoteAuthenticated || client == null || uid.isEmpty || !isDatabaseInitialized) return;

    await _ensureDismissedLoaded();

    // Clean any locally present dismissed notifications
    if (_dismissedLogIds.isNotEmpty) {
      try {
        final placeholders = List.filled(_dismissedLogIds.length, '?').join(',');
        await db.execute(
          'DELETE FROM friend_activity_logs WHERE id IN ($placeholders)',
          _dismissedLogIds.toList(),
        );
      } catch (_) {}
    }

    try {
      final remoteLogs = await client
          .from('friend_activity_logs')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(30);

      for (final r in remoteLogs) {
        final lId = r['id']?.toString() ?? '';
        if (lId.isEmpty) continue;

        // Never pull or restore dismissed logs
        if (_dismissedLogIds.contains(lId)) {
          try {
            await client.from('friend_activity_logs').delete().eq('id', lId);
          } catch (_) {}
          continue;
        }

        final evType = r['event_type']?.toString() ?? 'prayer_reminder';
        final title = r['title']?.toString() ?? '';
        final meta = r['metadata'] != null ? jsonEncode(r['metadata']) : '{}';
        final created = r['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String();

        final existing = await db.getOptional('SELECT id FROM friend_activity_logs WHERE id = ?', [lId]);
        if (existing == null) {
          await db.execute(
            'INSERT INTO friend_activity_logs (id, user_id, event_type, title, metadata, created_at) VALUES (?, ?, ?, ?, ?, ?)',
            [lId, uid, evType, title, meta, created],
          );
        }
      }
    } catch (e) {
      debugPrint('[FriendActivityRepository] syncActivityLogsFromRemote notice: $e');
    }
  }
}

