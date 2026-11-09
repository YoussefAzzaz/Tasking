import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/ui/notes/widgets/note_category_selector_field.dart';
import 'package:axis/ui/notes/widgets/note_body_editor.dart';
import 'package:axis/ui/notes/widgets/note_category_customizer.dart';
import 'package:axis/ui/notes/widgets/note_format_selector.dart';
import 'package:axis/ui/notes/services/note_form_service.dart';

export 'package:axis/ui/notes/widgets/note_body_editor.dart';
export 'package:axis/ui/notes/widgets/note_category_customizer.dart';
export 'package:axis/ui/notes/widgets/note_format_selector.dart';
export 'package:axis/ui/notes/services/note_form_service.dart';

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
    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await NoteFormService().saveNote(
        noteToEdit: widget.noteToEdit,
        rawTitle: _titleController.text,
        rawBody: _bodyController.text,
        formatCategory: _category,
        categoryInput: _categoryController.text,
        selectedMood: _selectedMood,
        pinned: _pinned,
        selectedCategoryIcon: _selectedCategoryIcon,
        selectedCategoryColor: _selectedCategoryColor,
        existingCategories: _categories,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onNoteCreated();
      }
    } catch (e) {
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('ArgumentError: ', '');
        setState(() {
          _saving = false;
          _errorText = isAr && msg.contains('Please enter a title or note body')
              ? 'يرجى إدخال عنوان أو محتوى للملاحظة'
              : msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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
                    child: NoteSheetHeader(
                      isEdit: widget.noteToEdit != null,
                      isJournal: _category == 'journal',
                      onClose: () => Navigator.pop(context),
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
                    // Format Selector
                    NoteFormatSelector(
                      selectedCategory: _category,
                      onSelectCategory: (cat) {
                        setState(() {
                          _category = cat;
                          if (cat == 'note') {
                            if (_categoryController.text.trim().isEmpty ||
                                _categoryController.text.toLowerCase() == 'note') {
                              _categoryController.text = 'General';
                            }
                          } else {
                            if (_titleController.text.trim().isEmpty ||
                                _titleController.text.startsWith('Untitled')) {
                              _titleController.text = isArabic
                                  ? 'اليوميات • ${context.formatDate(DateTime.now(), 'EEE, d MMM')}'
                                  : 'Daily Journal • ${DateFormat('EEE, MMM d').format(DateTime.now())}';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Title
                    NoteSectionTitle(label: isArabic ? 'العنوان' : 'TITLE'),
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
                              ? (isArabic
                                  ? 'مثال: المراجعة اليومية وأفكار الصباح'
                                  : 'e.g. Daily Review & Morning Insights')
                              : (isArabic
                                  ? 'مثال: مسودة هيكلية النظام'
                                  : 'e.g. System Architecture Draft'),
                          hintStyle: const TextStyle(color: AxisColors.textDim),
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
                      NoteMoodSelector(
                        selectedMood: _selectedMood,
                        onSelectMood: (m) => setState(() => _selectedMood = m),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Body with markup formatting toolbar and preview toggle
                    NoteBodyEditor(
                      controller: _bodyController,
                      focusNode: _bodyFocusNode,
                      isJournal: _category == 'journal',
                      isExpanded: _isBodyExpanded,
                      previewMode: _previewMode,
                      onToggleExpanded: () =>
                          setState(() => _isBodyExpanded = !_isBodyExpanded),
                      onTogglePreview: () =>
                          setState(() => _previewMode = !_previewMode),
                      onInsertTemplate: () {
                        final template = isArabic
                            ? '### 📅 ماذا حدث اليوم\n- \n\n### 🏆 أهم الإنجازات والانتصارات\n1. \n\n### 💭 أفكار وتأملات\n> '
                            : '### 📅 What Happened Today\n- \n\n### 🏆 Key Wins & Accomplishments\n1. \n\n### 💭 Thoughts & Reflections\n> ';
                        if (_bodyController.text.trim().isEmpty) {
                          _bodyController.text = template;
                        } else {
                          _bodyController.text =
                              '${_bodyController.text}\n\n$template';
                        }
                        setState(() {});
                      },
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Note Category Selector
                    NoteSectionTitle(label: isArabic ? 'الفئة' : 'CATEGORY'),
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
                    if (_isNewCategoryTyped())
                      NoteCategoryCustomizer(
                        selectedColor: _selectedCategoryColor,
                        selectedIcon: _selectedCategoryIcon,
                        onColorChanged: (col) =>
                            setState(() => _selectedCategoryColor = col),
                        onIconChanged: (icon) =>
                            setState(() => _selectedCategoryIcon = icon),
                      ),
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
                        Text(
                          isArabic ? 'تثبيت في أعلى قائمة الملاحظات' : 'Pin to top of notes list',
                          style: const TextStyle(
                              color: AxisColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    NoteSubmitButton(
                      isEdit: widget.noteToEdit != null,
                      isSaving: _saving,
                      onPressed: _saving ? null : _save,
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
