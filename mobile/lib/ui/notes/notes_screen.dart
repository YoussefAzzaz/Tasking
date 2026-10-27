import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/notes/widgets/note_detail_sheet.dart';
import 'package:axis/ui/notes/widgets/note_category_card.dart';
import 'package:axis/ui/notes/widgets/daily_journal_card.dart';
import 'package:axis/ui/common/category_filter_slider.dart';
import 'package:axis/ui/common/cyber_search_bar.dart';

export 'package:axis/ui/notes/widgets/note_detail_sheet.dart';
export 'package:axis/ui/notes/widgets/note_card_widget.dart';
export 'package:axis/ui/notes/widgets/note_category_card.dart';
export 'package:axis/ui/notes/widgets/note_category_selector_field.dart';
export 'package:axis/ui/notes/widgets/daily_review_prompt_card.dart';
export 'package:axis/ui/notes/widgets/daily_journal_card.dart';
export 'package:axis/ui/notes/widgets/note_date_filter_toolbar.dart';

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
          await _repo.deleteNote(note.id);
          setState(() {});
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEmptySearchState({
    required String query,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AxisColors.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 32, color: AxisColors.secondary),
            ),
            const SizedBox(height: 14),
            Text(
              'No notes found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try checking your spelling or search with a different keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AxisColors.textDim,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AxisColors.secondary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.close_rounded,
                  size: 14, color: AxisColors.secondary),
              label: const Text(
                'Clear Search',
                style: TextStyle(
                  color: AxisColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Screen Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _activeTab == 'journal' ? 'Journals' : 'Notes & Journal',
                        style: Theme.of(context).textTheme.displaySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeTab == 'journal'
                            ? 'Daily reflections, logs & prompts'
                            : 'Categorized notes & knowledge base',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AxisColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openCreateNote(
                    category: _activeTab == 'journal'
                        ? 'journal'
                        : (_selectedCategoryId != 'all' &&
                                _selectedCategoryId != 'general_notes'
                            ? _selectedCategoryId
                            : 'General'),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _activeTab == 'journal'
                            ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
                            : const [AxisColors.secondary, Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: (_activeTab == 'journal'
                                  ? AxisColors.warning
                                  : AxisColors.secondary)
                              .withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _activeTab == 'journal'
                              ? Icons.auto_stories_rounded
                              : Icons.edit_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _activeTab == 'journal' ? 'New Journal' : 'New Note',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Segmented Tab Switcher: Notes vs Journals
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_activeTab != 'notes') {
                          setState(() {
                            _activeTab = 'notes';
                            _selectedCategoryId = 'all';
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 'notes'
                              ? AxisColors.secondary.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _activeTab == 'notes'
                                ? AxisColors.secondary.withValues(alpha: 0.8)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 15,
                              color: _activeTab == 'notes'
                                  ? AxisColors.secondary
                                  : AxisColors.textDim,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Notes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _activeTab == 'notes'
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: _activeTab == 'notes'
                                    ? AxisColors.textHigh
                                    : AxisColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_activeTab != 'journal') {
                          setState(() {
                            _activeTab = 'journal';
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 'journal'
                              ? AxisColors.warning.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _activeTab == 'journal'
                                ? AxisColors.warning.withValues(alpha: 0.8)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 15,
                              color: _activeTab == 'journal'
                                  ? AxisColors.warning
                                  : AxisColors.textDim,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Journals',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _activeTab == 'journal'
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: _activeTab == 'journal'
                                    ? AxisColors.textHigh
                                    : AxisColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                        child: CircularProgressIndicator(color: AxisColors.secondary),
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
                      notesByCategory.putIfAbsent(matchedCat.name, () => []).add(n);
                    } else {
                      unassignedNotes.add(n);
                    }
                  }

                  int totalRegularNotes = unassignedNotes.length;
                  for (final list in notesByCategory.values) {
                    totalRegularNotes += list.length;
                  }

                  final isSearching = _searchQuery.isNotEmpty;

                  // ==========================================
                  // 1. NOTES TAB CONTENT
                  // ==========================================
                  if (_activeTab == 'notes') {
                    // Build horizontal category filter slider items (notes only)
                    final sliderItems = <CategorySliderItem>[
                      CategorySliderItem(
                        id: 'all',
                        label: 'All Notes',
                        iconData: Icons.apps_rounded,
                        color: AxisColors.secondary,
                        count: totalRegularNotes,
                      ),
                      ...allCategories.map((category) {
                        final notes = notesByCategory[category.name] ?? [];
                        return CategorySliderItem(
                          id: category.id,
                          label: category.name,
                          icon: category.icon,
                          color: _parseHex(category.color),
                          count: notes.length,
                        );
                      }),
                      if (unassignedNotes.isNotEmpty)
                        CategorySliderItem(
                          id: 'general_notes',
                          label: 'General Notes',
                          iconData: Icons.article_rounded,
                          color: const Color(0xFF64748B),
                          count: unassignedNotes.length,
                        ),
                    ];

                    final displayedCategories = allCategories.where((category) {
                      if (_selectedCategoryId != 'all') {
                        final matches = category.id.toLowerCase() ==
                                _selectedCategoryId.toLowerCase() ||
                            category.name.toLowerCase() ==
                                _selectedCategoryId.toLowerCase();
                        if (!matches) return false;
                      }

                      if (_searchQuery.isNotEmpty) {
                        final notes = notesByCategory[category.name] ?? [];
                        final hasMatchingNote = notes.any((n) =>
                            n.title.toLowerCase().contains(_searchQuery) ||
                            n.bodyMd.toLowerCase().contains(_searchQuery));
                        final matchesCategory =
                            category.name.toLowerCase().contains(_searchQuery);
                        return hasMatchingNote || matchesCategory;
                      }

                      return true;
                    }).toList();

                    final showUnassignedCategory = (_selectedCategoryId == 'all' ||
                            _selectedCategoryId.toLowerCase() == 'general_notes') &&
                        unassignedNotes.isNotEmpty;

                    final displayedUnassignedNotes = showUnassignedCategory
                        ? (_searchQuery.isEmpty
                            ? unassignedNotes
                            : unassignedNotes
                                .where((n) =>
                                    n.title.toLowerCase().contains(_searchQuery) ||
                                    n.bodyMd.toLowerCase().contains(_searchQuery))
                                .toList())
                        : <Note>[];

                    int totalMatchingNotes = displayedUnassignedNotes.length;
                    for (final cat in displayedCategories) {
                      final raw = notesByCategory[cat.name] ?? [];
                      final filtered = _searchQuery.isEmpty
                          ? raw
                          : raw
                              .where((n) =>
                                  n.title.toLowerCase().contains(_searchQuery) ||
                                  n.bodyMd.toLowerCase().contains(_searchQuery) ||
                                  cat.name.toLowerCase().contains(_searchQuery))
                              .toList();
                      totalMatchingNotes += filtered.length;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: CyberSearchBar(
                            controller: _searchController,
                            hintText: 'Search notes or categories...',
                            accentColor: AxisColors.secondary,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                            onClear: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Horizontal category filter slider
                        if (sliderItems.length > 1) ...[
                          CategoryFilterSlider(
                            items: sliderItems,
                            selectedId: _selectedCategoryId,
                            onSelected: (id) {
                              setState(() {
                                if (_selectedCategoryId == id && id != 'all') {
                                  _selectedCategoryId = 'all';
                                } else {
                                  _selectedCategoryId = id;
                                }
                              });
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          const SizedBox(height: 14),
                        ],



                        // Empty search results state
                        if (isSearching && totalMatchingNotes == 0)
                          _buildEmptySearchState(
                            query: _searchController.text.trim(),
                            onClear: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        // No note categories created state
                        else if (!isSearching &&
                            allCategories.isEmpty &&
                            unassignedNotes.isEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AxisColors.surfaceLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AxisColors.borderSubtle),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.folder_open_rounded,
                                      size: 38, color: AxisColors.textDim),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No Notes or Categories Yet',
                                    style: TextStyle(
                                      color: AxisColors.textHigh,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tap "New Note" above to organize your thoughts and knowledge.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AxisColors.textDim,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _openCreateNote(category: 'General'),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Create First Note'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AxisColors.secondary,
                                      foregroundColor: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        // Render separated categories
                        else ...[
                          // Custom categories
                          ...displayedCategories.map((category) {
                            final rawNotes = notesByCategory[category.name] ?? [];
                            final notes = (!isSearching ||
                                    category.name.toLowerCase().contains(_searchQuery))
                                ? rawNotes
                                : rawNotes
                                    .where((n) =>
                                        n.title.toLowerCase().contains(_searchQuery) ||
                                        n.bodyMd.toLowerCase().contains(_searchQuery))
                                    .toList();
                            final color = _parseHex(category.color);

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: NoteCategoryCard(
                                category: category,
                                color: color,
                                notes: notes,
                                forceExpand: isSearching,
                                onTapNote: _showNoteDetail,
                                onAddNote: () => _openCreateNote(
                                  category: category.name,
                                  existingCategories: allCategories,
                                ),
                                onDeleteCategory: () async {
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
                              ),
                            );
                          }),

                          // General Notes Category Card
                          if (displayedUnassignedNotes.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: NoteCategoryCard(
                                category: const NoteCategory(
                                  id: 'general_notes',
                                  name: 'General Notes',
                                  icon: 'article',
                                  color: '#64748B',
                                ),
                                color: const Color(0xFF64748B),
                                notes: displayedUnassignedNotes,
                                forceExpand: isSearching,
                                onTapNote: _showNoteDetail,
                                onAddNote: () => _openCreateNote(
                                  category: 'General',
                                  existingCategories: allCategories,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    );
                  }

                  // ==========================================
                  // 2. JOURNALS TAB CONTENT
                  // ==========================================
                  final displayedJournalNotes = _searchQuery.isEmpty
                      ? journalNotes
                      : journalNotes
                          .where((n) =>
                              n.title.toLowerCase().contains(_searchQuery) ||
                              n.bodyMd.toLowerCase().contains(_searchQuery))
                          .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search bar for journals
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CyberSearchBar(
                          controller: _searchController,
                          hintText: 'Search journals & reflections...',
                          accentColor: AxisColors.warning,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          onClear: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Daily Journal Card (prominent when no search query)
                      if (!isSearching) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DailyJournalCard(
                            todayJournal: todayJournal,
                            onOpenTodayJournal: (note) => _openCreateNote(
                              category: 'journal',
                              noteToEdit: note,
                            ),
                            onStartNewJournal: () =>
                                _openCreateNote(category: 'journal'),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Empty search results state
                      if (isSearching && displayedJournalNotes.isEmpty)
                        _buildEmptySearchState(
                          query: _searchController.text.trim(),
                          onClear: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      // No journal entries yet state
                      else if (!isSearching && journalNotes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLow,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.menu_book_rounded,
                                    size: 38, color: AxisColors.textDim),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Journal Entries Recorded Yet',
                                  style: TextStyle(
                                    color: AxisColors.textHigh,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Log your daily thoughts, reflections, and insights.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AxisColors.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _openCreateNote(category: 'journal'),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Start First Journal'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AxisColors.warning,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      // Render Journal Entries Card
                      else if (displayedJournalNotes.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: NoteCategoryCard(
                            category: const NoteCategory(
                              id: 'journal',
                              name: 'Daily Logs & Reflections',
                              icon: 'journal',
                              color: '#F59E0B',
                            ),
                            color: AxisColors.warning,
                            notes: displayedJournalNotes,
                            forceExpand: true,
                            onTapNote: _showNoteDetail,
                            onAddNote: () =>
                                _openCreateNote(category: 'journal'),
                          ),
                        ),
                      ],
                    ],
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
