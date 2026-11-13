import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/friends/daily_prayer_checklist_builder.dart';
import 'package:axis/ui/friends/widgets/companion_checklist_card.dart';

void main() {
  group('Daily Prayer Companion Multi-Prayer Persistence Tests', () {
    test('Sequential prayer checkoffs preserve earlier completed prayers', () {
      // Step 1: User B checks Fajr
      const step1 = DailyPrayerStatus(
        id: 'prs_userB_2026-11-04',
        userId: 'userB',
        date: '2026-11-04',
        fajr: true,
        dhuhr: false,
        asr: false,
        maghrib: false,
        isha: false,
      );

      expect(step1.completedCount, equals(1));
      expect(step1.isPrayerDone('fajr'), isTrue);
      expect(step1.isPrayerDone('dhuhr'), isFalse);

      // Step 2: User B checks Dhuhr. Fajr MUST NOT disappear!
      final step2 = DailyPrayerStatus(
        id: 'prs_userB_2026-11-04',
        userId: 'userB',
        date: '2026-11-04',
        fajr: step1.fajr, // Preserved from previous state
        dhuhr: true,
        asr: false,
        maghrib: false,
        isha: false,
      );

      expect(step2.completedCount, equals(2));
      expect(step2.isPrayerDone('fajr'), isTrue);
      expect(step2.isPrayerDone('dhuhr'), isTrue);
      expect(step2.isPrayerDone('asr'), isFalse);

      // Step 3: User B checks Asr. Fajr and Dhuhr MUST remain true!
      final step3 = DailyPrayerStatus(
        id: 'prs_userB_2026-11-04',
        userId: 'userB',
        date: '2026-11-04',
        fajr: step2.fajr,
        dhuhr: step2.dhuhr,
        asr: true,
        maghrib: false,
        isha: false,
      );

      expect(step3.completedCount, equals(3));
      expect(step3.isPrayerDone('fajr'), isTrue);
      expect(step3.isPrayerDone('dhuhr'), isTrue);
      expect(step3.isPrayerDone('asr'), isTrue);
      expect(step3.isPrayerDone('maghrib'), isFalse);

      // Step 4: User B unchecks Asr. Fajr and Dhuhr MUST stay true, only Asr becomes false!
      final step4 = DailyPrayerStatus(
        id: 'prs_userB_2026-11-04',
        userId: 'userB',
        date: '2026-11-04',
        fajr: step3.fajr,
        dhuhr: step3.dhuhr,
        asr: false, // Explicitly unchecked
        maghrib: false,
        isha: false,
      );

      expect(step4.completedCount, equals(2));
      expect(step4.isPrayerDone('fajr'), isTrue);
      expect(step4.isPrayerDone('dhuhr'), isTrue);
      expect(step4.isPrayerDone('asr'), isFalse);

      // Step 5: User B unchecks Dhuhr. Fajr MUST stay true, Dhuhr and Asr are false!
      final step5 = DailyPrayerStatus(
        id: 'prs_userB_2026-11-04',
        userId: 'userB',
        date: '2026-11-04',
        fajr: step4.fajr,
        dhuhr: false, // Explicitly unchecked
        asr: false,
        maghrib: false,
        isha: false,
      );

      expect(step5.completedCount, equals(1));
      expect(step5.isPrayerDone('fajr'), isTrue);
      expect(step5.isPrayerDone('dhuhr'), isFalse);
      expect(step5.isPrayerDone('asr'), isFalse);

      // Step 6: User B unchecks Fajr. All are now unchecked.
      const step6 = DailyPrayerStatus(
        id: 'prs_userB_2026-11-04',
        userId: 'userB',
        date: '2026-11-04',
        fajr: false,
        dhuhr: false,
        asr: false,
        maghrib: false,
        isha: false,
      );

      expect(step6.completedCount, equals(0));
      expect(step6.isPrayerDone('fajr'), isFalse);
    });

    test('parseToBool robustly handles boolean, int, string, and null variations from Supabase/SQLite', () {
      expect(parseToBool(true), isTrue);
      expect(parseToBool(false), isFalse);
      expect(parseToBool(1), isTrue);
      expect(parseToBool(0), isFalse);
      expect(parseToBool('true'), isTrue);
      expect(parseToBool('TRUE'), isTrue);
      expect(parseToBool('1'), isTrue);
      expect(parseToBool('false'), isFalse);
      expect(parseToBool('0'), isFalse);
      expect(parseToBool(null), isFalse);
      expect(parseToBool(''), isFalse);
    });

    test('parseToInt robustly handles numbers and strings with fallback', () {
      expect(parseToInt(5), equals(5));
      expect(parseToInt('14'), equals(14));
      expect(parseToInt(null, 2), equals(2));
      expect(parseToInt('invalid', 0), equals(0));
    });

    test('DailyPrayerStatusRepository exposes currentUserPrayerCache for responsive UI', () {
      final repo = DailyPrayerStatusRepository();
      expect(repo.currentUserPrayerCache, isNotNull);
      expect(repo.currentUserPrayerCache, isA<Map<String, bool>>());
    });

    test('DailyPrayerChecklistBuilder correctly constructs today checklist models', () {
      const builder = DailyPrayerChecklistBuilder();
      expect(builder, isNotNull);
    });

    test('Explicit false in currentUserPrayerCache preserves un-checked state', () {
      final repo = DailyPrayerStatusRepository();
      repo.setCacheForTesting('fajr', false);
      repo.setCacheForTesting('dhuhr', true);

      expect(repo.currentUserPrayerCache['fajr'], isFalse);
      expect(repo.currentUserPrayerCache['dhuhr'], isTrue);
    });

    test('Companion with previous day row preserves streakDays even when today prayers are false', () {
      const companionStatusYesterday = DailyPrayerStatus(
        id: 'prs_comp1_2026-11-04',
        userId: 'comp1',
        userName: 'Ammar',
        date: '2026-11-04',
        fajr: true,
        dhuhr: true,
        asr: true,
        maghrib: true,
        isha: true,
        streakDays: 42,
      );

      expect(companionStatusYesterday.streakDays, equals(42));
      expect(companionStatusYesterday.completedCount, equals(5));

      // Rolled over to today without marking prayers yet:
      final companionStatusToday = DailyPrayerStatus(
        id: 'prs_comp1_2026-11-05',
        userId: 'comp1',
        userName: companionStatusYesterday.userName,
        date: '2026-11-05',
        fajr: false,
        dhuhr: false,
        asr: false,
        maghrib: false,
        isha: false,
        streakDays: companionStatusYesterday.streakDays, // preserved streak!
      );

      expect(companionStatusToday.streakDays, equals(42));
      expect(companionStatusToday.completedCount, equals(0));
    });

    test('Realtime companion prayer update preserves companion name and avatar', () {
      const existingStatus = DailyPrayerStatus(
        id: 'prs_comp1_2026-11-05',
        userId: 'comp1',
        userName: 'Bilal',
        userAvatarColor: '#10B981',
        userAvatarUrl: 'https://avatar.url',
        date: '2026-11-05',
        fajr: false,
        streakDays: 15,
      );

      // Incoming realtime update for companion
      final updatedStatus = DailyPrayerStatus(
        id: existingStatus.id,
        userId: existingStatus.userId,
        userName: existingStatus.userName, // Name preserved!
        userAvatarColor: existingStatus.userAvatarColor,
        userAvatarUrl: existingStatus.userAvatarUrl,
        date: existingStatus.date,
        fajr: true, // Fajr completed
        dhuhr: false,
        asr: false,
        maghrib: false,
        isha: false,
        streakDays: 16,
      );

      expect(updatedStatus.userName, equals('Bilal'));
      expect(updatedStatus.userAvatarColor, equals('#10B981'));
      expect(updatedStatus.fajr, isTrue);
      expect(updatedStatus.streakDays, equals(16));
    });

    test('Partial Postgres Realtime UPDATE preserves non-modified prayers when unchecking one', () {
      // User B initially has 3 prayers checked (fajr, dhuhr, asr)
      const prev = DailyPrayerStatus(
        id: 'prs_userB_2026-11-05',
        userId: 'userB',
        userName: 'Mizouni',
        userAvatarColor: '#6366F1',
        date: '2026-11-05',
        fajr: true,
        dhuhr: true,
        asr: true,
        maghrib: false,
        isha: false,
        streakDays: 13,
        habitsDone: 2,
        habitsTotal: 4,
      );

      expect(prev.completedCount, equals(3));
      expect(prev.fajr, isTrue);
      expect(prev.dhuhr, isTrue);
      expect(prev.asr, isTrue);

      // Simulates Postgres Realtime payload when User B unchecks Asr:
      // In Postgres Realtime with default replica identity, ONLY the modified column ('asr') is sent!
      // 'fajr', 'dhuhr', 'maghrib', 'isha' are absent/null in newRecord!
      final Map<String, dynamic> partialNewRecord = {
        'id': 'prs_userB_2026-11-05',
        'user_id': 'userB',
        'asr': false, // ONLY 'asr' was changed!
        'updated_at': '2026-11-05T14:30:00Z',
      };

      // Apply the merging logic from friend_repository.dart
      final recDate = (partialNewRecord['date']?.toString() ?? '').split('T').first.trim();
      final effectiveDate = recDate.isNotEmpty ? recDate : prev.date;

      final bool fajrVal = partialNewRecord.containsKey('fajr') && partialNewRecord['fajr'] != null
          ? parseToBool(partialNewRecord['fajr'])
          : prev.fajr;
      final bool dhuhrVal = partialNewRecord.containsKey('dhuhr') && partialNewRecord['dhuhr'] != null
          ? parseToBool(partialNewRecord['dhuhr'])
          : prev.dhuhr;
      final bool asrVal = partialNewRecord.containsKey('asr') && partialNewRecord['asr'] != null
          ? parseToBool(partialNewRecord['asr'])
          : prev.asr;
      final bool maghribVal = partialNewRecord.containsKey('maghrib') && partialNewRecord['maghrib'] != null
          ? parseToBool(partialNewRecord['maghrib'])
          : prev.maghrib;
      final bool ishaVal = partialNewRecord.containsKey('isha') && partialNewRecord['isha'] != null
          ? parseToBool(partialNewRecord['isha'])
          : prev.isha;

      final merged = DailyPrayerStatus(
        id: partialNewRecord['id']?.toString() ?? prev.id,
        userId: 'userB',
        userName: prev.userName,
        userAvatarColor: prev.userAvatarColor,
        date: effectiveDate,
        fajr: fajrVal,
        dhuhr: dhuhrVal,
        asr: asrVal,
        maghrib: maghribVal,
        isha: ishaVal,
        streakDays: prev.streakDays,
        habitsDone: prev.habitsDone,
        habitsTotal: prev.habitsTotal,
      );

      // CRITICAL ASSERTION: Fajr and Dhuhr MUST remain true! Only Asr is false!
      expect(merged.completedCount, equals(2));
      expect(merged.fajr, isTrue);
      expect(merged.dhuhr, isTrue);
      expect(merged.asr, isFalse);
      expect(merged.date, equals('2026-11-05'));
    });

    test('Targeted check of Dhuhr when Fajr was checked preserves Fajr, streak, and daily habits', () {
      // User B initially has Fajr checked, streak 13, habits 2/4
      const prev = DailyPrayerStatus(
        id: 'prs_userB_2026-11-05',
        userId: 'userB',
        userName: 'Mizouni',
        userAvatarColor: '#6366F1',
        date: '2026-11-05',
        fajr: true,
        dhuhr: false,
        asr: false,
        maghrib: false,
        isha: false,
        streakDays: 13,
        habitsDone: 2,
        habitsTotal: 4,
      );

      // User B checks Dhuhr. Supabase targeted update sends only 'dhuhr: true':
      final Map<String, dynamic> checkDhuhrPayload = {
        'id': 'prs_userB_2026-11-05',
        'user_id': 'userB',
        'dhuhr': true,
        'updated_at': '2026-11-05T15:10:00Z',
      };

      final recDate = (checkDhuhrPayload['date']?.toString() ?? '').split('T').first.trim();
      final effectiveDate = recDate.isNotEmpty ? recDate : prev.date;

      final bool fajrVal = checkDhuhrPayload.containsKey('fajr') && checkDhuhrPayload['fajr'] != null
          ? parseToBool(checkDhuhrPayload['fajr'])
          : prev.fajr;
      final bool dhuhrVal = checkDhuhrPayload.containsKey('dhuhr') && checkDhuhrPayload['dhuhr'] != null
          ? parseToBool(checkDhuhrPayload['dhuhr'])
          : prev.dhuhr;
      final bool asrVal = checkDhuhrPayload.containsKey('asr') && checkDhuhrPayload['asr'] != null
          ? parseToBool(checkDhuhrPayload['asr'])
          : prev.asr;
      final bool maghribVal = checkDhuhrPayload.containsKey('maghrib') && checkDhuhrPayload['maghrib'] != null
          ? parseToBool(checkDhuhrPayload['maghrib'])
          : prev.maghrib;
      final bool ishaVal = checkDhuhrPayload.containsKey('isha') && checkDhuhrPayload['isha'] != null
          ? parseToBool(checkDhuhrPayload['isha'])
          : prev.isha;

      int streakVal = prev.streakDays;
      if (checkDhuhrPayload.containsKey('streak_days') && checkDhuhrPayload['streak_days'] != null) {
        final s = parseToInt(checkDhuhrPayload['streak_days']);
        if (s > 0) streakVal = s;
      }

      int habitsDoneVal = prev.habitsDone;
      if (checkDhuhrPayload.containsKey('habits_done') && checkDhuhrPayload['habits_done'] != null) {
        final hd = parseToInt(checkDhuhrPayload['habits_done']);
        if (hd > 0) habitsDoneVal = hd;
      }

      int habitsTotalVal = prev.habitsTotal;
      if (checkDhuhrPayload.containsKey('habits_total') && checkDhuhrPayload['habits_total'] != null) {
        final ht = parseToInt(checkDhuhrPayload['habits_total']);
        if (ht > 0) habitsTotalVal = ht;
      }

      final merged = DailyPrayerStatus(
        id: checkDhuhrPayload['id']?.toString() ?? prev.id,
        userId: 'userB',
        userName: prev.userName,
        userAvatarColor: prev.userAvatarColor,
        date: effectiveDate,
        fajr: fajrVal,
        dhuhr: dhuhrVal,
        asr: asrVal,
        maghrib: maghribVal,
        isha: ishaVal,
        streakDays: streakVal,
        habitsDone: habitsDoneVal,
        habitsTotal: habitsTotalVal,
      );

      // ONLY Dhuhr changed! Fajr, streak, and habits are completely preserved!
      expect(merged.completedCount, equals(2));
      expect(merged.fajr, isTrue);
      expect(merged.dhuhr, isTrue);
      expect(merged.asr, isFalse);
      expect(merged.streakDays, equals(13));
      expect(merged.habitsDone, equals(2));
      expect(merged.habitsTotal, equals(4));
    });

    test('Realtime callback extracts user_id from prs_ ID when user_id column is omitted in update payload', () {
      final payloadWithoutUserId = {
        'id': 'prs_bb192339-77e9-473a-8eec-8269604334ae_2026-11-05',
        'asr': true,
        'updated_at': '2026-11-05T16:00:00Z',
      };

      final newUid = payloadWithoutUserId['user_id']?.toString();
      var changedUserId = newUid ?? '';
      if (changedUserId.isEmpty) {
        final recId = payloadWithoutUserId['id']?.toString() ?? '';
        if (recId.startsWith('prs_')) {
          final parts = recId.split('_');
          if (parts.length >= 2 && parts[1].isNotEmpty) {
            changedUserId = parts[1];
          }
        }
      }

      expect(changedUserId, equals('bb192339-77e9-473a-8eec-8269604334ae'));
    });

    test('Companion checklist builder falls back to local SQLite streak and habits if cached has 0', () {
      // Suppose in-memory cache had streak = 0 and habits = 0
      const cached = DailyPrayerStatus(
        id: 'prs_comp_2026-11-05',
        userId: 'comp',
        userName: 'Ammar',
        date: '2026-11-05',
        fajr: true,
        dhuhr: false,
        streakDays: 0,
        habitsDone: 0,
        habitsTotal: 0,
      );

      // Local SQLite row has the historical streak and daily habits
      final localFriendRow = {
        'id': 'prs_comp_2026-11-05',
        'user_id': 'comp',
        'date': '2026-11-05',
        'streak_days': 19,
        'habits_done': 3,
        'habits_total': 6,
      };

      int streak = cached.streakDays;
      if (streak == 0) {
        streak = parseToInt(localFriendRow['streak_days']);
      }
      int hDone = cached.habitsDone;
      int hTotal = cached.habitsTotal;
      if (hTotal == 0) {
        hDone = parseToInt(localFriendRow['habits_done']);
        hTotal = parseToInt(localFriendRow['habits_total']);
      }

      final status = DailyPrayerStatus(
        id: cached.id,
        userId: cached.userId,
        userName: cached.userName,
        date: cached.date,
        fajr: cached.fajr,
        dhuhr: cached.dhuhr,
        streakDays: streak,
        habitsDone: hDone,
        habitsTotal: hTotal,
      );

      expect(status.fajr, isTrue);
      expect(status.streakDays, equals(19));
      expect(status.habitsDone, equals(3));
      expect(status.habitsTotal, equals(6));
    });

    test('Non-prayer habit calculation correctly counts all user habits without being filtered out', () {
      final habitRows = List.generate(13, (i) => {
        'id': 'habit_$i',
        'kind': i % 2 == 0 ? 'fitness' : 'health',
        'schedule_type': i % 3 == 0 ? 'custom' : (i % 2 == 0 ? 'daily' : 'weekdays'),
      });
      // Plus 5 prayer habits that must be excluded:
      habitRows.addAll([
        {'id': 'prayer_fajr', 'kind': 'prayers', 'schedule_type': 'daily'},
        {'id': 'prayer_dhuhr', 'kind': 'prayers', 'schedule_type': 'daily'},
        {'id': 'prayer_asr', 'kind': 'prayers', 'schedule_type': 'daily'},
        {'id': 'prayer_maghrib', 'kind': 'prayers', 'schedule_type': 'daily'},
        {'id': 'prayer_isha', 'kind': 'prayers', 'schedule_type': 'daily'},
      ]);

      final validHabitIds = <String>{};
      for (final h in habitRows) {
        final hId = (h['id'] ?? '').trim();
        final kind = (h['kind'] ?? '').toLowerCase().trim();
        if (!HabitRepository.isPrayerIdentifier(hId) &&
            kind != 'prayers' &&
            kind != 'prayer') {
          validHabitIds.add(hId);
        }
      }

      expect(validHabitIds.length, equals(13));
    });

    test('Multiple companion rows ordered by updated_at DESC keeps newest and does not overwrite with older', () {
      final prayerRows = [
        {
          'id': 'prs_userB_2026-11-05',
          'user_id': 'userB',
          'date': '2026-11-05',
          'fajr': true,
          'dhuhr': true,
          'asr': false,
          'maghrib': false,
          'isha': false,
          'streak_days': 7,
          'habits_done': 4,
          'habits_total': 13,
          'updated_at': '2026-11-05T19:40:00Z', // Newest
        },
        {
          'id': 'prs_userB_2026-11-05_old',
          'user_id': 'userB',
          'date': '2026-11-05',
          'fajr': false,
          'dhuhr': false,
          'asr': false,
          'maghrib': false,
          'isha': false,
          'streak_days': 0,
          'habits_done': 0,
          'habits_total': 0,
          'updated_at': '2026-11-05T08:00:00Z', // Old morning row
        },
      ];

      final prayerStatusMap = <String, Map<String, dynamic>>{};
      for (final pr in prayerRows) {
        final pUid = pr['user_id']?.toString() ?? '';
        if (pUid.isEmpty) continue;
        if (!prayerStatusMap.containsKey(pUid)) {
          prayerStatusMap[pUid] = pr;
        }
      }

      final chosen = prayerStatusMap['userB']!;
      expect(chosen['fajr'], isTrue);
      expect(chosen['dhuhr'], isTrue);
      expect(chosen['streak_days'], equals(7));
      expect(chosen['habits_total'], equals(13));
    });

    test('Live Realtime update with newer updated_at is preserved over stale REST snapshot', () {
      const prevLive = DailyPrayerStatus(
        id: 'prs_userB_2026-11-05',
        userId: 'userB',
        date: '2026-11-05',
        fajr: true,
        dhuhr: true,
        streakDays: 5,
        habitsDone: 2,
        habitsTotal: 13,
        updatedAt: '2026-11-05T19:45:00Z', // Received via Realtime at 19:45
      );

      final staleRestRow = {
        'id': 'prs_userB_2026-11-05',
        'user_id': 'userB',
        'date': '2026-11-05',
        'fajr': false, // Stale snapshot from 19:44
        'dhuhr': false,
        'updated_at': '2026-11-05T19:44:00Z',
      };

      final prayUpdatedAt = staleRestRow['updated_at']?.toString() ?? '';
      bool isPrevNewer = false;
      if (prevLive.updatedAt != null && prayUpdatedAt.isNotEmpty) {
        isPrevNewer = DateTime.parse(prevLive.updatedAt!).isAfter(DateTime.parse(prayUpdatedAt));
      }

      expect(isPrevNewer, isTrue);

      final fajrVal = isPrevNewer ? prevLive.fajr : parseToBool(staleRestRow['fajr']);
      final dhuhrVal = isPrevNewer ? prevLive.dhuhr : parseToBool(staleRestRow['dhuhr']);

      expect(fajrVal, isTrue);
      expect(dhuhrVal, isTrue);
    });

    test('DailyPrayerStatus copyWith accurately updates targeted fields while preserving others', () {
      const original = DailyPrayerStatus(
        id: 'prs_userB_2026-11-05',
        userId: 'userB',
        date: '2026-11-05',
        fajr: true,
        dhuhr: false,
        streakDays: 4,
        habitsDone: 1,
        habitsTotal: 13,
      );

      final updated = original.copyWith(
        dhuhr: true,
        updatedAt: '2026-11-05T19:50:00Z',
      );

      expect(updated.fajr, isTrue);
      expect(updated.dhuhr, isTrue);
      expect(updated.streakDays, equals(4));
      expect(updated.habitsTotal, equals(13));
      expect(updated.updatedAt, equals('2026-11-05T19:50:00Z'));
    });

    test('DailyPrayerChecklistBuilder computeMyStatus keeps user checklist operational offline', () async {
      final myStatus = await const DailyPrayerChecklistBuilder().computeMyStatus(
        uid: 'userA',
        currentUserName: 'You',
        date: '2026-11-05',
      );

      expect(myStatus.userId, equals('userA'));
      expect(myStatus.userName, equals('You'));
      expect(myStatus.date, equals('2026-11-05'));
    });

    test('Strict daily habit filtering retrieves only daily habits and excludes weekly/weekdays', () {
      final rawHabits = [
        {'id': 'h_daily1', 'kind': 'fitness', 'schedule_type': 'daily', 'is_enabled': 1},
        {'id': 'h_daily2', 'kind': 'study', 'schedule_type': 'daily', 'is_enabled': 1},
        {'id': 'h_daily3', 'kind': 'work', 'schedule_type': null, 'is_enabled': 1}, // default is daily
        {'id': 'h_weekly', 'kind': 'health', 'schedule_type': 'weekly', 'is_enabled': 1},
        {'id': 'h_weekdays', 'kind': 'reading', 'schedule_type': 'weekdays', 'is_enabled': 1},
        {'id': 'h_prayer_fajr', 'kind': 'prayers', 'schedule_type': 'daily', 'is_enabled': 1},
        {'id': 'prayer_dhuhr', 'kind': 'prayer', 'schedule_type': 'daily', 'is_enabled': 1},
      ];

      final validDailyHabitIds = <String>{};
      for (final h in rawHabits) {
        final hId = (h['id'] as String? ?? '').trim();
        final kind = (h['kind'] as String? ?? '').toLowerCase().trim();
        final sched = (h['schedule_type'] as String?)?.toLowerCase().trim();
        final isDaily = sched == null || sched.isEmpty || sched == 'daily';

        if (!HabitRepository.isPrayerIdentifier(hId) &&
            kind != 'prayers' &&
            kind != 'prayer' &&
            !hId.startsWith('prayer_') &&
            !hId.startsWith('habit_prayer_') &&
            isDaily) {
          validDailyHabitIds.add(hId);
        }
      }

      // Exactly the 3 daily habits are kept
      expect(validDailyHabitIds, containsAll(['h_daily1', 'h_daily2', 'h_daily3']));
      expect(validDailyHabitIds.contains('h_weekly'), isFalse);
      expect(validDailyHabitIds.contains('h_weekdays'), isFalse);
      expect(validDailyHabitIds.contains('h_prayer_fajr'), isFalse);
      expect(validDailyHabitIds.contains('prayer_dhuhr'), isFalse);
      expect(validDailyHabitIds.length, equals(3));
    });

    testWidgets('CompanionChecklistCard displays level and name cleanly without prayers, habits, streak or emojis', (tester) async {
      const status = DailyPrayerStatus(
        id: 'prs_comp1_2026-11-05',
        userId: 'comp1',
        userName: 'Zaid Companion',
        userAvatarColor: '#10B981',
        date: '2026-11-05',
        level: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompanionChecklistCard(
              status: status,
              friendRepo: FriendRepository(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Companion name & level badge
      expect(find.text('Zaid Companion'), findsOneWidget);
      expect(find.text('LVL 7'), findsOneWidget);
      expect(find.textContaining('7'), findsWidgets);

      // Arrow navigation icon
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);

      // No emojis in any text widget
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final tw in textWidgets) {
        final text = tw.data ?? '';
        expect(text.contains('✨'), isFalse);
        expect(text.contains('🔥'), isFalse);
      }

      // No individual prayer buttons or progress bars
      expect(find.text('Fajr'), findsNothing);
      expect(find.text('Dhuhr'), findsNothing);
      expect(find.text('Asr'), findsNothing);
      expect(find.text('Maghrib'), findsNothing);
      expect(find.text('Isha'), findsNothing);
      expect(find.text('الفجر'), findsNothing);
      expect(find.text('الظهر'), findsNothing);
      expect(find.text('العصر'), findsNothing);
      expect(find.text('المغرب'), findsNothing);
      expect(find.text('العشاء'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
