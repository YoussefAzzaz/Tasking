import 'package:powersync/powersync.dart';

/// PowerSync Schema defining multi-tenant isolated tables
/// based on SPEC.md §4 Core Data Entities.
const appSchema = Schema([
  Table(
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
  Table(
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
  Table(
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
  Table(
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
  Table(
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
      Column.integer('is_enabled'),
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
  Table(
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
  Table(
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
  Table(
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
  Table(
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
  Table(
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
  Table(
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
  Table(
    'user_profiles',
    [
      Column.text('user_id'),
      Column.text('name'),
      Column.text('title'),
      Column.text('avatar_color'),
      Column.text('avatar_url'),
      Column.integer('total_xp'),
      Column.integer('level'),
      Column.text('friend_code'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('friend_code', [IndexedColumn.ascending('friend_code')]),
    ],
  ),
  Table(
    'friendships',
    [
      Column.text('requester_id'),
      Column.text('addressee_id'),
      Column.text('status'), // 'pending', 'accepted', 'blocked'
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('requester_id', [IndexedColumn.ascending('requester_id')]),
      Index('addressee_id', [IndexedColumn.ascending('addressee_id')]),
      Index('status', [IndexedColumn.ascending('status')]),
    ],
  ),
  Table(
    'daily_prayer_status',
    [
      Column.text('user_id'),
      Column.text('date'),
      Column.integer('fajr'),
      Column.integer('dhuhr'),
      Column.integer('asr'),
      Column.integer('maghrib'),
      Column.integer('isha'),
      Column.integer('streak_days'),
      Column.integer('habits_done'),
      Column.integer('habits_total'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('date', [IndexedColumn.ascending('date')]),
      Index('user_date', [IndexedColumn.ascending('user_id'), IndexedColumn.ascending('date')]),
    ],
  ),
  Table(
    'friend_activity_logs',
    [
      Column.text('user_id'),
      Column.text('event_type'),
      Column.text('title'),
      Column.text('metadata'), // JSON string
      Column.text('created_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn.ascending('user_id')]),
      Index('created_at', [IndexedColumn.descending('created_at')]),
    ],
  ),
  Table(
    'companion_shares',
    [
      Column.text('sender_id'),
      Column.text('recipient_id'),
      Column.text('entity_type'), // 'task', 'habit', 'note', 'project'
      Column.text('entity_id'),
      Column.text('share_mode'), // 'copy', 'collaborate'
      Column.text('status'), // 'pending', 'accepted', 'declined', 'cancelled'
      Column.text('preview_data'), // JSON string
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('recipient_status', [
        IndexedColumn.ascending('recipient_id'),
        IndexedColumn.ascending('status'),
      ]),
      Index('sender_status', [
        IndexedColumn.ascending('sender_id'),
        IndexedColumn.ascending('status'),
      ]),
      Index('entity', [
        IndexedColumn.ascending('entity_type'),
        IndexedColumn.ascending('entity_id'),
      ]),
    ],
  ),
]);
