import 'package:flutter/foundation.dart';
import 'package:axis/data/powersync_db.dart';

class Note {
  final String id;
  final String? userId;
  final String title;
  final String bodyMd;
  final String category; // 'note', 'journal', 'voice'
  final String? mood; // 'HIGH ENERGY', 'CALM FOCUS', 'REFLECTIVE'
  final String? energy;
  final bool pinned;
  final DateTime createdAt;

  Note({
    required this.id,
    this.userId,
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
      userId: row['user_id'] as String?,
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

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? bodyMd,
    String? category,
    String? mood,
    String? energy,
    bool? pinned,
    DateTime? createdAt,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      bodyMd: bodyMd ?? this.bodyMd,
      category: category ?? this.category,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NoteRepository {
  Stream<List<Note>> watchNotes({String? category, int? limit, int? offset}) {
    if (!isDatabaseInitialized) {
      return Stream.value(const <Note>[]);
    }
    final uid = currentUserId;
    String query;
    List<dynamic> params = [];

    if (uid.isNotEmpty) {
      if (category != null && category != 'all') {
        query = 'SELECT * FROM notes WHERE category = ? AND user_id = ? AND (deleted_at IS NULL OR deleted_at = \'\') ORDER BY pinned DESC, created_at DESC';
        params = [category, uid];
      } else {
        query = 'SELECT * FROM notes WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = \'\') ORDER BY pinned DESC, created_at DESC';
        params = [uid];
      }
    } else {
      if (category != null && category != 'all') {
        query = 'SELECT * FROM notes WHERE category = ? AND (deleted_at IS NULL OR deleted_at = \'\') ORDER BY pinned DESC, created_at DESC';
        params = [category];
      } else {
        query = 'SELECT * FROM notes WHERE (deleted_at IS NULL OR deleted_at = \'\') ORDER BY pinned DESC, created_at DESC';
        params = [];
      }
    }

    if (limit != null && limit > 0) {
      query += ' LIMIT $limit';
      if (offset != null && offset > 0) {
        query += ' OFFSET $offset';
      }
    }

    return db.watch(query, parameters: params).map((rows) {
      return rows.map((r) => Note.fromRow(r)).toList();
    });
  }

  /// Fetches notes with optional category filter, limit, and offset.
  Future<List<Note>> getNotes({String? category, int? limit, int? offset}) async {
    if (!isDatabaseInitialized) return const [];
    final uid = currentUserId;
    String query;
    List<dynamic> params = [];

    if (uid.isNotEmpty) {
      if (category != null && category != 'all') {
        query = 'SELECT * FROM notes WHERE category = ? AND user_id = ? AND (deleted_at IS NULL OR deleted_at = \'\') ORDER BY pinned DESC, created_at DESC';
        params = [category, uid];
      } else {
        query = 'SELECT * FROM notes WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = \'\') ORDER BY pinned DESC, created_at DESC';
        params = [uid];
      }
    } else {
      if (category != null && category != 'all') {
        query = 'SELECT * FROM notes WHERE category = ? AND (deleted_at IS NULL OR deleted_at = \'\') ORDER BY pinned DESC, created_at DESC';
        params = [category];
      } else {
        query = 'SELECT * FROM notes WHERE (deleted_at IS NULL OR deleted_at = \'\') ORDER BY pinned DESC, created_at DESC';
        params = [];
      }
    }

    if (limit != null && limit > 0) {
      query += ' LIMIT $limit';
      if (offset != null && offset > 0) {
        query += ' OFFSET $offset';
      }
    }

    final rows = await db.getAll(query, params);
    return rows.map((r) => Note.fromRow(r)).toList();
  }

  /// Fetches total count of active notes/journals for user.
  Future<int> getNotesCount({String? category}) async {
    if (!isDatabaseInitialized) return 0;
    final uid = currentUserId;
    String query;
    List<dynamic> params = [];

    if (uid.isNotEmpty) {
      if (category != null && category != 'all') {
        query = 'SELECT COUNT(*) as count FROM notes WHERE category = ? AND user_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')';
        params = [category, uid];
      } else {
        query = 'SELECT COUNT(*) as count FROM notes WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = \'\')';
        params = [uid];
      }
    } else {
      if (category != null && category != 'all') {
        query = 'SELECT COUNT(*) as count FROM notes WHERE category = ? AND (deleted_at IS NULL OR deleted_at = \'\')';
        params = [category];
      } else {
        query = 'SELECT COUNT(*) as count FROM notes WHERE (deleted_at IS NULL OR deleted_at = \'\')';
        params = [];
      }
    }

    final row = await db.getOptional(query, params);
    return (row?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> addNote(Note note) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final uid = note.userId ?? currentUserId;
    try {
      await db.execute('''
        INSERT INTO notes (
          id, user_id, title, body_md, pinned, category, mood, energy, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        note.id,
        uid,
        note.title,
        note.bodyMd,
        note.pinned ? 1 : 0,
        note.category,
        note.mood,
        note.energy,
        now,
        now,
      ]);
    } catch (e) {
      debugPrint('[NoteRepository] Error adding note: $e');
      rethrow;
    }
  }

  Future<void> updateNote(Note note) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final uid = currentUserId;
    try {
      await db.execute('''
        UPDATE notes SET
          user_id = COALESCE(NULLIF(user_id, ''), ?),
          title = ?, body_md = ?, pinned = ?, category = ?, mood = ?, energy = ?, updated_at = ?
        WHERE id = ?
      ''', [
        uid,
        note.title,
        note.bodyMd,
        note.pinned ? 1 : 0,
        note.category,
        note.mood,
        note.energy,
        now,
        note.id,
      ]);
    } catch (e) {
      debugPrint('[NoteRepository] Error updating note: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.execute('UPDATE notes SET deleted_at = ?, updated_at = ? WHERE id = ?', [nowUtc, nowUtc, id]);
    } catch (e) {
      debugPrint('[NoteRepository] Error deleting note: $e');
      rethrow;
    }
  }
}
