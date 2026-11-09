import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/category_filter_slider.dart';

void main() {
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
                  onSelected: (id) => setState(() => selectedId = id),
                ),
              );
            },
          ),
        ),
      );

      // Verify all items are rendered
      expect(find.text('All Habits'), findsOneWidget);
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);

      // Verify counts
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Tap 'Fitness'
      await tester.tap(find.text('Fitness'));
      await tester.pumpAndSettle();

      expect(selectedId, equals('fitness'));
    });
  });
}
