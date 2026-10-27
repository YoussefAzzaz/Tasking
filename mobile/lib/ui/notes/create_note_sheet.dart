import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';
import 'package:axis/ui/common/markdown_list_text_input_formatter.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';
import 'package:axis/ui/notes/widgets/note_category_selector_field.dart';

class CreateNoteSheet extends StatefulWidget {
  const CreateNoteSheet({
    super.key,
    required this.onNoteCreated,
    this.initialCategory = 'General',
    this.existingCategories,
    this.noteToEdit,
  });

  final VoidCallback onNoteCreated;
  final String initialCategory;
  final List<NoteCategory>? existingCategories;
  final Note? noteToEdit;

  @override
  State<CreateNoteSheet> createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends State<CreateNoteSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _categoryController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();
  final _categoryFocusNode = FocusNode();

  late String _category; // 'note' or 'journal'
  bool _showCategoryDropdown = false;
  List<NoteCategory> _categories = [];
  String _selectedCategoryColor = '#38BDF8';
  String _selectedCategoryIcon = 'article';

  String _selectedMood = 'HIGH ENERGY';
  bool _pinned = false;
  bool _saving = false;
  bool _previewMode = false;
  bool _isBodyExpanded = false;
  String? _errorText;

  static const _moods = [
    {'label': 'HIGH ENERGY', 'icon': Icons.bolt_rounded, 'color': AxisColors.warning},
    {'label': 'CALM FOCUS', 'icon': Icons.spa_rounded, 'color': AxisColors.secondary},
    {'label': 'DEEP FLOW', 'icon': Icons.psychology_rounded, 'color': AxisColors.primary},
    {'label': 'RECHARGE', 'icon': Icons.battery_charging_full_rounded, 'color': AxisColors.success},
  ];

  static const _categoryIconOptions = [
    {'name': 'article', 'icon': Icons.article_rounded},
    {'name': 'work', 'icon': Icons.work_rounded},
    {'name': 'idea', 'icon': Icons.lightbulb_rounded},
    {'name': 'study', 'icon': Icons.school_rounded},
    {'name': 'star', 'icon': Icons.star_rounded},
    {'name': 'bookmark', 'icon': Icons.bookmark_rounded},
    {'name': 'code', 'icon': Icons.terminal_rounded},
    {'name': 'checklist', 'icon': Icons.checklist_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    if (widget.noteToEdit != null) {
      final n = widget.noteToEdit!;
      _titleController.text = n.title;
      _bodyController.text = n.bodyMd;
      if (n.bodyMd.trim().isNotEmpty) {
        _isBodyExpanded = true;
      }
      final isJ = n.category.toLowerCase() == 'journal';
      _category = isJ ? 'journal' : 'note';
      if (!isJ &&
          n.category.trim().isNotEmpty &&
          n.category.toLowerCase() != 'note' &&
          n.category.toLowerCase() != 'general notes') {
        _categoryController.text = n.category.trim();
      } else if (!isJ) {
        _categoryController.text = 'General';
      }
      if (n.mood != null) _selectedMood = n.mood!;
      _pinned = n.pinned;
    } else {
      final isJ = widget.initialCategory.toLowerCase() == 'journal';
      _category = isJ ? 'journal' : 'note';
      if (!isJ) {
        if (widget.initialCategory.trim().isNotEmpty &&
            widget.initialCategory.toLowerCase() != 'note' &&
            widget.initialCategory.toLowerCase() != 'general notes' &&
            widget.initialCategory.toLowerCase() != 'all') {
          _categoryController.text = widget.initialCategory.trim();
        } else {
          _categoryController.text = 'General';
        }
      }
      if (_category == 'journal') {
        _titleController.text =
            'Daily Journal • ${DateFormat('EEE, MMM d').format(DateTime.now())}';
      }
    }

    _loadCategories();

    _categoryFocusNode.addListener(() {
      if (_categoryFocusNode.hasFocus) {
        setState(() => _showCategoryDropdown = true);
      }
    });

    _bodyFocusNode.addListener(() {
      if (_bodyFocusNode.hasFocus) {
        if (!_isBodyExpanded) {
          setState(() {
            _isBodyExpanded = true;
          });
        }
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final list = await NoteCategoryRepository().getCategories(forceRefresh: true);
      if (mounted) {
        setState(() {
          final merged = <NoteCategory>[...list];
          final names = merged.map((c) => c.name.toLowerCase()).toSet();
          if (widget.existingCategories != null) {
            for (final ec in widget.existingCategories!) {
              if (!names.contains(ec.name.toLowerCase())) {
                names.add(ec.name.toLowerCase());
                merged.add(ec);
              }
            }
          }
          _categories = merged;
          if (_categoryController.text.trim().isNotEmpty) {
            final cat = _categoryController.text.trim().toLowerCase();
            final match = _categories.firstWhere(
              (c) => c.name.toLowerCase() == cat,
              orElse: () => const NoteCategory(id: '', name: ''),
            );
            if (match.name.isNotEmpty) {
              _selectedCategoryIcon = match.icon;
              _selectedCategoryColor = match.color;
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _categoryController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  bool _isNewCategoryTyped() {
    final text = _categoryController.text.trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (lower == 'general notes' || lower == 'note' || lower == 'journal' || lower == 'all') {
      return false;
    }
    return !_categories.any((c) => c.name.toLowerCase() == lower);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty && body.isEmpty) {
      setState(() => _errorText = 'Please enter a title or note body');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final categoryName = _categoryController.text.trim();
    if (categoryName.isNotEmpty &&
        categoryName.toLowerCase() != 'general notes' &&
        categoryName.toLowerCase() != 'note' &&
        categoryName.toLowerCase() != 'all') {
      final exists = _categories.any(
        (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      );
      if (!exists) {
        await NoteCategoryRepository().addCategory(
          name: categoryName,
          icon: _selectedCategoryIcon,
          color: _selectedCategoryColor,
        );
      }
    }

    final effectiveCategory = categoryName.isNotEmpty
        ? categoryName
        : (_category == 'journal' ? 'journal' : 'General');

    if (widget.noteToEdit != null) {
      final updatedNote = Note(
        id: widget.noteToEdit!.id,
        title: title.isEmpty ? 'Untitled ${DateTime.now().month}/${DateTime.now().day}' : title,
        bodyMd: body,
        category: effectiveCategory,
        mood: _category == 'journal' ? _selectedMood : null,
        pinned: _pinned,
        createdAt: widget.noteToEdit!.createdAt,
      );

      await NoteRepository().updateNote(updatedNote);

      if (mounted) {
        Navigator.pop(context);
        widget.onNoteCreated();
      }
      return;
    }

    final note = Note(
      id: IdGenerator.generateDeterministicId(
          'note_${DateTime.now().microsecondsSinceEpoch}_$title'),
      title: title.isEmpty ? 'Untitled ${DateTime.now().month}/${DateTime.now().day}' : title,
      bodyMd: body,
      category: effectiveCategory,
      mood: _category == 'journal' ? _selectedMood : null,
      pinned: _pinned,
    );

    await NoteRepository().addNote(note);

    if (mounted) {
      Navigator.pop(context);
      widget.onNoteCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return FocusScope(
      autofocus: false,
      child: ModalSheetScaffold(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: EdgeInsets.only(bottom: insets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              decoration: BoxDecoration(
                color: const Color(0xF50C1626),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle and Header (tap to close automatically)
                  ModalSheetTopBar(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AxisColors.borderGlass2,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AxisColors.secondary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.edit_note_rounded,
                                        color: AxisColors.secondary, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    widget.noteToEdit != null
                                        ? (_category == 'journal' ? 'EDIT JOURNAL ENTRY' : 'EDIT NOTE')
                                        : (_category == 'journal' ? 'NEW JOURNAL ENTRY' : 'NEW NOTE'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AxisColors.textHigh,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AxisColors.textMuted, size: 22),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: AxisColors.borderSubtle, height: 1),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Selector
                    _SectionTitle(label: 'FORMAT'),
                    Row(
                      children: [
                        _CategoryOption(
                          label: 'Note',
                          icon: Icons.article_rounded,
                          isSelected: _category == 'note',
                          onTap: () {
                            setState(() {
                              _category = 'note';
                              if (_categoryController.text.trim().isEmpty ||
                                  _categoryController.text.toLowerCase() == 'note') {
                                _categoryController.text = 'General';
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryOption(
                          label: 'Journal',
                          icon: Icons.auto_stories_rounded,
                          isSelected: _category == 'journal',
                          onTap: () {
                            setState(() {
                              _category = 'journal';
                              if (_titleController.text.trim().isEmpty ||
                                  _titleController.text.startsWith('Untitled')) {
                                _titleController.text =
                                    'Daily Journal • ${DateFormat('EEE, MMM d').format(DateTime.now())}';
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    _SectionTitle(label: 'TITLE'),
                    AutoDirectionScope(
                      controller: _titleController,
                      child: TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        autofocus: false,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AxisColors.textHigh,
                              fontWeight: FontWeight.w600,
                            ),
                        cursorColor: AxisColors.secondary,
                        decoration: InputDecoration(
                          hintText: _category == 'journal'
                              ? 'e.g. Daily Review & Morning Insights'
                              : 'e.g. System Architecture Draft',
                          hintStyle: TextStyle(color: AxisColors.textDim),
                          errorText: _errorText,
                          filled: true,
                          fillColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AxisColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AxisColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AxisColors.secondary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mood selector (if journal)
                    if (_category == 'journal') ...[
                      _SectionTitle(label: 'ENERGY & MOOD STATE'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _moods.map((m) {
                          final isSel = _selectedMood == m['label'];
                          final color = m['color'] as Color;
                          return InkWell(
                            onTap: () => setState(
                                () => _selectedMood = m['label'] as String),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? color.withValues(alpha: 0.25)
                                    : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSel ? color : AxisColors.borderSubtle,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(m['icon'] as IconData,
                                      size: 14, color: color),
                                  const SizedBox(width: 6),
                                  Text(
                                    m['label'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSel ? color : AxisColors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Body with markup formatting toolbar and preview toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _SectionTitle(label: 'CONTENT (MARKDOWN & LISTS)'),
                        Row(
                          children: [
                            if (_category == 'journal')
                              Padding(
                                padding: const EdgeInsets.only(right: 6, bottom: 8),
                                child: InkWell(
                                  onTap: () {
                                    const template = '### 📅 What Happened Today\n- \n\n### 🏆 Key Wins & Accomplishments\n1. \n\n### 💭 Thoughts & Reflections\n> ';
                                    if (_bodyController.text.trim().isEmpty) {
                                      _bodyController.text = template;
                                    } else {
                                      _bodyController.text = '${_bodyController.text}\n\n$template';
                                    }
                                    setState(() {});
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AxisColors.secondary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AxisColors.secondary
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.playlist_add_rounded,
                                            size: 13,
                                            color: AxisColors.secondary),
                                        SizedBox(width: 4),
                                        Text(
                                          'Template',
                                          style: TextStyle(
                                            color: AxisColors.secondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    key: const ValueKey('note_expand_toggle'),
                                    onTap: () => setState(
                                        () => _isBodyExpanded = !_isBodyExpanded),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _isBodyExpanded
                                            ? AxisColors.secondary
                                                .withValues(alpha: 0.25)
                                            : AxisColors.surfaceHigh
                                                .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _isBodyExpanded
                                              ? AxisColors.secondary
                                              : AxisColors.borderSubtle,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isBodyExpanded
                                                ? Icons.unfold_less_rounded
                                                : Icons.unfold_more_rounded,
                                            size: 13,
                                            color: _isBodyExpanded
                                                ? AxisColors.secondary
                                                : AxisColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isBodyExpanded ? 'Compact' : 'Expand',
                                            style: TextStyle(
                                              color: _isBodyExpanded
                                                  ? AxisColors.secondary
                                                  : AxisColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _previewMode = !_previewMode),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _previewMode
                                            ? AxisColors.secondary
                                                .withValues(alpha: 0.25)
                                            : AxisColors.surfaceHigh
                                                .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _previewMode
                                              ? AxisColors.secondary
                                              : AxisColors.borderSubtle,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _previewMode
                                                ? Icons.edit_note_rounded
                                                : Icons.visibility_outlined,
                                            size: 13,
                                            color: _previewMode
                                                ? AxisColors.secondary
                                                : AxisColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _previewMode ? 'Edit' : 'Preview',
                                            style: TextStyle(
                                              color: _previewMode
                                                  ? AxisColors.secondary
                                                  : AxisColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (!_previewMode) ...[
                      NoteFormatToolbar(
                        controller: _bodyController,
                        focusNode: _bodyFocusNode,
                        onChanged: () => setState(() {}),
                      ),
                      AutoDirectionScope(
                        controller: _bodyController,
                        child: TextField(
                          controller: _bodyController,
                          focusNode: _bodyFocusNode,
                          autofocus: false,
                          minLines: _isBodyExpanded ? 10 : 4,
                          maxLines: _isBodyExpanded ? 26 : 7,
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          onTap: () {
                            if (!_isBodyExpanded) {
                              setState(() => _isBodyExpanded = true);
                            }
                          },
                          inputFormatters: const [
                            MarkdownListTextInputFormatter(),
                          ],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AxisColors.textHigh,
                                height: 1.4,
                              ),
                          cursorColor: AxisColors.secondary,
                          decoration: InputDecoration(
                            hintText: _category == 'journal'
                                ? 'Log events (e.g. **14:00** - Event), what happened, accomplishments, blockers...'
                                : 'Write notes, ordered lists (1. ), bullet points (- ), or checklists (- [ ] )...',
                            hintStyle: TextStyle(color: AxisColors.textDim),
                            filled: true,
                            fillColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AxisColors.borderSubtle),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AxisColors.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AxisColors.secondary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: _isBodyExpanded ? 240 : 140,
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AxisColors.secondary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: AxisMarkdownViewer(
                          markdown: _bodyController.text,
                          onMarkdownChanged: (updatedBody) {
                            setState(() => _bodyController.text = updatedBody);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Note Category Selector
                    _SectionTitle(label: 'CATEGORY'),
                    NoteCategorySelectorField(
                      controller: _categoryController,
                      focusNode: _categoryFocusNode,
                      categories: _categories,
                      isOpen: _showCategoryDropdown,
                      onOpenChanged: (open) => setState(() => _showCategoryDropdown = open),
                      onSelectCategory: (name, icon, color) {
                        setState(() {
                          _categoryController.text = name;
                          _selectedCategoryIcon = icon;
                          _selectedCategoryColor = color;
                          _showCategoryDropdown = false;
                        });
                      },
                      onClear: () {
                        setState(() {
                          _categoryController.clear();
                          _showCategoryDropdown = false;
                        });
                      },
                    ),
                    if (_isNewCategoryTyped()) ...[
                      const SizedBox(height: 12),
                      _SectionTitle(label: 'NEW CATEGORY COLOR & ICON'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...['#38BDF8', '#10B981', '#6366F1', '#F59E0B', '#EC4899', '#A855F7'].map((hex) {
                            final isSel = _selectedCategoryColor.toUpperCase() == hex.toUpperCase();
                            final col = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                            return InkWell(
                              onTap: () => setState(() => _selectedCategoryColor = hex),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: col,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? Colors.white : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: isSel
                                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                    : null,
                              ),
                            );
                          }),
                          RainbowColorPickerButton(
                            selectedColor: _selectedCategoryColor,
                            size: 30,
                            borderWidth: 2,
                            onColorSelected: (col) => setState(() => _selectedCategoryColor = col),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryIconOptions.map((item) {
                          final name = item['name'] as String;
                          final icon = item['icon'] as IconData;
                          final isSel = _selectedCategoryIcon == name;
                          return InkWell(
                            onTap: () => setState(() => _selectedCategoryIcon = name),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AxisColors.secondary.withValues(alpha: 0.25)
                                    : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel ? AxisColors.secondary : AxisColors.borderSubtle,
                                ),
                              ),
                              child: Icon(icon, size: 16, color: isSel ? AxisColors.secondary : AxisColors.textDim),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Pin Option
                    Row(
                      children: [
                        Checkbox(
                          value: _pinned,
                          activeColor: AxisColors.secondary,
                          side: const BorderSide(color: AxisColors.borderSubtle),
                          onChanged: (v) => setState(() => _pinned = v ?? false),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Pin to top of notes list',
                          style: TextStyle(
                              color: AxisColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    InkWell(
                      onTap: _saving ? null : _save,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AxisColors.secondary, Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AxisColors.secondary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bookmark_added_rounded,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.noteToEdit != null ? 'UPDATE ENTRY' : 'SAVE ENTRY',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
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
          ],
        ),
      ),
    ),
  ),
),
);
}
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AxisColors.secondary.withValues(alpha: 0.22)
                : AxisColors.surfaceHigh.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AxisColors.secondary : AxisColors.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? AxisColors.secondary : AxisColors.textDim),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AxisColors.textHigh : AxisColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AxisColors.textMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
