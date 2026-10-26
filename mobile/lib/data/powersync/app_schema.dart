import 'package:powersync/powersync.dart';

/// PowerSync Schema defining multi-tenant isolated tables
/// based on SPEC.md §4 Core Data Entities.
final appSchema = Schema([
  const Table(
    'tasks',
    [
      Column.text('user_id'),
      Column.text('title'),
      Column.text('notes'),
      Column.text('status'), // 'todo', 'done', 'skipped'
      Column.integer('priority'),
      Column.text('project_id'),
      Column.text('tags'), // JSON string or comma separated
      Column.text('due_date'), // YYYY-MM-DD
      Column.text('due_time'), // HH:mm
      Column.integer('estimate_min'),
      Column.text('recurrence_rule'),
      Column.text('recurrence_mode'),
      Column.text('completed_at'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('due_date', [IndexedColumn.ascending('due_date')]),
      Index('status_due', [IndexedColumn.ascending('status'), IndexedColumn.ascending('due_date')]),
      Index('project', [IndexedColumn.ascending('project_id')]),
      Index('created_at', [IndexedColumn.ascending('created_at')]),
      Index('user_status', [IndexedColumn.ascending('user_id'), IndexedColumn.ascending('status')]),
      Index('user_status_priority', [
        IndexedColumn.ascending('user_id'),
        IndexedColumn.ascending('status'),
        IndexedColumn.ascending('priority'),
      ]),
    ],
  ),
  const Table(
    'projects',
    [
      Column.text('user_id'),
      Column.text('name'),
      Column.text('color'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
    ],
  ),
  const Table(
    'tags',
    [
      Column.text('user_id'),
      Column.text('name'),
      Column.text('color'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
    ],
  ),
  const Table(
    'logs',
    [
      Column.text('user_id'),
      Column.text('task_id'),
      Column.text('event_type'),
      Column.integer('xp_earned'),
      Column.text('timestamp'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('timestamp', [IndexedColumn.ascending('timestamp')]),
      Index('task_event', [IndexedColumn.ascending('task_id'), IndexedColumn.ascending('event_type')]),
    ],
  ),
  const Table(
    'habits',
    [
      Column.text('user_id'),
      Column.text('name'),
      Column.text('icon'),
      Column.text('color'),
      Column.text('kind'),
      Column.integer('target_value'),
      Column.text('unit'),
      Column.text('schedule_type'),
      Column.text('remind_time'),
      Column.integer('sort_order'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('sort_order', [IndexedColumn.ascending('sort_order')]),
      Index('kind', [IndexedColumn.ascending('kind')]),
    ],
  ),
  const Table(
    'habit_logs',
    [
      Column.text('user_id'),
      Column.text('habit_id'),
      Column.text('log_date'),
      Column.text('status'),
      Column.integer('value'),
      Column.text('note'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('habit_date', [IndexedColumn.ascending('habit_id'), IndexedColumn.ascending('log_date')]),
      Index('date_status', [IndexedColumn.ascending('log_date'), IndexedColumn.ascending('status')]),
      Index('user_status', [IndexedColumn.ascending('user_id'), IndexedColumn.ascending('status')]),
    ],
  ),
  const Table(
    'notes',
    [
      Column.text('user_id'),
      Column.text('title'),
      Column.text('body_md'),
      Column.integer('pinned'),
      Column.text('category'),
      Column.text('mood'),
      Column.text('energy'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('pinned_created', [IndexedColumn.ascending('pinned'), IndexedColumn.ascending('created_at')]),
      Index('category', [IndexedColumn.ascending('category')]),
      Index('user_pinned', [IndexedColumn.ascending('user_id'), IndexedColumn.ascending('pinned')]),
    ],
  ),
  const Table(
    'focus_sessions',
    [
      Column.text('user_id'),
      Column.text('task_id'),
      Column.text('kind'),
      Column.integer('planned_min'),
      Column.integer('actual_min'),
      Column.text('started_at'),
      Column.text('ended_at'),
      Column.integer('completed'),
      Column.integer('xp_earned'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('completed', [IndexedColumn.ascending('completed'), IndexedColumn.ascending('started_at')]),
      Index('user_completed', [
        IndexedColumn.ascending('user_id'),
        IndexedColumn.ascending('completed'),
        IndexedColumn.ascending('actual_min'),
      ]),
    ],
  ),
  const Table(
    'habit_categories',
    [
      Column.text('user_id'),
      Column.text('name'),
      Column.text('icon'),
      Column.text('color'),
      Column.integer('sort_order'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
    ],
  ),
  const Table(
    'note_categories',
    [
      Column.text('user_id'),
      Column.text('name'),
      Column.text('icon'),
      Column.text('color'),
      Column.integer('sort_order'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
    ],
  ),
  const Table(
    'prayers',
    [
      Column.text('user_id'),
      Column.text('prayer_code'),
      Column.text('name'),
      Column.text('icon'),
      Column.text('time'),
      Column.integer('sort_order'),
      Column.integer('is_done'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('user_sort', [IndexedColumn.ascending('user_id'), IndexedColumn.ascending('sort_order')]),
      Index('user_done', [IndexedColumn.ascending('user_id'), IndexedColumn.ascending('is_done')]),
    ],
  ),
  const Table(
    'user_profiles',
    [
      Column.text('user_id'),
      Column.text('name'),
      Column.text('title'),
      Column.text('avatar_color'),
      Column.text('avatar_url'),
      Column.integer('total_xp'),
      Column.integer('level'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
    ],
  ),
]);
