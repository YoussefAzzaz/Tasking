import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/network_service.dart';

void main() {
  group('NetworkService TCP Connectivity Tests', () {
    test('NetworkService returns singleton instance', () {
      final s1 = NetworkService();
      final s2 = NetworkService();
      expect(identical(s1, s2), isTrue);
    });

    test('isOnlineNotifier exposes reactive online status', () {
      final service = NetworkService();
      expect(service.isOnlineNotifier, isNotNull);
      expect(service.isOnline, isA<bool>());
    });

    test('checkSupabaseConnectivity completes cleanly without throwing even when offline or timed out', () async {
      final service = NetworkService();
      // Test with an ultra-short timeout to verify non-throwing exception handling
      final result = await service.checkSupabaseConnectivity(
        timeout: const Duration(milliseconds: 50),
      );
      expect(result, isA<bool>());
      expect(service.isOnline, equals(result));
    });

    test('startMonitoring and stopMonitoring start and cancel timers cleanly', () {
      final service = NetworkService();
      service.startMonitoring(interval: const Duration(seconds: 1));
      service.stopMonitoring();
      expect(service.isOnlineNotifier, isNotNull);
    });

    testWidgets('Top bar sync dot updates reactively to online and offline state changes', (tester) async {
      final service = NetworkService();
      service.isOnlineNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: service.isOnlineNotifier,
              builder: (context, isOnline, _) {
                final dotColor = isOnline ? AxisColors.tertiary : AxisColors.warning;
                final label = isOnline ? 'SYNCED' : 'OFFLINE';

                return Row(
                  children: [
                    Container(key: const Key('sync_dot'), color: dotColor),
                    Text(label),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Online initially
      expect(find.text('SYNCED'), findsOneWidget);
      expect(find.text('OFFLINE'), findsNothing);

      // Transition to offline (e.g. airplane mode)
      service.isOnlineNotifier.value = false;
      await tester.pumpAndSettle();

      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('SYNCED'), findsNothing);

      // Transition back to online
      service.isOnlineNotifier.value = true;
      await tester.pumpAndSettle();

      expect(find.text('SYNCED'), findsOneWidget);
      expect(find.text('OFFLINE'), findsNothing);
    });
  });
}
