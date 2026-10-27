import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../data/note_repository.dart';
import '../../../domain/id_generator.dart';
import '../../common/axis_markdown_viewer.dart';
import '../core/desktop_layout.dart';
import '../services/desktop_file_service.dart';
import '../widgets/accent_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_pressable.dart';
import '../widgets/ghost_button.dart';
import '../widgets/telemetry_chip.dart';
import '../widgets/undo_snackbar.dart';

/// Journal & Vault Screen (Tab 4) — 3-column Markdown knowledge base and personal vault.
class JournalVaultScreen extends StatefulWidget {
  const JournalVaultScreen({super.key});

  @override
  State<JournalVaultScreen> createState() => _JournalVaultScreenState();
}

class _JournalVaultScreenState extends State<JournalVaultScreen> {
  Note? _selectedNote;
  final _searchController = TextEditingController();
  final _editorController = TextEditingController();
  String _activeTab = 'notes'; // 'notes' or 'journal'
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _editorController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _selectNote(Note note) {
    _debounceTimer?.cancel();
    setState(() {
      _selectedNote = note;
      _editorController.text = note.bodyMd;
    });
  }

  void _onEditorChanged(String text) {
    if (_selectedNote == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (_selectedNote != null) {
        final updated = _selectedNote!.copyWith(bodyMd: text);
        await NoteRepository().updateNote(updated);
        if (mounted) setState(() => _selectedNote = updated);
      }
    });
    setState(() {}); // Updates live preview immediately
  }

  Future<void> _handleCreateNewNote({required String category}) async {
    final newNote = Note(
      id: IdGenerator.generateDeterministicId('note_${DateTime.now().microsecondsSinceEpoch}'),
      title: category == 'journal' ? 'Journal Entry' : 'Untitled Architecture Note',
      bodyMd: '# Overview\n\n- [ ] Initial requirements defined\n- [ ] Implementation completed\n\nEnter notes here...',
      category: category,
    );
    await NoteRepository().addNote(newNote);
    _selectNote(newNote);
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

  void _insertFormatting(String prefix, String suffix) {
    final selection = _editorController.selection;
    final text = _editorController.text;
    final selectedText = selection.textInside(text);
    final replacement = '$prefix$selectedText$suffix';

    final newText = text.replaceRange(selection.start, selection.end, replacement);
    _editorController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length + selectedText.length,
      ),
    );
    _onEditorChanged(newText);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 6.2 Page Header
          _buildPageHeader(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 6.1 3-Column Split: Navigator (3) | Editor (4) | Preview (4)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    final note = _selectedNote;
    final words = note != null
        ? note.bodyMd.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length
        : 0;
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
                    'Knowledge Base / Notes / ',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: AxisColors.textDim,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      note != null ? note.title : 'Overview',
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
                note?.title ?? 'Vault & Architecture Notes',
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
            if (note != null) ...[
              GhostButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                color: AxisColors.priorityHigh,
                borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
                onPressed: () async {
                  final title = note.title.trim().isEmpty ? 'Untitled note' : note.title.trim();
                  final confirmed = await ConfirmDialog.show(
                    context,
                    title: 'Delete note?',
                    message:
                        '"$title" will be permanently removed from your vault. You can undo for a few seconds after deleting.',
                  );
                  if (!confirmed) return;

                  final snapshot = note; // captured for undo
                  await NoteRepository().deleteNote(snapshot.id);
                  setState(() {
                    _selectedNote = null;
                    _editorController.clear();
                  });
                  if (!mounted) return;
                  showUndoSnackBar(
                    context,
                    message: 'Note deleted',
                    onUndo: () => NoteRepository().addNote(snapshot),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            GhostButton(
              label: 'Export .md',
              icon: Icons.file_download_outlined,
              onPressed: note != null ? _handleExportMarkdown : null,
            ),
            const SizedBox(width: 8),
            AccentButton(
              label: '+ New Note',
              icon: Icons.add_rounded,
              onPressed: () => _handleCreateNewNote(category: _activeTab),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteNavigatorPane() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab Switcher
          Row(
            children: [
              Expanded(
                child: DesktopPressable(
                  role: DesktopPressableRole.tab,
                  selected: _activeTab == 'notes',
                  label: 'Notes',
                  onActivate: () => setState(() => _activeTab = 'notes'),
                  builder: (context, visuals) {
                    final active = _activeTab == 'notes';
                    final hovered = visuals.hovered || visuals.pressed;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? AxisColors.primary.withValues(alpha: 0.2)
                            : hovered
                                ? AxisColors.surfaceHigh.withValues(alpha: 0.35)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: active ? AxisColors.primary : AxisColors.borderSubtle,
                          width: 1,
                        ),
                        boxShadow: desktopFocusRing(visuals.focused),
                      ),
                      child: Center(
                        child: Text(
                          '≡ Notes',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active ? AxisColors.textHigh : AxisColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DesktopPressable(
                  role: DesktopPressableRole.tab,
                  selected: _activeTab == 'journal',
                  label: 'Journals',
                  onActivate: () => setState(() => _activeTab = 'journal'),
                  builder: (context, visuals) {
                    final active = _activeTab == 'journal';
                    final hovered = visuals.hovered || visuals.pressed;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? AxisColors.primary.withValues(alpha: 0.2)
                            : hovered
                                ? AxisColors.surfaceHigh.withValues(alpha: 0.35)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: active ? AxisColors.primary : AxisColors.borderSubtle,
                          width: 1,
                        ),
                        boxShadow: desktopFocusRing(visuals.focused),
                      ),
                      child: Center(
                        child: Text(
                          'Journals',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active ? AxisColors.textHigh : AxisColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search input
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textHigh),
              decoration: InputDecoration(
                icon: const Icon(Icons.search_rounded, size: 14, color: AxisColors.textDim),
                hintText: 'Search notes & tags...',
                hintStyle: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Vault hierarchy section
          Text(
            'VAULT HIERARCHY',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AxisColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Note>>(
            stream: NoteRepository().watchNotes(category: _activeTab == 'notes' ? null : 'journal'),
            builder: (context, snapshot) {
              final allNotes = snapshot.data ?? [];
              final filtered = _searchQuery.isEmpty
                  ? allNotes
                  : allNotes.where((n) =>
                      n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      n.bodyMd.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'No entries found',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              // Auto-select first note if null
              if (_selectedNote == null && filtered.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedNote == null) {
                    _selectNote(filtered.first);
                  }
                });
              }

              return Column(
                children: filtered.map((n) {
                  final isSelected = _selectedNote?.id == n.id;
                  return DesktopPressable(
                    role: DesktopPressableRole.listItem,
                    selected: isSelected,
                    label: n.title.isEmpty ? 'Untitled note' : n.title,
                    onActivate: () => _selectNote(n),
                    builder: (context, visuals) {
                      final hovered = visuals.hovered || visuals.pressed;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AxisColors.primary.withValues(alpha: 0.16)
                              : hovered
                                  ? AxisColors.surfaceLowest
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? AxisColors.primary
                                : (hovered ? AxisColors.borderGlass2 : Colors.transparent),
                            width: 1,
                          ),
                          boxShadow: desktopFocusRing(visuals.focused),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              n.category == 'journal' ? Icons.book_outlined : Icons.description_outlined,
                              size: 15,
                              color: isSelected ? AxisColors.secondary : AxisColors.textDim,
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
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 18),

          // Mini Streak Calendar
          Container(
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
                          '42d Streak',
                          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.warning),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final isToday = i == 6;
                    return Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isToday ? AxisColors.secondary : AxisColors.secondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${18 + i}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isToday ? AxisColors.canvasBase : AxisColors.secondary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
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
              Text(
                '⚡ MARKDOWN EDITOR',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AxisColors.secondary,
                ),
              ),
              const TelemetryChip(
                label: 'AUTO-SAVED',
                color: AxisColors.tertiary,
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Format Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                _buildToolbarBtn('B', () => _insertFormatting('**', '**')),
                _buildToolbarBtn('/', () => _insertFormatting('*', '*')),
                _buildToolbarBtn('H1', () => _insertFormatting('# ', '')),
                _buildToolbarBtn('H2', () => _insertFormatting('## ', '')),
                _buildToolbarBtn('`', () => _insertFormatting('`', '`')),
                _buildToolbarBtn('[]', () => _insertFormatting('- [ ] ', '')),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Editor text area
          Container(
            height: 480,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: _editorController,
              onChanged: _onEditorChanged,
              maxLines: null,
              expands: true,
              style: GoogleFonts.firaCode(
                fontSize: 13,
                height: 1.5,
                color: AxisColors.textHigh,
              ),
              decoration: InputDecoration(
                hintText: '# Title\n\nBegin drafting your architectural breakdown or journal log...',
                hintStyle: GoogleFonts.firaCode(fontSize: 13, color: AxisColors.textDim),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarBtn(String label, VoidCallback onTap) {
    return DesktopPressable(
      label: 'Format $label',
      tooltip: 'Insert $label',
      onActivate: onTap,
      builder: (context, visuals) {
        final active = visuals.hovered || visuals.pressed;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? AxisColors.surfaceHigh.withValues(alpha: 0.5)
                : AxisColors.surfaceHigh.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            boxShadow: desktopFocusRing(visuals.focused),
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
          ),
        );
      },
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
              Text(
                '● LIVE PREVIEW',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AxisColors.tertiary,
                ),
              ),
              const TelemetryChip(
                label: 'READ-ONLY RENDER',
                color: AxisColors.textDim,
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Markdown viewer container
          Container(
            height: 480,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: SingleChildScrollView(
              child: AxisMarkdownViewer(
                markdown: markdown,
                onMarkdownChanged: (newMd) {
                  _editorController.text = newMd;
                  _onEditorChanged(newMd);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
