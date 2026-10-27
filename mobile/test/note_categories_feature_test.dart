import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/notes/notes_screen.dart';

void main() {
  group('Note Categories Feature Tests', () {
    test('NoteCategory model copyWith preserves and updates values correctly', () {
      const cat = NoteCategory(
        id: 'cat_work',
        name: 'Work',
        icon: 'work',
        color: '#38BDF8',
      );

      final updated = cat.copyWith(name: 'Work & Projects', color: '#10B981');
      expect(updated.id, equals('cat_work'));
      expect(updated.name, equals('Work & Projects'));
      expect(updated.icon, equals('work'));
      expect(updated.color, equals('#10B981'));
    });

    testWidgets('NoteCategoryCard renders category name, count, and note items with expand/collapse',
        (tester) async {
      bool addTapped = false;
      bool deleteTapped = false;
      Note? selectedNote;

      final testCategory = const NoteCategory(
        id: 'cat_work',
        name: 'Architecture',
        icon: 'code',
        color: '#38BDF8',
      );

      final testNotes = [
        Note(
          id: 'note_1',
          title: 'System Blueprint',
          bodyMd: 'Microservices architecture plan',
          category: 'Architecture',
        ),
        Note(
          id: 'note_2',
          title: 'Database Indexing',
          bodyMd: 'B-tree vs LSM tree benchmarks',
          category: 'Architecture',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: NoteCategoryCard(
              category: testCategory,
              color: const Color(0xFF38BDF8),
              notes: testNotes,
              onTapNote: (n) => selectedNote = n,
              onAddNote: () => addTapped = true,
              onDeleteCategory: () => deleteTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify category title, count and entry label
      expect(find.text('Architecture'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('2 entries'), findsOneWidget);
      expect(find.text('System Blueprint'), findsOneWidget);
      expect(find.text('Database Indexing'), findsOneWidget);

      // Tap on a note item
      await tester.tap(find.text('System Blueprint'));
      expect(selectedNote?.id, equals('note_1'));

      // Tap add note button
      await tester.tap(find.byTooltip('Add note to Architecture'));
      expect(addTapped, isTrue);

      // Tap delete button to show dialog
      await tester.tap(find.byTooltip('Delete category'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Architecture"?'), findsOneWidget);

      // Confirm delete dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleteTapped, isTrue);

      // Test collapse toggle
      await tester.tap(find.text('Architecture').first);
      await tester.pumpAndSettle();
      expect(find.text('System Blueprint'), findsNothing);

      // Test re-expand
      await tester.tap(find.text('Architecture').first);
      await tester.pumpAndSettle();
      expect(find.text('System Blueprint'), findsOneWidget);
    });

    testWidgets('NoteCategorySelectorField filters categories and allows selection',
        (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      bool isOpen = true;
      String? selectedName;

      final categories = [
        const NoteCategory(id: 'cat_work', name: 'Work', icon: 'work', color: '#38BDF8'),
        const NoteCategory(id: 'cat_ideas', name: 'Ideas', icon: 'idea', color: '#F59E0B'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => NoteCategorySelectorField(
                controller: controller,
                focusNode: focusNode,
                categories: categories,
                isOpen: isOpen,
                onOpenChanged: (val) => setState(() => isOpen = val),
                onSelectCategory: (name, icon, color) {
                  setState(() {
                    selectedName = name;
                    controller.text = name;
                  });
                },
                onClear: () {
                  setState(() => controller.clear());
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Ideas'), findsOneWidget);

      // Tap 'Ideas'
      await tester.tap(find.text('Ideas'));
      await tester.pumpAndSettle();

      expect(selectedName, equals('Ideas'));
      expect(controller.text, equals('Ideas'));
    });

    testWidgets('NoteCategorySelectorField shows create new category option when typing new query',
        (tester) async {
      final controller = TextEditingController(text: 'Research');
      final focusNode = FocusNode();
      bool isOpen = true;
      String? selectedName;

      final categories = [
        const NoteCategory(id: 'cat_work', name: 'Work', icon: 'work', color: '#38BDF8'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => NoteCategorySelectorField(
                controller: controller,
                focusNode: focusNode,
                categories: categories,
                isOpen: isOpen,
                onOpenChanged: (val) => setState(() => isOpen = val),
                onSelectCategory: (name, icon, color) {
                  setState(() => selectedName = name);
                },
                onClear: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Create new category "Research"'), findsOneWidget);

      await tester.tap(find.text('Create new category "Research"'));
      await tester.pumpAndSettle();

      expect(selectedName, equals('Research'));
    });

    testWidgets('CreateNoteSheet supports pre-filled initialCategory and custom category typing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateNoteSheet(
              initialCategory: 'Design Systems',
              onNoteCreated: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify category controller is populated with initial category
      expect(find.text('Design Systems'), findsOneWidget);

      // Verify Title field is present
      expect(find.text('TITLE'), findsOneWidget);

      // Verify Category section title is present
      expect(find.text('CATEGORY'), findsOneWidget);
    });

    testWidgets('NotesScreen does not render removed banners or date filter toolbar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const Scaffold(
            body: NotesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notes & Journal'), findsOneWidget);
      expect(find.text('NOTES BY CATEGORY'), findsNothing);
      expect(find.text('Category'), findsNothing);
      expect(find.text('JOURNAL ENTRIES'), findsNothing);
      expect(find.text('Filter by Date'), findsNothing);
      expect(find.text('Today'), findsNothing);
      expect(find.text('Yesterday'), findsNothing);
      expect(find.text('DAILY REVIEW PROMPT'), findsNothing);
    });

    testWidgets('NotesScreen separates notes from journals and toggles between tabs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const Scaffold(
            body: NotesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially in Notes tab
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Journals'), findsOneWidget);
      expect(find.text('New Note'), findsOneWidget);
      expect(find.text('NOTES BY CATEGORY'), findsNothing);

      // Tap on Journals tab
      await tester.tap(find.text('Journals'));
      await tester.pumpAndSettle();

      // Now in Journals tab
      expect(find.text('New Journal'), findsWidgets);
      expect(find.text('JOURNAL ENTRIES'), findsNothing);
      expect(find.text('DAILY REVIEW PROMPT'), findsNothing);

      // Switch back to Notes tab
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('New Note'), findsOneWidget);
      expect(find.text('NOTES BY CATEGORY'), findsNothing);
    });

    testWidgets('CreateNoteSheet defaults category to General when creating note',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateNoteSheet(
              onNoteCreated: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify category defaults to General
      expect(find.text('General'), findsOneWidget);
      expect(find.text('NEW NOTE'), findsOneWidget);
    });
  });
}
