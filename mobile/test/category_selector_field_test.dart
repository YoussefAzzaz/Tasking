import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';

void main() {
  group('CategorySelectorField Custom Categories Isolation Tests', () {
    testWidgets('CategorySelectorField shows empty prompt when no habit categories exist',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      bool isOpen = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CategorySelectorField(
                  controller: controller,
                  focusNode: focusNode,
                  categories: const [],
                  isOpen: isOpen,
                  onOpenChanged: (val) => setState(() => isOpen = val),
                  onSelectCategory: (name, icon, color) => setState(() => controller.text = name),
                  onClear: () => setState(() => controller.clear()),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No custom categories yet. Type above to create one.'), findsOneWidget);

      expect(find.text('Workout'), findsNothing);
      expect(find.text('Reading'), findsNothing);
      expect(find.text('Mindful'), findsNothing);
      expect(find.text('Hydrate'), findsNothing);
      expect(find.text('Code'), findsNothing);
      expect(find.text('Rest'), findsNothing);
    });

    testWidgets('CategorySelectorField displays only user-created custom categories',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      bool isOpen = true;

      const categories = [
        HabitCategory(id: 'cat_workout', name: 'Workout'), // legacy default
        HabitCategory(id: 'cat_deepwork', name: 'Deep Work', icon: 'code', color: '#6366F1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CategorySelectorField(
                  controller: controller,
                  focusNode: focusNode,
                  categories: categories,
                  isOpen: isOpen,
                  onOpenChanged: (val) => setState(() => isOpen = val),
                  onSelectCategory: (name, icon, color) => setState(() => controller.text = name),
                  onClear: () => setState(() => controller.clear()),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Deep Work'), findsOneWidget);
      expect(find.text('Workout'), findsNothing);
    });

    testWidgets('CategorySelectorField shows all user categories even when editing a habit with pre-selected category',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Deep Work');
      final focusNode = FocusNode();
      bool isOpen = true;

      const categories = [
        HabitCategory(id: 'cat_deepwork', name: 'Deep Work', icon: 'code', color: '#6366F1'),
        HabitCategory(id: 'cat_fitness_routine', name: 'Fitness Routine', icon: 'fitness', color: '#10B981'),
        HabitCategory(id: 'cat_meditation', name: 'Mindfulness', icon: 'meditation', color: '#A855F7'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CategorySelectorField(
                  controller: controller,
                  focusNode: focusNode,
                  categories: categories,
                  isOpen: isOpen,
                  onOpenChanged: (val) => setState(() => isOpen = val),
                  onSelectCategory: (name, icon, color) => setState(() => controller.text = name),
                  onClear: () => setState(() => controller.clear()),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Deep Work'), findsNWidgets(2));
      expect(find.text('Fitness Routine'), findsOneWidget);
      expect(find.text('Mindfulness'), findsOneWidget);
    });

    testWidgets('Multiple custom categories do not replace each other and persist simultaneously',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      bool isOpen = true;

      final categoriesList = <HabitCategory>[
        const HabitCategory(id: 'cat_u1_fitness', name: 'Fitness', icon: 'fitness', color: '#10B981'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          categoriesList.add(const HabitCategory(
                            id: 'cat_u1_study',
                            name: 'Study',
                            icon: 'fitness',
                            color: '#38BDF8',
                          ));
                        });
                      },
                      child: const Text('Add Second Category'),
                    ),
                    CategorySelectorField(
                      controller: controller,
                      focusNode: focusNode,
                      categories: categoriesList,
                      isOpen: isOpen,
                      onOpenChanged: (val) => setState(() => isOpen = val),
                      onSelectCategory: (name, icon, color) => setState(() => controller.text = name),
                      onClear: () => setState(() => controller.clear()),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Study'), findsNothing);

      await tester.tap(find.text('Add Second Category'));
      await tester.pumpAndSettle();

      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
    });
  });
}

