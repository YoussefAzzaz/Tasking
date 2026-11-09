import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/notes/widgets/note_detail_sheet.dart';
import 'package:axis/ui/notes/widgets/notes_screen_header.dart';
import 'package:axis/ui/notes/widgets/notes_tab_view.dart';
import 'package:axis/ui/notes/widgets/journals_tab_view.dart';

export 'package:axis/ui/notes/widgets/note_detail_sheet.dart';
export 'package:axis/ui/notes/widgets/note_card_widget.dart';
export 'package:axis/ui/notes/widgets/note_category_card.dart';
export 'package:axis/ui/notes/widgets/note_category_selector_field.dart';
export 'package:axis/ui/notes/widgets/daily_review_prompt_card.dart';
export 'package:axis/ui/notes/widgets/daily_journal_card.dart';
export 'package:axis/ui/notes/widgets/note_date_filter_toolbar.dart';
export 'package:axis/ui/notes/widgets/notes_screen_header.dart';
export 'package:axis/ui/notes/widgets/notes_tab_view.dart';
export 'package:axis/ui/notes/widgets/journals_tab_view.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _repo = NoteRepository();
  final _categoryRepo = NoteCategoryRepository();

  late final Stream<List<Note>> _notesStream;
  late final Stream<List<NoteCategory>> _categoriesStream;

  List<NoteCategory> _latestCategories = [];

  String _activeTab = 'notes'; // 'notes' or 'journal'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryId = 'all';

  @override
  void initState() {
    super.initState();
    _notesStream = _repo.watchNotes();
    _categoriesStream = _categoryRepo.watchCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.secondary;
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.secondary;
    }
  }

  void _openCreateNote({
    String? category,
    List<NoteCategory>? existingCategories,
    Note? noteToEdit,
  }) {
    final effectiveCategory = category ??
        (_activeTab == 'journal' ? 'journal' : 'General');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateNoteSheet(
        initialCategory: effectiveCategory,
        existingCategories: existingCategories ?? _latestCategories,
        noteToEdit: noteToEdit,
        onNoteCreated: () => setState(() {}),
      ),
    );
  }

  void _showNoteDetail(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoteDetailSheet(
        note: note,
        onEdit: () => _openCreateNote(
          category: note.category,
          noteToEdit: note,
        ),
        onDelete: () async {
          final title = note.title.isNotEmpty ? note.title : 'Entry';
          await _repo.deleteNote(note.id);
          setState(() {});
          if (mounted) {
            AxisSnackBar.showDeleted(
              context,
              itemTitle: title,
              itemType: context.isArabic ? 'ملاحظة' : 'Note',
            );
          }
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Screen Header & Tab Switcher
          NotesScreenHeader(
            activeTab: _activeTab,
            onTabChanged: (tab) {
              setState(() {
                _activeTab = tab;
                if (tab == 'notes') {
                  _selectedCategoryId = 'all';
                }
              });
            },
            onNewItem: () => _openCreateNote(
              category: _activeTab == 'journal'
                  ? 'journal'
                  : (_selectedCategoryId != 'all' &&
                          _selectedCategoryId != 'general_notes'
                      ? _selectedCategoryId
                      : 'General'),
            ),
          ),
          const SizedBox(height: 12),

          // Dual Streams: Categories + Notes
          StreamBuilder<List<NoteCategory>>(
            stream: _categoriesStream,
            builder: (context, catSnapshot) {
              return StreamBuilder<List<Note>>(
                stream: _notesStream,
                builder: (context, noteSnapshot) {
                  if (catSnapshot.connectionState == ConnectionState.waiting &&
                      noteSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child:
                            CircularProgressIndicator(color: AxisColors.secondary),
                      ),
                    );
                  }

                  final customCategories = catSnapshot.data ?? [];
                  final rawNotes = noteSnapshot.data ?? [];
                  final allNotes = rawNotes;

                  final now = DateTime.now();
                  final todayJournal = rawNotes.cast<Note?>().firstWhere(
                    (n) =>
                        n != null &&
                        n.category == 'journal' &&
                        _isSameDay(n.createdAt, now),
                    orElse: () => null,
                  );

                  // Auto-discover categories from notes
                  final categoryNames = <String>{};
                  for (final c in customCategories) {
                    categoryNames.add(c.name.toLowerCase());
                  }

                  final discoveredCategories = <NoteCategory>[];
                  for (final n in allNotes) {
                    final catTrimmed = n.category.trim();
                    final catLower = catTrimmed.toLowerCase();
                    if (catTrimmed.isNotEmpty &&
                        catLower != 'note' &&
                        catLower != 'journal' &&
                        catLower != 'general' &&
                        catLower != 'general notes' &&
                        !categoryNames.contains(catLower)) {
                      categoryNames.add(catLower);
                      discoveredCategories.add(
                        NoteCategory(
                          id: 'discovered_$catTrimmed',
                          name: catTrimmed,
                          icon: 'article',
                          color: '#38BDF8',
                        ),
                      );
                    }
                  }

                  final allCategories = [
                    ...customCategories,
                    ...discoveredCategories,
                  ].where((c) {
                    final idLower = c.id.toLowerCase();
                    final nameLower = c.name.toLowerCase();
                    return idLower != 'general_notes' &&
                        nameLower != 'general notes' &&
                        idLower != 'general' &&
                        nameLower != 'general' &&
                        idLower != 'journal' &&
                        nameLower != 'journal' &&
                        idLower != 'all' &&
                        nameLower != 'note';
                  }).toList();

                  allCategories.sort((a, b) => a.name.compareTo(b.name));
                  _latestCategories = allCategories;

                  // Separate notes by category
                  final Map<String, List<Note>> notesByCategory = {};
                  final unassignedNotes = <Note>[];
                  final journalNotes = <Note>[];

                  for (final n in allNotes) {
                    final catTrimmed = n.category.trim();
                    final isJournal = catTrimmed.toLowerCase() == 'journal';

                    if (isJournal) {
                      journalNotes.add(n);
                      continue;
                    }

                    final isGeneral = catTrimmed.isEmpty ||
                        catTrimmed.toLowerCase() == 'general' ||
                        catTrimmed.toLowerCase() == 'note' ||
                        catTrimmed.toLowerCase() == 'general notes';

                    if (isGeneral) {
                      unassignedNotes.add(n);
                      continue;
                    }

                    final matchedCat = allCategories.firstWhere(
                      (c) =>
                          c.id == catTrimmed ||
                          c.name.toLowerCase() == catTrimmed.toLowerCase(),
                      orElse: () => const NoteCategory(id: '', name: ''),
                    );

                    if (matchedCat.name.isNotEmpty) {
                      notesByCategory
                          .putIfAbsent(matchedCat.name, () => [])
                          .add(n);
                    } else {
                      unassignedNotes.add(n);
                    }
                  }

                  // 1. NOTES TAB CONTENT
                  if (_activeTab == 'notes') {
                    return NotesTabView(
                      allCategories: allCategories,
                      notesByCategory: notesByCategory,
                      unassignedNotes: unassignedNotes,
                      searchController: _searchController,
                      searchQuery: _searchQuery,
                      selectedCategoryId: _selectedCategoryId,
                      onSearchChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                      onSearchCleared: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      onCategorySelected: (id) {
                        setState(() {
                          if (_selectedCategoryId == id && id != 'all') {
                            _selectedCategoryId = 'all';
                          } else {
                            _selectedCategoryId = id;
                          }
                        });
                      },
                      onTapNote: _showNoteDetail,
                      onAddNoteToCategory: (catName) => _openCreateNote(
                        category: catName,
                        existingCategories: allCategories,
                      ),
                      onDeleteCategory: (category) async {
                        setState(() {
                          if (_selectedCategoryId == category.id ||
                              _selectedCategoryId.toLowerCase() ==
                                  category.name.toLowerCase()) {
                            _selectedCategoryId = 'all';
                          }
                        });

                        await _categoryRepo.deleteCategory(
                          category.id,
                          name: category.name,
                        );
                      },
                      parseHex: _parseHex,
                      onOpenCreateFirstNote: () =>
                          _openCreateNote(category: 'General'),
                    );
                  }

                  // 2. JOURNALS TAB CONTENT
                  return JournalsTabView(
                    todayJournal: todayJournal,
                    journalNotes: journalNotes,
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    onSearchChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    onSearchCleared: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                    onOpenTodayJournal: (note) => _openCreateNote(
                      category: 'journal',
                      noteToEdit: note,
                    ),
                    onStartNewJournal: () =>
                        _openCreateNote(category: 'journal'),
                    onTapNote: _showNoteDetail,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
