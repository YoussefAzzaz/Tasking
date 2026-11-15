import 'dart:convert';

bool parseToBool(dynamic val) {
  if (val == null) return false;
  if (val is bool) return val;
  if (val is num) return val.toInt() == 1;
  if (val is String) {
    final s = val.trim().toLowerCase();
    return s == '1' || s == 'true';
  }
  return false;
}

int parseToInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

/// Data model representing a connected friend or incoming friend request.
class FriendUser {
  final String id;
  final String userId;
  final String name;
  final String title;
  final String avatarColor;
  final String? avatarUrl;
  final int totalXp;
  final int level;
  final String? friendCode;
  final String friendshipId;
  final String status;
  final bool isRequester;

  const FriendUser({
    required this.id,
    required this.userId,
    required this.name,
    this.title = 'Specialist',
    this.avatarColor = '#6366F1',
    this.avatarUrl,
    this.totalXp = 0,
    this.level = 1,
    this.friendCode,
    required this.friendshipId,
    this.status = 'accepted',
    this.isRequester = false,
  });

  FriendUser copyWith({
    String? id,
    String? userId,
    String? name,
    String? title,
    String? avatarColor,
    String? avatarUrl,
    int? totalXp,
    int? level,
    String? friendCode,
    String? friendshipId,
    String? status,
    bool? isRequester,
  }) {
    return FriendUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      title: title ?? this.title,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      friendCode: friendCode ?? this.friendCode,
      friendshipId: friendshipId ?? this.friendshipId,
      status: status ?? this.status,
      isRequester: isRequester ?? this.isRequester,
    );
  }

  factory FriendUser.fromRow(Map<String, dynamic> row, String currentUid) {
    final reqId = row['requester_id']?.toString() ?? '';
    final addId = row['addressee_id']?.toString() ?? '';
    final isReq = reqId == currentUid;
    final companionUid = (reqId == currentUid)
        ? addId
        : (addId == currentUid ? reqId : (row['user_id']?.toString() ?? (isReq ? addId : reqId)));
    return FriendUser(
      id: row['profile_id']?.toString() ?? row['friendship_id']?.toString() ?? '',
      userId: companionUid.isNotEmpty ? companionUid : (isReq ? addId : reqId),
      name: (row['name']?.toString() ?? '').trim().isNotEmpty ? row['name'].toString() : 'Companion',
      title: row['title']?.toString() ?? 'Specialist',
      avatarColor: row['avatar_color']?.toString() ?? '#6366F1',
      avatarUrl: row['avatar_url']?.toString(),
      totalXp: parseToInt(row['total_xp']),
      level: parseToInt(row['level'], 1),
      friendCode: row['friend_code']?.toString(),
      friendshipId: row['friendship_id']?.toString() ?? '',
      status: row['status']?.toString() ?? 'accepted',
      isRequester: isReq,
    );
  }
}

/// Data model for today's 5 prayers and habit progress for a user.
class DailyPrayerStatus {
  final String id;
  final String userId;
  final String userName;
  final String userAvatarColor;
  final String? userAvatarUrl;
  final String date;
  final bool fajr;
  final bool dhuhr;
  final bool asr;
  final bool maghrib;
  final bool isha;
  final int streakDays;
  final int habitsDone;
  final int habitsTotal;
  final int level;
  final String? updatedAt;

  const DailyPrayerStatus({
    required this.id,
    required this.userId,
    this.userName = 'Companion',
    this.userAvatarColor = '#6366F1',
    this.userAvatarUrl,
    required this.date,
    this.fajr = false,
    this.dhuhr = false,
    this.asr = false,
    this.maghrib = false,
    this.isha = false,
    this.streakDays = 0,
    this.habitsDone = 0,
    this.habitsTotal = 0,
    this.level = 1,
    this.updatedAt,
  });

  DailyPrayerStatus copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarColor,
    String? userAvatarUrl,
    String? date,
    bool? fajr,
    bool? dhuhr,
    bool? asr,
    bool? maghrib,
    bool? isha,
    int? streakDays,
    int? habitsDone,
    int? habitsTotal,
    int? level,
    String? updatedAt,
  }) {
    return DailyPrayerStatus(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarColor: userAvatarColor ?? this.userAvatarColor,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      date: date ?? this.date,
      fajr: fajr ?? this.fajr,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      streakDays: streakDays ?? this.streakDays,
      habitsDone: habitsDone ?? this.habitsDone,
      habitsTotal: habitsTotal ?? this.habitsTotal,
      level: level ?? this.level,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get completedCount =>
      (fajr ? 1 : 0) + (dhuhr ? 1 : 0) + (asr ? 1 : 0) + (maghrib ? 1 : 0) + (isha ? 1 : 0);

  bool isPrayerDone(String prayerCode) {
    switch (prayerCode.toLowerCase()) {
      case 'fajr':
        return fajr;
      case 'dhuhr':
        return dhuhr;
      case 'asr':
        return asr;
      case 'maghrib':
        return maghrib;
      case 'isha':
        return isha;
      default:
        return false;
    }
  }

  factory DailyPrayerStatus.fromRow(Map<String, dynamic> row) {
    return DailyPrayerStatus(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      userName: row['user_name']?.toString() ?? 'Companion',
      userAvatarColor: row['avatar_color']?.toString() ?? '#6366F1',
      userAvatarUrl: row['avatar_url']?.toString(),
      date: row['date']?.toString() ?? '',
      fajr: parseToBool(row['fajr']),
      dhuhr: parseToBool(row['dhuhr']),
      asr: parseToBool(row['asr']),
      maghrib: parseToBool(row['maghrib']),
      isha: parseToBool(row['isha']),
      streakDays: parseToInt(row['streak_days']),
      habitsDone: parseToInt(row['habits_done']),
      habitsTotal: parseToInt(row['habits_total']),
      level: parseToInt(row['level'], 1),
      updatedAt: row['updated_at']?.toString(),
    );
  }
}

/// Lightweight activity event to inspire mutual consistency and notify users.
class FriendActivityLog {
  final String id;
  final String userId;
  final String userName;
  final String userAvatarColor;
  final String eventType;
  final String title;
  final Map<String, dynamic> metadata;
  final String createdAt;

  const FriendActivityLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatarColor,
    required this.eventType,
    required this.title,
    this.metadata = const {},
    required this.createdAt,
  });

  bool get isFriendRequest => eventType == 'friend_request';
  bool get isRequestAccepted => eventType == 'request_accepted';
  bool get isRequestDeclined => eventType == 'request_declined';
  bool get isPrayerReminder => eventType == 'prayer_reminder' || eventType == 'nudge';
  bool get isSharedItemDeclined => eventType == 'shared_item_declined';
  bool get isCollaborativeTaskDeleted =>
      eventType == 'collaborative_task_deleted';
  bool get isSharedItem =>
      eventType == 'shared_item_sent' ||
      eventType == 'shared_item_accepted' ||
      eventType == 'shared_item_declined' ||
      eventType == 'collaborative_task_completed' ||
      eventType == 'collaborative_task_deleted';

  factory FriendActivityLog.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> meta = {};
    if (row['metadata'] != null) {
      if (row['metadata'] is Map) {
        meta = Map<String, dynamic>.from(row['metadata'] as Map);
      } else if (row['metadata'] is String) {
        try {
          meta = Map<String, dynamic>.from(jsonDecode(row['metadata'] as String));
        } catch (_) {}
      }
    }

    return FriendActivityLog(
      id: (row['id'] as String?) ?? '',
      userId: (row['user_id'] as String?) ?? '',
      userName: (row['user_name'] as String?) ?? (row['sender_name'] as String?) ?? 'Companion',
      userAvatarColor: (row['avatar_color'] as String?) ?? (row['sender_avatar_color'] as String?) ?? '#6366F1',
      eventType: (row['event_type'] as String?) ?? 'prayer_reminder',
      title: (row['title'] as String?) ?? '',
      metadata: meta,
      createdAt: (row['created_at'] as String?) ?? '',
    );
  }
}
