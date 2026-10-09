import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

late PowerSyncDatabase db;
bool _dbInitialized = false;

// We define the schema based on SPEC.md §4 Core Data Entities
final schema = Schema([
  const Table('tasks', [
    Column.text('title'),
    Column.text('status'), // 'todo', 'done', 'skipped'
    Column.integer('priority'),
    Column.text('project_id'),
    Column.text('tags'), // JSON string or comma separated
    Column.text('due_date'), // YYYY-MM-DD
    Column.text('due_time'), // HH:mm
    Column.integer('estimate_min'),
    Column.text('recurrence_rule'),
    Column.text('recurrence_mode'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  const Table('projects', [
    Column.text('name'),
    Column.text('color'),
    Column.text('created_at'),
  ]),
  const Table('tags', [
    Column.text('name'),
    Column.text('color'),
    Column.text('created_at'),
  ]),
  const Table('logs', [
    Column.text('task_id'),
    Column.text('event_type'),
    Column.integer('xp_earned'),
    Column.text('timestamp'),
  ])
]);

class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseConnector() : super();

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return null;
    }
    final token = session.accessToken;
    
    // In production, your backend would generate a secure PowerSync token.
    // For local dev, we use the JWT directly if PowerSync is configured to trust Supabase JWTs.
    return PowerSyncCredentials(
      endpoint: const String.fromEnvironment('POWERSYNC_URL', defaultValue: 'http://localhost:8080'),
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
      for (var op in transaction.crud) {
        final table = Supabase.instance.client.from(op.table);
        if (op.op == UpdateType.put) {
          await table.upsert(op.opData!);
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } catch (e) {
      // In real life, handle specific errors
      rethrow;
    }
  }
}

Future<void> openDatabase() async {
  if (_dbInitialized) return;
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'axis_powersync.db');

  db = PowerSyncDatabase(schema: schema, path: path);
  await db.initialize();

  // Connect to Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'http://localhost:54321'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'dummy_key'),
  );

  final connector = SupabaseConnector();
  db.connect(connector: connector);

  _dbInitialized = true;
}
