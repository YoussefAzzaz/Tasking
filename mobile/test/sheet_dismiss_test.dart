import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/notes/widgets/note_detail_sheet.dart';
import 'package:axis/ui/habits/create_habit_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CreateTaskSheet dismisses on outside click and top bar click', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CreateTaskSheet(onTaskCreated: () {}),
                  );
                },
                child: const Text('Open Task Sheet'),
              );
            },
          ),
        ),
      ),
    );

    // 1. Open and test top bar dismissal
    await tester.tap(find.text('Open Task Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTaskSheet), findsOneWidget);

    // Tap the top bar
    await tester.tap(find.byType(ModalSheetTopBar));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTaskSheet), findsNothing);

    // 2. Open again and test outside click dismissal
    await tester.tap(find.text('Open Task Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTaskSheet), findsOneWidget);

    // Tap near the top of the screen (outside sheet container)
    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTaskSheet), findsNothing);
  });

  testWidgets('CreateNoteSheet dismisses on outside click and top bar click', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CreateNoteSheet(onNoteCreated: () {}),
                  );
                },
                child: const Text('Open Note Sheet'),
              );
            },
          ),
        ),
      ),
    );

    // 1. Top bar dismissal
    await tester.tap(find.text('Open Note Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateNoteSheet), findsOneWidget);

    await tester.tap(find.byType(ModalSheetTopBar));
    await tester.pumpAndSettle();

    expect(find.byType(CreateNoteSheet), findsNothing);

    // 2. Outside click dismissal
    await tester.tap(find.text('Open Note Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateNoteSheet), findsOneWidget);

    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();

    expect(find.byType(CreateNoteSheet), findsNothing);
  });

  testWidgets('CreateHabitSheet dismisses on outside click and top bar click', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CreateHabitSheet(onHabitCreated: () {}),
                  );
                },
                child: const Text('Open Habit Sheet'),
              );
            },
          ),
        ),
      ),
    );

    // 1. Top bar dismissal
    await tester.tap(find.text('Open Habit Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHabitSheet), findsOneWidget);

    await tester.tap(find.byType(ModalSheetTopBar));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHabitSheet), findsNothing);

    // 2. Outside click dismissal
    await tester.tap(find.text('Open Habit Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHabitSheet), findsOneWidget);

    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHabitSheet), findsNothing);
  });

  testWidgets('NoteDetailSheet dismisses on outside click and top bar click', (tester) async {
    final note = Note(
      id: 'n1',
      title: 'Deep Reflection Journal',
      bodyMd: 'Gratitude journal entry content.',
      category: 'journal',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => NoteDetailSheet(
                      note: note,
                      onEdit: () {},
                      onDelete: () {},
                    ),
                  );
                },
                child: const Text('Open Note Detail'),
              );
            },
          ),
        ),
      ),
    );

    // 1. Top bar dismissal
    await tester.tap(find.text('Open Note Detail'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteDetailSheet), findsOneWidget);

    await tester.tap(find.byType(ModalSheetTopBar));
    await tester.pumpAndSettle();

    expect(find.byType(NoteDetailSheet), findsNothing);

    // 2. Outside click dismissal
    await tester.tap(find.text('Open Note Detail'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteDetailSheet), findsOneWidget);

    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();

    expect(find.byType(NoteDetailSheet), findsNothing);
  });

  testWidgets('TaskDetailSheet dismisses on outside click and top bar click', (tester) async {
    final task = Task(
      id: 't1',
      title: 'Review System Design',
      notes: 'Detailed notes on design.',
      status: 'todo',
      priority: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TaskDetailSheet(task: task),
                  );
                },
                child: const Text('Open Task Detail'),
              );
            },
          ),
        ),
      ),
    );

    // 1. Top bar dismissal
    await tester.tap(find.text('Open Task Detail'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsOneWidget);

    await tester.tap(find.byType(ModalSheetTopBar));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsNothing);

    // 2. Outside click dismissal
    await tester.tap(find.text('Open Task Detail'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsOneWidget);

    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsNothing);
  });
}
