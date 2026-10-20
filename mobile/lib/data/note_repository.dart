import 'package:axis/data/powersync_db.dart';

class Note {
  final String id;
  final String title;
  final String bodyMd;
  final String category; // 'note', 'journal', 'voice'
  final String? mood; // 'HIGH ENERGY', 'CALM FOCUS', 'REFLECTIVE'
  final String? energy;
  final bool pinned;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.bodyMd,
    this.category = 'note',
    this.mood,
    this.energy,
    this.pinned = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Note.fromRow(Map<String, dynamic> row) {
    return Note(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? 'Untitled Note',
      bodyMd: (row['body_md'] as String?) ?? '',
      category: (row['category'] as String?) ?? 'note',
      mood: row['mood'] as String?,
      energy: row['energy'] as String?,
      pinned: ((row['pinned'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class NoteRepository {
  Stream<List<Note>> watchNotes({String? category}) {

    final query = category != null && category != 'all'
        ? 'SELECT * FROM notes WHERE category = ? ORDER BY created_at DESC'
        : 'SELECT * FROM notes ORDER BY pinned DESC, created_at DESC';

    final params = (category != null && category != 'all') ? [category] : <dynamic>[];

    return db.watch(query, parameters: params).map((rows) {
      return rows.map((r) => Note.fromRow(r)).toList();
    });
  }

  Future<void> addNote(Note note) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await db.execute('''
        INSERT INTO notes (
          id, title, body_md, pinned, category, mood, energy, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        note.id,
        note.title,
        note.bodyMd,
        note.pinned ? 1 : 0,
        note.category,
        note.mood,
        note.energy,
        now,
        now,
      ]).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<void> updateNote(Note note) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await db.execute('''
        UPDATE notes SET
          title = ?, body_md = ?, pinned = ?, category = ?, mood = ?, energy = ?, updated_at = ?
        WHERE id = ?
      ''', [
        note.title,
        note.bodyMd,
        note.pinned ? 1 : 0,
        note.category,
        note.mood,
        note.energy,
        now,
        note.id,
      ]).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<void> deleteNote(String id) async {
    try {
      await db.execute('DELETE FROM notes WHERE id = ?', [id]).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
