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

  testWidgets('Stack with Positioned.fill closes sheet on outside click', (tester) async {
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetCtx) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              key: const ValueKey('outside_barrier'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                closed = true;
                                Navigator.pop(sheetCtx);
                              },
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: GestureDetector(
                              key: const ValueKey('sheet_container'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {},
                              child: Container(
                                height: 300,
                                color: Colors.blue,
                                child: const Center(child: Text('Sheet Content')),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    );

    // Open the sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Sheet Content'), findsOneWidget);
    expect(closed, isFalse);

    // Tap inside the sheet container -> should NOT close
    await tester.tap(find.byKey(const ValueKey('sheet_container')));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('Sheet Content'), findsOneWidget);

    // Tap outside the sheet container (near the top of the screen)
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.text('Sheet Content'), findsNothing);
  });

  testWidgets('DraggableScrollableSheet in Stack closes on outside click', (tester) async {
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetCtx) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              key: const ValueKey('draggable_outside_barrier'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                closed = true;
                                Navigator.pop(sheetCtx);
                              },
                            ),
                          ),
                          DraggableScrollableSheet(
                            initialChildSize: 0.6,
                            minChildSize: 0.4,
                            maxChildSize: 0.9,
                            builder: (ctx, scroll) {
                              return Container(
                                color: Colors.green,
                                child: ListView(
                                  controller: scroll,
                                  children: const [
                                    Text('Draggable Content'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Open Draggable'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Draggable'));
    await tester.pumpAndSettle();

    expect(find.text('Draggable Content'), findsOneWidget);
    expect(closed, isFalse);

    // Tap outside in empty top space
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.text('Draggable Content'), findsNothing);
  });

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
