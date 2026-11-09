import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/common/cyber_search_bar.dart';

void main() {
  group('CyberSearchBar Tests', () {
    testWidgets('renders hint text and prefix icon', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CyberSearchBar(
                controller: controller,
                hintText: 'Search habits...',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Search habits...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('entering text reveals clear button and triggers onChanged', (tester) async {
      final controller = TextEditingController();
      String query = '';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CyberSearchBar(
                controller: controller,
                hintText: 'Search tasks...',
                onChanged: (val) => query = val,
                onClear: () => query = '',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'workout');
      await tester.pump();

      expect(query, equals('workout'));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(query, isEmpty);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}

