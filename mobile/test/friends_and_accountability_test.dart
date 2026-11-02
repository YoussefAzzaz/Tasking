import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/desktop/shell/desktop_sidebar.dart';

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

      // Verify "Companions" label is rendered
      expect(find.text('Companions'), findsOneWidget);
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);

      // Tap the Companions navigation item
      await tester.tap(find.text('Companions'));
      await tester.pump();

      expect(selectedTab, equals(5));
    });
  });
}

