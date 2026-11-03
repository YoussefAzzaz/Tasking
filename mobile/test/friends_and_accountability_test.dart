import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/desktop/shell/desktop_sidebar.dart';
import 'package:axis/core/l10n/app_localizations.dart';

void main() {
  group('DailyPrayerStatus model tests', () {
    test('completedCount calculates correct number of done prayers', () {
      const status = DailyPrayerStatus(
        id: 'prs_user1_2026-11-02',
        userId: 'user1',
        userName: 'Omar',
        date: '2026-11-02',
        fajr: true,
        dhuhr: true,
        asr: true,
        maghrib: false,
        isha: false,
        streakDays: 14,
        habitsDone: 3,
        habitsTotal: 4,
      );

      expect(status.completedCount, equals(3));
      expect(status.isPrayerDone('fajr'), isTrue);
      expect(status.isPrayerDone('dhuhr'), isTrue);
      expect(status.isPrayerDone('asr'), isTrue);
      expect(status.isPrayerDone('maghrib'), isFalse);
      expect(status.isPrayerDone('isha'), isFalse);
    });

    test('DailyPrayerStatus fromRow parses boolean flags and streak correctly', () {
      final row = {
        'id': 'prs_user2_2026-11-02',
        'user_id': 'user2',
        'user_name': 'Sarah',
        'avatar_color': '#10B981',
        'date': '2026-11-02',
        'fajr': 1,
        'dhuhr': 1,
        'asr': 0,
        'maghrib': 0,
        'isha': 0,
        'streak_days': 7,
        'habits_done': 2,
        'habits_total': 3,
      };

      final status = DailyPrayerStatus.fromRow(row);
      expect(status.id, equals('prs_user2_2026-11-02'));
      expect(status.userId, equals('user2'));
      expect(status.userName, equals('Sarah'));
      expect(status.completedCount, equals(2));
      expect(status.streakDays, equals(7));
      expect(status.habitsDone, equals(2));
      expect(status.habitsTotal, equals(3));
    });
  });

  group('FriendUser model tests', () {
    test('FriendUser fromRow assigns isRequester properly', () {
      final row = {
        'friendship_id': 'f_1',
        'requester_id': 'me_user',
        'addressee_id': 'friend_user',
        'status': 'accepted',
        'profile_id': 'prof_1',
        'name': 'Ahmad',
        'title': 'Strategist',
        'total_xp': 1200,
        'level': 4,
        'friend_code': 'AX-1234',
      };

      final friend = FriendUser.fromRow(row, 'me_user');
      expect(friend.name, equals('Ahmad'));
      expect(friend.isRequester, isTrue);
      expect(friend.totalXp, equals(1200));
      expect(friend.friendCode, equals('AX-1234'));
    });

    test('FriendUser copyWith preserves and updates fields correctly', () {
      const friend = FriendUser(
        id: 'prof_1',
        userId: 'u_1',
        name: 'Zaid',
        friendshipId: 'f_1',
        status: 'none',
      );

      final updated = friend.copyWith(status: 'pending', level: 5);
      expect(updated.name, equals('Zaid'));
      expect(updated.status, equals('pending'));
      expect(updated.level, equals(5));
      expect(updated.friendshipId, equals('f_1'));
    });
  });

  group('FriendActivityLog model tests', () {
    test('fromRow parses prayer reminders, request acceptances and declination', () {
      final prayerRow = {
        'id': 'log_1',
        'user_id': 'u_target',
        'event_type': 'prayer_reminder',
        'title': 'Ali reminded you to pray Asr 🕌',
        'metadata': '{"sender_id":"u_ali","sender_name":"Ali","prayer_name":"Asr"}',
        'created_at': '2026-11-03T16:00:00Z',
      };

      final prayerLog = FriendActivityLog.fromRow(prayerRow);
      expect(prayerLog.isPrayerReminder, isTrue);
      expect(prayerLog.isFriendRequest, isFalse);
      expect(prayerLog.metadata['prayer_name'], equals('Asr'));
      expect(prayerLog.metadata['sender_name'], equals('Ali'));

      final acceptRow = {
        'id': 'log_2',
        'user_id': 'u_req',
        'event_type': 'request_accepted',
        'title': 'Sara accepted your companion request! 🎉',
        'created_at': '2026-11-03T16:05:00Z',
      };
      final acceptLog = FriendActivityLog.fromRow(acceptRow);
      expect(acceptLog.isRequestAccepted, isTrue);
      expect(acceptLog.isPrayerReminder, isFalse);

      final declineRow = {
        'id': 'log_3',
        'user_id': 'u_req',
        'event_type': 'request_declined',
        'title': 'Omar declined your companion request',
        'created_at': '2026-11-03T16:10:00Z',
      };
      final declineLog = FriendActivityLog.fromRow(declineRow);
      expect(declineLog.isRequestDeclined, isTrue);
    });
  });

  group('Companions Localization Tests', () {
    test('AppLocalizations provides localized companion strings in Arabic and English', () {
      final ar = AppLocalizations(const Locale('ar'));
      final en = AppLocalizations(const Locale('en'));

      expect(ar.candidateFound, equals('تم العثور على رفيق'));
      expect(en.candidateFound, equals('Companion Found'));

      expect(ar.refuse, equals('رفض'));
      expect(en.refuse, equals('Refuse'));

      expect(ar.friendNotifications, equals('إشعارات الرفاق والتذكيرات'));
      expect(en.friendNotifications, equals('Companion Reminders & Activity'));

      expect(ar.sendRequestTo('علي'), equals('إرسال طلب إلى علي'));
      expect(en.sendRequestTo('Ali'), equals('Send Request to Ali'));
    });
  });

  group('Desktop Sidebar Companions Navigation Tests', () {
    testWidgets('DesktopSidebar includes Companions item at index 5', (tester) async {
      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSidebar(
              selectedTab: selectedTab,
              onSelectTab: (tab) => selectedTab = tab,
              onNewTask: () {},
            ),
          ),
        ),
      );

      // Verify "Companions" / "الرفاق" label is rendered
      final companionsFinder = find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data == 'Companions' || widget.data == 'الرفاق'),
      );
      expect(companionsFinder, findsOneWidget);
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);

      // Tap the Companions navigation item
      await tester.tap(companionsFinder);
      await tester.pump();

      expect(selectedTab, equals(5));
    });
  });
}
