import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/category_filter_slider.dart';
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

      // Tap clear button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(query, isEmpty);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });

  group('CategoryFilterSlider Tests', () {
    testWidgets('renders all slider items with badges and handles selection', (tester) async {
      String selectedId = 'all';

      final items = [
        const CategorySliderItem(
          id: 'all',
          label: 'All Habits',
          iconData: Icons.apps_rounded,
          count: 5,
        ),
        const CategorySliderItem(
          id: 'fitness',
          label: 'Fitness',
          icon: 'fitness',
          color: AxisColors.success,
          count: 3,
        ),
        const CategorySliderItem(
          id: 'reading',
          label: 'Reading',
          icon: 'reading',
          color: AxisColors.secondary,
          count: 2,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: CategoryFilterSlider(
                  items: items,
                  selectedId: selectedId,
                  onSelected: (id) {
                    setState(() {
                      selectedId = id;
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      // Verify labels rendered
      expect(find.text('All Habits'), findsOneWidget);
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);

      // Verify count badges rendered
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Tap Fitness pill
      await tester.tap(find.text('Fitness'));
      await tester.pumpAndSettle();

      expect(selectedId, equals('fitness'));

      // Tap All Habits pill
      await tester.tap(find.text('All Habits'));
      await tester.pumpAndSettle();

      expect(selectedId, equals('all'));
    });
  });
}
