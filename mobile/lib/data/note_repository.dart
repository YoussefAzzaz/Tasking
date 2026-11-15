import 'dart:convert';
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
  final String? shareId;
  final String? senderId;
  final String? senderUsername;

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
    this.shareId,
    this.senderId,
    this.senderUsername,
  }) : createdAt = createdAt ?? DateTime.now();

  static String? _cleanUsername(dynamic raw) {
    final val = raw?.toString().trim() ?? '';
    if (val.isEmpty) return null;
    final cleaned = val.replaceFirst(RegExp(r'^@+'), '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  factory Note.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> preview = const {};
    final rawPreview = row['share_preview_data'];
    if (rawPreview is Map) {
      preview = Map<String, dynamic>.from(rawPreview);
    } else if (rawPreview is String && rawPreview.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPreview);
        if (decoded is Map) {
          preview = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final shareIdRaw = row['share_id']?.toString().trim();
    final previewSender = _cleanUsername(preview['sender_name']);
    final rowSender = _cleanUsername(row['sender_username']);
    final resolvedSender = (rowSender != null && rowSender != 'Companion')
        ? rowSender
        : (previewSender ?? rowSender);
    final senderIdRaw =
        row['share_sender_id']?.toString().trim() ??
        preview['sender_id']?.toString().trim();

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
      shareId: (shareIdRaw != null && shareIdRaw.isNotEmpty) ? shareIdRaw : null,
      senderId:
          (senderIdRaw != null && senderIdRaw.isNotEmpty) ? senderIdRaw : null,
      senderUsername: resolvedSender,
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
    String? shareId,
    String? senderId,
    String? senderUsername,
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
      shareId: shareId ?? this.shareId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
    );
  }
}

class NoteRepository {
  static const String _joinedNotesSelectPrefix = '''
    SELECT
      n.*,
      cs.id AS share_id,
      cs.sender_id AS share_sender_id,
      cs.preview_data AS share_preview_data,
      sp.name AS sender_username
    FROM notes n
    LEFT JOIN companion_shares cs
      ON cs.id = (
        SELECT cs2.id
        FROM companion_shares cs2
        WHERE cs2.entity_type = 'note'
          AND cs2.status = 'accepted'
          AND cs2.accepted_entity_id = n.id
          AND cs2.sender_id != COALESCE(n.user_id, '')
        ORDER BY cs2.updated_at DESC
        LIMIT 1
      )
    LEFT JOIN user_profiles sp ON sp.user_id = cs.sender_id
  ''';

  Future<bool> _hasShareJoinTables() async {
    if (!isDatabaseInitialized) return false;
    try {
      final rows = await db.getAll('''
        SELECT name FROM sqlite_master
        WHERE type IN ('table', 'view')
          AND name IN ('companion_shares', 'user_profiles')
      ''');
      return rows.length >= 2;
    } catch (_) {
      return false;
    }
  }

  (String, List<dynamic>) _buildNotesQuery({
    required bool hasJoin,
    required String uid,
    String? category,
    int? limit,
    int? offset,
  }) {
    final alias = hasJoin ? 'n.' : '';
    final prefix = hasJoin ? _joinedNotesSelectPrefix : 'SELECT * FROM notes';
    final conditions = <String>[
      '(${alias}deleted_at IS NULL OR ${alias}deleted_at = \'\')',
    ];
    final params = <dynamic>[];

    if (category != null && category != 'all') {
      conditions.add('${alias}category = ?');
      params.add(category);
    }
    if (uid.isNotEmpty) {
      conditions.add('${alias}user_id = ?');
      params.add(uid);
    }

    var query =
        '$prefix WHERE ${conditions.join(' AND ')} ORDER BY ${alias}pinned DESC, ${alias}created_at DESC';
    if (limit != null && limit > 0) {
      query += ' LIMIT $limit';
      if (offset != null && offset > 0) {
        query += ' OFFSET $offset';
      }
    }
    return (query, params);
  }

  Stream<List<Note>> watchNotes({String? category, int? limit, int? offset}) {
    if (!isDatabaseInitialized) {
      return Stream.value(const <Note>[]);
    }
    return _watchNotesInternal(
      category: category,
      limit: limit,
      offset: offset,
    );
  }

  Stream<List<Note>> _watchNotesInternal({
    String? category,
    int? limit,
    int? offset,
  }) async* {
    final uid = currentUserId;
    final hasJoin = await _hasShareJoinTables();
    final (query, params) = _buildNotesQuery(
      hasJoin: hasJoin,
      uid: uid,
      category: category,
      limit: limit,
      offset: offset,
    );

    yield* db.watch(query, parameters: params).map((rows) {
      return _deduplicateNotes(rows.map((r) => Note.fromRow(r)).toList());
    });
  }

  List<Note> _deduplicateNotes(List<Note> notes) {
    final seenIds = <String, int>{};
    final seenKeys = <String, int>{};
    final result = <Note>[];
    for (final n in notes) {
      final hasSender =
          n.senderUsername != null && n.senderUsername!.trim().isNotEmpty;
      final existingById = seenIds[n.id];
      if (existingById != null) {
        final existing = result[existingById];
        final existingHasSender = existing.senderUsername != null &&
            existing.senderUsername!.trim().isNotEmpty;
        if (!existingHasSender && hasSender) {
          result[existingById] = n;
        }
        continue;
      }
      final normKey =
          '${n.title.trim().toLowerCase()}|${n.bodyMd.trim().toLowerCase()}|${n.category.trim().toLowerCase()}';
      final existingByKey = n.title.trim().isNotEmpty ? seenKeys[normKey] : null;
      if (existingByKey != null) {
        final existing = result[existingByKey];
        final existingHasSender = existing.senderUsername != null &&
            existing.senderUsername!.trim().isNotEmpty;
        if (!existingHasSender && hasSender) {
          result[existingByKey] = n;
        }
        continue;
      }
      final idx = result.length;
      seenIds[n.id] = idx;
      if (n.title.trim().isNotEmpty) {
        seenKeys[normKey] = idx;
      }
      result.add(n);
    }
    return result;
  }

  /// Fetches notes with optional category filter, limit, and offset.
  Future<List<Note>> getNotes({String? category, int? limit, int? offset}) async {
    if (!isDatabaseInitialized) return const [];
    final uid = currentUserId;
    final hasJoin = await _hasShareJoinTables();
    final (query, params) = _buildNotesQuery(
      hasJoin: hasJoin,
      uid: uid,
      category: category,
      limit: limit,
      offset: offset,
    );

    if (hasJoin) {
      try {
        final rows = await db.getAll(query, params);
        return _deduplicateNotes(rows.map((r) => Note.fromRow(r)).toList());
      } catch (e) {
        debugPrint('[NoteRepository] Joined getNotes fallback: $e');
      }
    }

    final (fallbackQuery, fallbackParams) = _buildNotesQuery(
      hasJoin: false,
      uid: uid,
      category: category,
      limit: limit,
      offset: offset,
    );
    final rows = await db.getAll(fallbackQuery, fallbackParams);
    return _deduplicateNotes(rows.map((r) => Note.fromRow(r)).toList());
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
        INSERT OR REPLACE INTO notes (
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
