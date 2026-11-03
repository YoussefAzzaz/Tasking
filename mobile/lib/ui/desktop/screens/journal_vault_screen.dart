import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/note_category_repository.dart';
import '../../../data/note_repository.dart';
import '../../../data/reading_preferences_service.dart';
import '../../../domain/id_generator.dart';
import '../../common/axis_markdown_viewer.dart';
import '../../notes/widgets/daily_review_prompt_card.dart';
import '../../notes/widgets/note_format_toolbar.dart';
import '../core/desktop_layout.dart';
import '../services/desktop_file_service.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_horizontal_scroll.dart';
import '../widgets/ghost_button.dart';
import '../widgets/telemetry_chip.dart';

/// Journal & Vault Screen (Tab 4) — 3-column Markdown knowledge base, note categories, and personal vault.
class JournalVaultScreen extends StatefulWidget {
  const JournalVaultScreen({super.key});

  @override
  State<JournalVaultScreen> createState() => _JournalVaultScreenState();
}

class _JournalVaultScreenState extends State<JournalVaultScreen> {
  Note? _selectedNote;
  bool _isCreating = false;
  String _creatingCategory = 'General';
  final _searchController = TextEditingController();
  final _editorController = TextEditingController();
  final _editorFocusNode = FocusNode();
  final _titleController = TextEditingController();
  final _vaultScrollController = ScrollController();
  String _activeTab = 'notes'; // 'notes' or 'journal'
  String _selectedCategoryFilter = 'All';
  String _searchQuery = '';
  Timer? _debounceTimer;
  Timer? _titleDebounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _editorController.dispose();
    _editorFocusNode.dispose();
    _titleController.dispose();
    _vaultScrollController.dispose();
    _debounceTimer?.cancel();
    _titleDebounceTimer?.cancel();
    super.dispose();
  }

  void _selectNote(Note note) {
    _debounceTimer?.cancel();
    _titleDebounceTimer?.cancel();
    setState(() {
      _isCreating = false;
      _selectedNote = note;
      _editorController.text = note.bodyMd;
      _titleController.text = note.title;
    });
  }

  void _onTitleChanged(String title) {
    if (_selectedNote == null || _isCreating) {
      setState(() {});
      return;
    }
    _titleDebounceTimer?.cancel();
    _titleDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_selectedNote != null && !_isCreating) {
        final updated = _selectedNote!.copyWith(title: title);
        try {
          await NoteRepository().updateNote(updated);
        } catch (e) {
          debugPrint('[JournalVaultScreen] Error updating note title: $e');
        }
        if (mounted) setState(() => _selectedNote = updated);
      }
    });
    setState(() {});
  }

  void _onEditorChanged(String text) {
    if (_selectedNote == null || _isCreating) {
      setState(() {});
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (_selectedNote != null && !_isCreating) {
        final updated = _selectedNote!.copyWith(bodyMd: text);
        try {
          await NoteRepository().updateNote(updated);
        } catch (e) {
          debugPrint('[JournalVaultScreen] Error updating note body: $e');
        }
        if (mounted) setState(() => _selectedNote = updated);
      }
    });
    setState(() {}); // Updates live preview immediately
  }

  Future<void> _handleTogglePin() async {
    if (_selectedNote == null) return;
    final updated = _selectedNote!.copyWith(pinned: !_selectedNote!.pinned);
    try {
      await NoteRepository().updateNote(updated);
    } catch (e) {
      debugPrint('[JournalVaultScreen] Error toggling pin: $e');
    }
    if (mounted) {
      setState(() => _selectedNote = updated);
    }
  }

  Future<void> _handleUpdateCategory(String categoryName) async {
    if (_selectedNote == null) return;
    final updated = _selectedNote!.copyWith(category: categoryName);
    try {
      await NoteRepository().updateNote(updated);
    } catch (e) {
      debugPrint('[JournalVaultScreen] Error updating category: $e');
    }
    if (mounted) {
      setState(() => _selectedNote = updated);
    }
  }

  void _handleStartNewEntry({required String category}) {
    _debounceTimer?.cancel();
    _titleDebounceTimer?.cancel();
    setState(() {
      _selectedNote = null;
      _isCreating = true;
      _creatingCategory = category == 'journal'
          ? 'journal'
          : (_selectedCategoryFilter != 'All' && _selectedCategoryFilter.isNotEmpty
              ? _selectedCategoryFilter
              : 'General');
      _titleController.clear();
      _editorController.clear();
      if (category == 'journal') {
        final now = DateTime.now();
        final dateHeading = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        _titleController.text = 'Daily Reflection • $dateHeading';
        _editorController.text = '# Daily Review • $dateHeading\n\n### ⚡ Focus & Accomplishments\n- What was the main victory today?\n- Key deliverables executed\n\n### 💡 Insights & Energy\n- What energized me?\n- Blockers resolved\n\n### 🎯 Tomorrow Priorities\n- [ ] Top priority 1\n- [ ] Top priority 2\n';
      }
    });
  }

  Future<void> _handleSaveNewEntry() async {
    final rawTitle = _titleController.text.trim();
    final isJournal = _activeTab == 'journal';
    final now = DateTime.now();
    final dateHeading = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final title = rawTitle.isNotEmpty
        ? rawTitle
        : (isJournal ? 'Daily Reflection • $dateHeading' : 'Untitled Note');

    final body = _editorController.text;
    final category = isJournal
        ? 'journal'
        : (_creatingCategory.isNotEmpty ? _creatingCategory : 'General');

    final newNote = Note(
      id: IdGenerator.generateDeterministicId('${isJournal ? 'journal' : 'note'}_${now.microsecondsSinceEpoch}'),
      title: title,
      bodyMd: body,
      category: category,
      mood: isJournal ? 'CALM FOCUS' : null,
    );

    try {
      await NoteRepository().addNote(newNote);
    } catch (e) {
      debugPrint('[JournalVaultScreen] Error adding note: $e');
    }

    if (mounted) {
      setState(() {
        _isCreating = false;
        _selectedNote = newNote;
        _titleController.text = newNote.title;
        _editorController.text = newNote.bodyMd;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isJournal ? 'Journal entry saved' : 'Note saved to Vault'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleSaveEditor() async {
    if (_isCreating || _selectedNote == null) {
      await _handleSaveNewEntry();
      return;
    }
    _debounceTimer?.cancel();
    _titleDebounceTimer?.cancel();
    final rawTitle = _titleController.text.trim();
    final title = rawTitle.isNotEmpty ? rawTitle : _selectedNote!.title;
    final updated = _selectedNote!.copyWith(
      title: title,
      bodyMd: _editorController.text,
    );
    try {
      await NoteRepository().updateNote(updated);
    } catch (e) {
      debugPrint('[JournalVaultScreen] Error saving note: $e');
    }
    if (mounted) {
      setState(() => _selectedNote = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_activeTab == 'journal' ? 'Journal saved' : 'Note saved to Vault'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleDeleteSelectedNote() async {
    if (_selectedNote == null) return;
    _debounceTimer?.cancel();
    _titleDebounceTimer?.cancel();
    final noteId = _selectedNote!.id;
    try {
      await NoteRepository().deleteNote(noteId);
    } catch (e) {
      debugPrint('[JournalVaultScreen] Error deleting note: $e');
    }
    if (mounted) {
      setState(() {
        _selectedNote = null;
        _isCreating = false;
        _titleController.clear();
        _editorController.clear();
      });
    }
  }

  void _switchTab(String tab) {
    if (_activeTab == tab) return;
    _debounceTimer?.cancel();
    _titleDebounceTimer?.cancel();
    setState(() {
      _activeTab = tab;
      _selectedNote = null;
      _isCreating = false;
      _creatingCategory = tab == 'journal' ? 'journal' : 'General';
      _titleController.clear();
      _editorController.clear();
    });
  }

  Future<void> _handleExportMarkdown() async {
    if (_selectedNote == null) return;
    final path = await DesktopFileService().exportMarkdownFile(
      title: _selectedNote!.title,
      markdownContent: _selectedNote!.bodyMd,
    );
    if (mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $path')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
          padding: const EdgeInsets.all(DesktopLayout.panelPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 6.2 Page Header
              _buildPageHeader(),
              const SizedBox(height: DesktopLayout.sectionSpacing),

              // 6.1 3-Column Split: Navigator (3) | Editor (4) | Preview (4)
              // All three panes stretch to the exact same height matching the page
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildNoteNavigatorPane(),
                    ),
                    const SizedBox(width: DesktopLayout.sectionSpacing),
                    Expanded(
                      flex: 4,
                      child: _buildMarkdownEditorPane(),
                    ),
                    const SizedBox(width: DesktopLayout.sectionSpacing),
                    Expanded(
                      flex: 4,
                      child: _buildLivePreviewPane(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (!constraints.hasBoundedHeight || constraints.maxHeight < 620) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SizedBox(
              height: 620,
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }

  Widget _buildPageHeader() {
    final note = _selectedNote;
    final isEditing = note != null && !_isCreating;
    final words = _editorController.text.isNotEmpty
        ? _editorController.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length
        : (note != null
            ? note.bodyMd.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length
            : 0);
    final readTime = (words / 200).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _activeTab == 'journal'
                        ? 'Knowledge Base / Journals / '
                        : 'Knowledge Base / Notes / ',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: AxisColors.textDim,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      isEditing
                          ? note.title
                          : (_isCreating
                              ? (_activeTab == 'journal' ? 'New Journal' : 'New Note')
                              : 'Overview'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AxisColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isEditing
                    ? note.title
                    : (_isCreating
                        ? (_activeTab == 'journal' ? 'Create Daily Journal' : 'Create Note')
                        : (_activeTab == 'journal' ? 'Journal Vault' : 'Vault & Architecture Notes')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '■ $words words  ·  ⏱ ~$readTime min read',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: AxisColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing) ...[
              GhostButton(
                label: note.pinned ? 'Pinned' : 'Pin',
                icon: note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: note.pinned ? AxisColors.secondary : null,
                borderColor: note.pinned ? AxisColors.secondary.withValues(alpha: 0.5) : null,
                onPressed: _handleTogglePin,
              ),
              const SizedBox(width: 8),
              GhostButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                color: AxisColors.priorityHigh,
                borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
                onPressed: _handleDeleteSelectedNote,
              ),
              const SizedBox(width: 8),
              GhostButton(
                label: 'Export .md',
                icon: Icons.file_download_outlined,
                onPressed: _handleExportMarkdown,
              ),
              const SizedBox(width: 8),
            ],
            AccentButton(
              label: AppLocalizations.of(context).isArabic
                  ? (_activeTab == 'journal' ? 'يومية جديدة' : 'ملاحظة جديدة')
                  : (_activeTab == 'journal' ? 'New Journal' : 'New Note'),
              icon: Icons.add_rounded,
              onPressed: () => _handleStartNewEntry(category: _activeTab),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteNavigatorPane() {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab Switcher
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab('notes'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _activeTab == 'notes' ? AxisColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _activeTab == 'notes' ? AxisColors.primary : AxisColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isArabic ? '≡ الملاحظات' : '≡ Notes',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _activeTab == 'notes' ? AxisColors.textHigh : AxisColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab('journal'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _activeTab == 'journal' ? AxisColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _activeTab == 'journal' ? AxisColors.primary : AxisColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        l10n.journals,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _activeTab == 'journal' ? AxisColors.textHigh : AxisColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Daily Review Prompt Card if in journal mode
          if (_activeTab == 'journal') ...[
            DailyReviewPromptCard(
              onTapRecord: () => _handleStartNewEntry(category: 'journal'),
            ),
            const SizedBox(height: 10),
          ],

          // Note Category Filter Chips if in notes mode
          if (_activeTab == 'notes') ...[
            StreamBuilder<List<NoteCategory>>(
              stream: NoteCategoryRepository().watchCategories(),
              builder: (context, catSnap) {
                final cats = catSnap.data ?? [];
                final seenFilters = <String>{'all', 'general'};
                final allFilters = <String>['All', 'General'];
                for (final c in cats) {
                  final name = c.name.trim();
                  if (name.isNotEmpty && seenFilters.add(name.toLowerCase())) {
                    allFilters.add(name);
                  }
                }
                return DesktopHorizontalScrollView(
                  child: Row(
                    children: allFilters.map((cat) {
                      final isSel = _selectedCategoryFilter.toLowerCase() == cat.toLowerCase();
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategoryFilter = cat),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8, bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSel ? AxisColors.secondary.withValues(alpha: 0.2) : AxisColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSel ? AxisColors.secondary : AxisColors.borderSubtle,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                              color: isSel ? AxisColors.secondary : AxisColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],

          // Search input (no double text field)
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
              decoration: InputDecoration(
                icon: const Icon(Icons.search_rounded, size: 15, color: AxisColors.textDim),
                hintText: 'Search notes & tags...',
                hintStyle: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Vault hierarchy section header
          Text(
            'VAULT HIERARCHY',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AxisColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable Vault Hierarchy List (does not expand with number of notes/journals)
          Expanded(
            child: StreamBuilder<List<Note>>(
              stream: NoteRepository().watchNotes(category: _activeTab == 'notes' ? null : 'journal'),
              builder: (context, snapshot) {
                final allNotes = snapshot.data ?? [];
                var filtered = allNotes;

                // When in notes tab, exclude journals
                if (_activeTab == 'notes') {
                  filtered = filtered.where((n) => n.category.toLowerCase() != 'journal').toList();
                } else if (_activeTab == 'journal') {
                  filtered = filtered.where((n) => n.category.toLowerCase() == 'journal').toList();
                }

                if (_activeTab == 'notes' && _selectedCategoryFilter != 'All') {
                  filtered = filtered.where((n) {
                    final cat = (n.category.isEmpty ? 'general' : n.category).toLowerCase();
                    return cat == _selectedCategoryFilter.toLowerCase();
                  }).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((n) =>
                      n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      n.bodyMd.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                }

                // Sort pinned first, then by created date
                filtered = List<Note>.from(filtered)
                  ..sort((a, b) {
                    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                    return b.createdAt.compareTo(a.createdAt);
                  });

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        _activeTab == 'journal' ? 'No journals recorded yet' : 'No notes found',
                        style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      ),
                    ),
                  );
                }

                return Scrollbar(
                  controller: _vaultScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _vaultScrollController,
                    padding: const EdgeInsets.only(right: 6),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      final isSelected = _selectedNote?.id == n.id;
                      return GestureDetector(
                        onTap: () => _selectNote(n),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AxisColors.primary.withValues(alpha: 0.16) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? AxisColors.primary : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                n.pinned
                                    ? Icons.push_pin_rounded
                                    : (n.category == 'journal' ? Icons.book_outlined : Icons.description_outlined),
                                size: 15,
                                color: n.pinned
                                    ? AxisColors.secondary
                                    : (isSelected ? AxisColors.secondary : AxisColors.textDim),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  n.title.isEmpty ? 'Untitled' : n.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.getFont(
                                    'Geist',
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? AxisColors.textHigh : AxisColors.textMuted,
                                  ),
                                ),
                              ),
                              if (n.category.isNotEmpty && n.category != 'general' && n.category != 'journal') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AxisColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AxisColors.borderSubtle, width: 0.8),
                                  ),
                                  child: Text(
                                    n.category,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AxisColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Mini Streak Calendar
          _buildJournalDeckStreakCalendar(),
        ],
      ),
    );
  }

  Widget _buildJournalDeckStreakCalendar() {
    return StreamBuilder<List<Note>>(
      stream: NoteRepository().watchNotes(),
      builder: (context, snapshot) {
        final notes = snapshot.data ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final noteDates = notes.map((n) => DateFormat('yyyy-MM-dd').format(n.createdAt.toLocal())).toSet();

        int streak = 0;
        DateTime checkDay = noteDates.contains(todayStr) ? now : now.subtract(const Duration(days: 1));
        while (noteDates.contains(DateFormat('yyyy-MM-dd').format(checkDay))) {
          streak++;
          checkDay = checkDay.subtract(const Duration(days: 1));
        }

        final monday = now.subtract(Duration(days: now.weekday - 1));

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AxisColors.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'JOURNAL DECK',
                    style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.textMuted),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 12, color: AxisColors.warning),
                      const SizedBox(width: 2),
                      Text(
                        streak > 0 ? '${streak}d Streak' : '0d Streak',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: streak > 0 ? AxisColors.warning : AxisColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final day = monday.add(Duration(days: i));
                  final dStr = DateFormat('yyyy-MM-dd').format(day);
                  final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
                  final hasNote = noteDates.contains(dStr);

                  return Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AxisColors.secondary
                          : (hasNote ? AxisColors.secondary.withValues(alpha: 0.25) : AxisColors.secondary.withValues(alpha: 0.08)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday
                            ? AxisColors.secondary
                            : (hasNote ? AxisColors.secondary : Colors.transparent),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: isToday || hasNote ? FontWeight.w700 : FontWeight.w500,
                          color: isToday
                              ? AxisColors.canvasBase
                              : (hasNote ? AxisColors.secondary : AxisColors.textDim),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarkdownEditorPane() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'MARKDOWN EDITOR',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AxisColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedNote != null && !_isCreating) ...[
                const TelemetryChip(
                  label: 'AUTO-SAVED',
                  color: AxisColors.tertiary,
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                ),
                const SizedBox(width: 8),
              ],
              AccentButton(
                label: _activeTab == 'journal' ? 'Save Journal' : 'Save Note',
                icon: Icons.save_rounded,
                onPressed: _handleSaveEditor,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Editable Title input (no double text field)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: _titleController,
              onChanged: _onTitleChanged,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AxisColors.textHigh,
              ),
              decoration: InputDecoration(
                hintText: _activeTab == 'journal' ? 'Daily Reflection Title...' : 'Note Title...',
                hintStyle: GoogleFonts.spaceGrotesk(fontSize: 14, color: AxisColors.textDim),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Note Category Selector (when in notes tab)
          if (_activeTab == 'notes') ...[
            Row(
              children: [
                Text(
                  'CATEGORY: ',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: AxisColors.textDim),
                ),
                StreamBuilder<List<NoteCategory>>(
                  stream: NoteCategoryRepository().watchCategories(),
                  builder: (context, snapshot) {
                    final cats = snapshot.data ?? [];
                    final seen = <String>{'general'};
                    final catNames = <String>['General'];
                    for (final c in cats) {
                      final name = c.name.trim();
                      if (name.isNotEmpty && seen.add(name.toLowerCase())) {
                        catNames.add(name);
                      }
                    }
                    final currentCat = (_selectedNote != null && !_isCreating)
                        ? (_selectedNote!.category.isEmpty ? 'General' : _selectedNote!.category)
                        : _creatingCategory;
                    final effectiveValue = catNames.firstWhere(
                      (c) => c.toLowerCase() == currentCat.toLowerCase(),
                      orElse: () => catNames.first,
                    );
                    return Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AxisColors.borderSubtle, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: effectiveValue,
                          dropdownColor: AxisColors.surfaceLow,
                          icon: const Icon(Icons.arrow_drop_down, size: 16, color: AxisColors.textDim),
                          style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: AxisColors.textHigh),
                          items: catNames.map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              if (_selectedNote != null && !_isCreating) {
                                _handleUpdateCategory(val);
                              } else {
                                setState(() => _creatingCategory = val);
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Format Toolbar with full Markdown suite
          NoteFormatToolbar(
            controller: _editorController,
            focusNode: _editorFocusNode,
            onChanged: () => _onEditorChanged(_editorController.text),
          ),
          const SizedBox(height: 10),

          // Editor text area (fills card height, placeholder aligned to top, no double border)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle, width: 1),
              ),
              child: TextField(
                controller: _editorController,
                focusNode: _editorFocusNode,
                onChanged: _onEditorChanged,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: GoogleFonts.firaCode(
                  fontSize: 13,
                  height: 1.5,
                  color: AxisColors.textHigh,
                ),
                decoration: InputDecoration(
                  hintText: '# Title\n\nBegin drafting your architectural breakdown or journal log...',
                  hintStyle: GoogleFonts.firaCode(fontSize: 13, color: AxisColors.textDim),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLivePreviewPane() {
    final markdown = _editorController.text.isNotEmpty
        ? _editorController.text
        : (_selectedNote?.bodyMd ?? '# Empty Note\n\nNo content yet.');

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '● PREVIEW',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AxisColors.tertiary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<double>(
                valueListenable: ReadingPreferencesService().fontScaleNotifier,
                builder: (context, scale, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: ReadingPreferencesService().decreaseScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Text(
                              'A-',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: ReadingPreferencesService().resetScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Text(
                              '${(scale * 100).round()}%',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: ReadingPreferencesService().increaseScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Text(
                              'A+',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Markdown viewer container with live font scale (expands to fill pane height)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle, width: 1),
              ),
              child: SingleChildScrollView(
                child: ValueListenableBuilder<double>(
                  valueListenable: ReadingPreferencesService().fontScaleNotifier,
                  builder: (context, scale, _) {
                    return AxisMarkdownViewer(
                      markdown: markdown,
                      fontScale: scale,
                      onMarkdownChanged: (newMd) {
                        _editorController.text = newMd;
                        _onEditorChanged(newMd);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
