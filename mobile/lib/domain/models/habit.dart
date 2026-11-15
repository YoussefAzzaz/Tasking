import 'dart:convert';
import 'package:axis/data/habits/habit_state_manager.dart';

/// Domain model representing a user habit.
class Habit {
  final String id;
  final String name;
  final String category;
  final String icon;
  final String color;
  final String scheduleType;
  final String? remindTime;
  final int targetValue; // XP reward
  final bool isDoneToday;
  final int streakDays;
  final int sortOrder;
  final bool isEnabled;
  final String? createdAt;
  final String? shareId;
  final String? senderId;
  final String? senderUsername;

  Habit({
    required this.id,
    required this.name,
    this.category = '',
    this.icon = 'fitness',
    this.color = '#10B981',
    this.scheduleType = 'daily',
    this.remindTime,
    this.targetValue = 20,
    this.isDoneToday = false,
    this.streakDays = 0,
    this.sortOrder = 999,
    this.isEnabled = true,
    this.createdAt,
    this.shareId,
    this.senderId,
    this.senderUsername,
  });

  Habit copyWith({
    String? id,
    String? name,
    String? category,
    String? icon,
    String? color,
    String? scheduleType,
    String? remindTime,
    int? targetValue,
    bool? isDoneToday,
    int? streakDays,
    int? sortOrder,
    bool? isEnabled,
    String? createdAt,
    String? shareId,
    String? senderId,
    String? senderUsername,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      scheduleType: scheduleType ?? this.scheduleType,
      remindTime: remindTime ?? this.remindTime,
      targetValue: targetValue ?? this.targetValue,
      isDoneToday: isDoneToday ?? this.isDoneToday,
      streakDays: streakDays ?? this.streakDays,
      sortOrder: sortOrder ?? this.sortOrder,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      shareId: shareId ?? this.shareId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
    );
  }

  static String? _cleanUsername(dynamic raw) {
    final val = raw?.toString().trim() ?? '';
    if (val.isEmpty) return null;
    final cleaned = val.replaceFirst(RegExp(r'^@+'), '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  factory Habit.fromRow(
    Map<String, dynamic> row, {
    bool isDone = false,
    int streak = 0,
  }) {
    String cat = (row['kind'] as String?)?.trim() ?? '';
    if (cat.toLowerCase() == 'boolean' || cat.toLowerCase() == 'numeric') {
      cat = '';
    }
    if (cat.isEmpty) {
      final icon = (row['icon'] as String?) ?? '';
      if (icon == 'mosque' ||
          icon == 'prayer' ||
          icon == 'fajr' ||
          icon == 'dhuhr' ||
          icon == 'asr' ||
          icon == 'maghrib' ||
          icon == 'isha') {
        cat = 'Prayers';
      }
    }

    final id = row['id'] as String;
    final bool isEnabled;
    if (HabitStateManager.isHabitPaused(id)) {
      isEnabled = false;
    } else {
      final rawEnabled = row['is_enabled'];
      isEnabled = rawEnabled == null ||
          rawEnabled == 1 ||
          rawEnabled == true ||
          rawEnabled == '1' ||
          rawEnabled == 'true';
    }

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

    return Habit(
      id: id,
      name: row['name'] as String,
      category: cat,
      icon: (row['icon'] as String?) ?? 'fitness',
      color: (row['color'] as String?) ?? '#10B981',
      scheduleType: (row['schedule_type'] as String?) ?? 'daily',
      remindTime: row['remind_time'] as String?,
      targetValue: (row['target_value'] as num?)?.toInt() ?? 20,
      isDoneToday: isDone,
      streakDays: streak,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 999,
      isEnabled: isEnabled,
      createdAt: row['created_at'] as String?,
      shareId: (shareIdRaw != null && shareIdRaw.isNotEmpty) ? shareIdRaw : null,
      senderId:
          (senderIdRaw != null && senderIdRaw.isNotEmpty) ? senderIdRaw : null,
      senderUsername: resolvedSender,
    );
  }
}
