import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/ui/tasks/widgets/project_selector_field.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';

void main() {
  group('Custom Projects & Categories UI Isolation', () {
    testWidgets('ProjectSelectorField shows empty hint when no projects exist and hides default projects',
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
                return ProjectSelectorField(
                  controller: controller,
                  focusNode: focusNode,
                  selectedProject: null,
                  existingProjects: const [],
                  isOpen: isOpen,
                  onOpenChanged: (val) => setState(() => isOpen = val),
                  onSelectProject: (p) => setState(() => controller.text = p ?? ''),
                  onClear: () => setState(() => controller.clear()),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show Inbox (No Project)
      expect(find.text('Inbox (No Project)'), findsOneWidget);

      // Should show empty prompt
      expect(find.text('No custom projects yet. Type above to create one.'), findsOneWidget);

      // Must NOT show legacy default projects
      expect(find.text('Work'), findsNothing);
      expect(find.text('Personal'), findsNothing);
      expect(find.text('Growth'), findsNothing);
    });

    testWidgets('ProjectSelectorField ignores legacy default projects even if passed in existingProjects',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      bool isOpen = true;

      final mixedProjects = [
        Project(id: 'work', name: 'Work'),
        Project(id: 'personal', name: 'Personal'),
        Project(id: 'growth', name: 'Growth'),
        Project(id: 'proj_custom_1', name: 'Alpha Mobile App', color: '#6366F1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ProjectSelectorField(
                  controller: controller,
                  focusNode: focusNode,
                  selectedProject: null,
                  existingProjects: mixedProjects,
                  isOpen: isOpen,
                  onOpenChanged: (val) => setState(() => isOpen = val),
                  onSelectProject: (p) => setState(() => controller.text = p ?? ''),
                  onClear: () => setState(() => controller.clear()),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Custom project must be visible
      expect(find.text('Alpha Mobile App'), findsOneWidget);

      // Default projects must be filtered out
      expect(find.text('Work'), findsNothing);
      expect(find.text('Personal'), findsNothing);
      expect(find.text('Growth'), findsNothing);
    });

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

      // Should show empty prompt
      expect(find.text('No custom categories yet. Type above to create one.'), findsOneWidget);

      // Must NOT show legacy default habit categories
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

      final categories = const [
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

      // Only the custom category should show
      expect(find.text('Deep Work'), findsOneWidget);
      expect(find.text('Workout'), findsNothing);
    });

    testWidgets('CategorySelectorField shows all user categories even when editing a habit with pre-selected category',
        (WidgetTester tester) async {
      // Simulate editing a habit with existing category "Deep Work"
      final controller = TextEditingController(text: 'Deep Work');
      final focusNode = FocusNode();
      bool isOpen = true;

      final categories = const [
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

      // ALL user-created categories must be visible in the dropdown, not hidden by query
      // "Deep Work" appears twice: once in the TextField, and once in the dropdown list
      expect(find.text('Deep Work'), findsNWidgets(2));
      expect(find.text('Fitness Routine'), findsOneWidget);
      expect(find.text('Mindfulness'), findsOneWidget);
    });

    testWidgets('Multiple custom categories do not replace each other and persist simultaneously',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      bool isOpen = true;

      // Start with category 1
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

      // Only Category 1 is present initially
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Study'), findsNothing);

      // Add Category 2
      await tester.tap(find.text('Add Second Category'));
      await tester.pumpAndSettle();

      // BOTH Category 1 and Category 2 must be present simultaneously - neither replaced!
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
    });
  });
}
