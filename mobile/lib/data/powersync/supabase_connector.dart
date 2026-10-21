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
    final session = Supabase.instance.client.auth.currentSession;
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

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final uid = user?.id ?? (getCurrentUserId != null ? getCurrentUserId!() : '');

      for (var op in transaction.crud) {
        final table = Supabase.instance.client.from(op.table);

        if (op.op == UpdateType.put) {
          final data = Map<String, dynamic>.from(op.opData!);
          data['id'] = op.id;
          if (uid.isNotEmpty &&
              (!data.containsKey('user_id') ||
                  data['user_id'] == null ||
                  (data['user_id'] as String).isEmpty)) {
            data['user_id'] = uid;
          }
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          final data = Map<String, dynamic>.from(op.opData!);
          if (uid.isNotEmpty &&
              (!data.containsKey('user_id') ||
                  data['user_id'] == null ||
                  (data['user_id'] as String).isEmpty)) {
            data['user_id'] = uid;
          }
          await table.update(data).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          if (uid.isNotEmpty) {
            // Guard: only delete records on Supabase that belong to the active user
            await table.delete().eq('id', op.id).eq('user_id', uid);
          } else {
            await table.delete().eq('id', op.id);
          }
        }
      }
      await transaction.complete();
    } on AuthException catch (e) {
      debugPrint('[PowerSync SupabaseConnector] AuthException [${e.statusCode}]: ${e.message}');
      if (e.statusCode == '401' || e.statusCode == '403') {
        try {
          debugPrint('[PowerSync SupabaseConnector] 401/403 encountered, refreshing Supabase session...');
          await Supabase.instance.client.auth.refreshSession();
        } catch (refreshErr) {
          debugPrint('[PowerSync SupabaseConnector] Token refresh error: $refreshErr');
        }
      }
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint('[PowerSync SupabaseConnector] PostgrestException [${e.code}]: ${e.message}');
      final code = e.code ?? '';
      final msg = e.message.toLowerCase();
      final isAuthError = code == '401' ||
          code == '403' ||
          code == 'PGRST301' ||
          msg.contains('jwt') ||
          msg.contains('token') ||
          msg.contains('unauthorized') ||
          msg.contains('forbidden');

      if (isAuthError) {
        try {
          debugPrint('[PowerSync SupabaseConnector] Auth error during uploadData, attempting token refresh...');
          await Supabase.instance.client.auth.refreshSession();
        } catch (refreshErr) {
          debugPrint('[PowerSync SupabaseConnector] Token refresh error: $refreshErr');
        }
        rethrow;
      }

      final isFatal = code.startsWith('22') ||
          code.startsWith('23') ||
          code.startsWith('42') ||
          code == 'PGRST116' ||
          code == 'PGRST204';
      if (isFatal) {
        debugPrint('[PowerSync SupabaseConnector] Discarding fatal transaction to unblock sync queue: ${e.message}');
        await transaction.complete();
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('[PowerSync SupabaseConnector] upload error: $e');
      rethrow;
    }
  }
}
