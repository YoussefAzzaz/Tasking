import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/ui/tasks/widgets/project_selector_field.dart';

void main() {
  group('ProjectSelectorField Isolation Tests', () {
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

      expect(find.text('Inbox (No Project)'), findsOneWidget);
      expect(find.text('No custom projects yet. Type above to create one.'), findsOneWidget);

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

      expect(find.text('Alpha Mobile App'), findsOneWidget);
      expect(find.text('Work'), findsNothing);
      expect(find.text('Personal'), findsNothing);
      expect(find.text('Growth'), findsNothing);
    });
  });
}

