import 'package:intl/intl.dart';

/// Database representation of a prayer from the dedicated `prayers` table.
class Prayer {
  final String id;
  final String userId;
  final String prayerCode; // 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'
  final String name; // 'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'
  final String icon; // 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'
  final String time; // e.g. '05:14 AM'
  final int sortOrder; // 1..5
  final bool isDone;
  final String createdAt;
  final String updatedAt;

  const Prayer({
    required this.id,
    required this.userId,
    required this.prayerCode,
    required this.name,
    required this.icon,
    required this.time,
    required this.sortOrder,
    required this.isDone,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory to construct a Prayer from an SQLite row with automatic daily reset check.
  factory Prayer.fromRow(Map<String, dynamic> row) {
    final rawDone = row['is_done'];
    bool done = rawDone == 1 || rawDone == true || rawDone == 'true' || rawDone == '1';
    final todayLogStatus = (row['today_log_status'] as String?)?.toLowerCase();

    if (todayLogStatus == 'done') {
      done = true;
    } else {
      final updatedAt = (row['updated_at'] as String?) ?? '';
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Auto-reset completion flag if updated_at is from a previous calendar day
      if (done && updatedAt.isNotEmpty) {
        try {
          final updatedDateLocal = DateTime.parse(updatedAt).toLocal();
          final now = DateTime.now();
          final isToday = updatedDateLocal.year == now.year &&
              updatedDateLocal.month == now.month &&
              updatedDateLocal.day == now.day;
          if (!isToday) {
            done = false;
          }
        } catch (_) {
          if (!updatedAt.startsWith(today)) {
            done = false;
          }
        }
      }
    }

    final code = (row['prayer_code'] as String?) ?? '';
    String name = (row['name'] as String?) ?? '';
    if (name.isEmpty || name.length > 20 || name.contains('-')) {
      name = canonicalNameForCode(code);
    }

    return Prayer(
      id: row['id'] as String,
      userId: (row['user_id'] as String?) ?? '',
      prayerCode: code,
      name: name,
      icon: (row['icon'] as String?) ?? code,
      time: (row['time'] as String?) ?? '',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 1,
      isDone: done,
      createdAt: (row['created_at'] as String?) ?? '',
      updatedAt: (row['updated_at'] as String?) ?? '',
    );
  }

  Prayer copyWith({
    String? id,
    String? userId,
    String? prayerCode,
    String? name,
    String? icon,
    String? time,
    int? sortOrder,
    bool? isDone,
    String? createdAt,
    String? updatedAt,
  }) {
    return Prayer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      prayerCode: prayerCode ?? this.prayerCode,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      time: time ?? this.time,
      sortOrder: sortOrder ?? this.sortOrder,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String canonicalNameForCode(String code) {
    switch (code.toLowerCase().trim()) {
      case 'fajr':
        return 'Fajr';
      case 'dhuhr':
        return 'Dhuhr';
      case 'asr':
        return 'Asr';
      case 'maghrib':
        return 'Maghrib';
      case 'isha':
        return 'Isha';
      default:
        return code.isNotEmpty ? '${code[0].toUpperCase()}${code.substring(1)}' : 'Prayer';
    }
  }

  static String arabicNameForCode(String code) {
    switch (code.toLowerCase().trim()) {
      case 'fajr':
        return 'الفجر';
      case 'dhuhr':
        return 'الظهر';
      case 'asr':
        return 'العصر';
      case 'maghrib':
        return 'المغرب';
      case 'isha':
        return 'العشاء';
      default:
        return canonicalNameForCode(code);
    }
  }
}

/// Representation of a single calculated daily Islamic prayer
class PrayerItem {
  final String id;
  final String name;
  final String icon;
  final int sortOrder;
  final DateTime time;
  final String formattedTime;

  const PrayerItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.sortOrder,
    required this.time,
    required this.formattedTime,
  });
}

/// Dart 3 Record typedef for high-performance prayer telemetry without allocations
typedef NextPrayerTelemetry = ({
  Prayer nextPrayer,
  String countdownText,
  bool isDueNow,
  double progress,
  Duration timeRemaining,
});

