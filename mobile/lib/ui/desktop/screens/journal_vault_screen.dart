import 'dart:async';
import 'package:flutter/material.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';
import '../../../core/l10n/app_localizations.dart';

import '../../../data/note_repository.dart';
import '../../../domain/id_generator.dart';
import '../core/desktop_layout.dart';
import '../services/desktop_file_service.dart';
import 'journal/journal_vault_header.dart';
import 'journal/journal_vault_navigator_pane.dart';
import 'journal/journal_markdown_editor_pane.dart';
import 'journal/journal_live_preview_pane.dart';

export 'journal/journal_deck_streak_calendar.dart';
export 'journal/journal_vault_header.dart';
export 'journal/journal_vault_navigator_pane.dart';
export 'journal/journal_markdown_editor_pane.dart';
export 'journal/journal_live_preview_pane.dart';

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
    setState(() {});
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
      final isAr = AppLocalizations.of(context).isArabic;
      setState(() {
        _isCreating = false;
        _selectedNote = newNote;
        _titleController.text = newNote.title;
        _editorController.text = newNote.bodyMd;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isJournal
              ? (isAr ? 'تم حفظ تدوينة اليوميات' : 'Journal entry saved')
              : (isAr ? 'تم حفظ الملاحظة في الخزينة' : 'Note saved to Vault')),
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
      final isAr = AppLocalizations.of(context).isArabic;
      setState(() => _selectedNote = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_activeTab == 'journal'
              ? (isAr ? 'تم حفظ اليومية' : 'Journal saved')
              : (isAr ? 'تم حفظ الملاحظة في الخزينة' : 'Note saved to Vault')),
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
      final isAr = AppLocalizations.of(context).isArabic;
      setState(() {
        _selectedNote = null;
        _isCreating = false;
        _titleController.clear();
        _editorController.clear();
      });
      AxisSnackBar.showDeleted(
        context,
        itemTitle: isAr ? 'العنصر' : 'Entry',
        itemType: _activeTab == 'journal' ? (isAr ? 'اليومية' : 'Journal') : (isAr ? 'الملاحظة' : 'Note'),
      );
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
      final isAr = AppLocalizations.of(context).isArabic;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم التصدير إلى $path' : 'Exported to $path')),
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
              JournalVaultHeader(
                selectedNote: _selectedNote,
                isCreating: _isCreating,
                activeTab: _activeTab,
                editorText: _editorController.text,
                onTogglePin: _handleTogglePin,
                onDeleteSelectedNote: _handleDeleteSelectedNote,
                onExportMarkdown: _handleExportMarkdown,
                onStartNewEntry: (tab) => _handleStartNewEntry(category: tab),
                onShareSelectedNote: _selectedNote != null
                    ? () => ShareTaskSheet.showForNote(context, _selectedNote!)
                    : null,
              ),
              const SizedBox(height: DesktopLayout.sectionSpacing),

              // 6.1 3-Column Split: Navigator (3) | Editor (4) | Preview (4)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: JournalVaultNavigatorPane(
                        activeTab: _activeTab,
                        selectedCategoryFilter: _selectedCategoryFilter,
                        searchQuery: _searchQuery,
                        searchController: _searchController,
                        vaultScrollController: _vaultScrollController,
                        selectedNote: _selectedNote,
                        onSwitchTab: _switchTab,
                        onSelectCategoryFilter: (cat) => setState(() => _selectedCategoryFilter = cat),
                        onSearchChanged: (val) => setState(() => _searchQuery = val),
                        onSelectNote: _selectNote,
                        onStartNewEntry: (cat) => _handleStartNewEntry(category: cat),
                      ),
                    ),
                    const SizedBox(width: DesktopLayout.sectionSpacing),
                    Expanded(
                      flex: 4,
                      child: JournalMarkdownEditorPane(
                        selectedNote: _selectedNote,
                        isCreating: _isCreating,
                        activeTab: _activeTab,
                        creatingCategory: _creatingCategory,
                        titleController: _titleController,
                        editorController: _editorController,
                        editorFocusNode: _editorFocusNode,
                        onTitleChanged: _onTitleChanged,
                        onEditorChanged: _onEditorChanged,
                        onSaveEditor: _handleSaveEditor,
                        onUpdateCategory: _handleUpdateCategory,
                        onCreatingCategoryChanged: (cat) => setState(() => _creatingCategory = cat),
                      ),
                    ),
                    const SizedBox(width: DesktopLayout.sectionSpacing),
                    Expanded(
                      flex: 4,
                      child: JournalLivePreviewPane(
                        editorText: _editorController.text,
                        selectedNote: _selectedNote,
                        onMarkdownChanged: (newMd) {
                          _editorController.text = newMd;
                          _onEditorChanged(newMd);
                        },
                      ),
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
}
