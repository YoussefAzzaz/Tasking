import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/domain/id_generator.dart';

class CreateNoteSheet extends StatefulWidget {
  const CreateNoteSheet({
    super.key,
    required this.onNoteCreated,
    this.initialCategory = 'note',
    this.noteToEdit,
  });

  final VoidCallback onNoteCreated;
  final String initialCategory;
  final Note? noteToEdit;

  @override
  State<CreateNoteSheet> createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends State<CreateNoteSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  late String _category;
  String _selectedMood = 'HIGH ENERGY';
  bool _pinned = false;
  bool _saving = false;
  String? _errorText;

  static const _moods = [
    {'label': 'HIGH ENERGY', 'icon': Icons.bolt_rounded, 'color': AxisColors.warning},
    {'label': 'CALM FOCUS', 'icon': Icons.spa_rounded, 'color': AxisColors.secondary},
    {'label': 'DEEP FLOW', 'icon': Icons.psychology_rounded, 'color': AxisColors.primary},
    {'label': 'RECHARGE', 'icon': Icons.battery_charging_full_rounded, 'color': AxisColors.success},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.noteToEdit != null) {
      final n = widget.noteToEdit!;
      _titleController.text = n.title;
      _bodyController.text = n.bodyMd;
      _category = n.category;
      if (n.mood != null) _selectedMood = n.mood!;
      _pinned = n.pinned;
    } else {
      _category = widget.initialCategory;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
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

    if (widget.noteToEdit != null) {
      final updatedNote = Note(
        id: widget.noteToEdit!.id,
        title: title.isEmpty ? 'Untitled ${DateTime.now().month}/${DateTime.now().day}' : title,
        bodyMd: body,
        category: _category,
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
      category: _category,
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

    return GestureDetector(
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
            // Handle and Header
            Padding(
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
                          onTap: () => setState(() => _category = 'note'),
                        ),
                        const SizedBox(width: 8),
                        _CategoryOption(
                          label: 'Journal',
                          icon: Icons.auto_stories_rounded,
                          isSelected: _category == 'journal',
                          onTap: () => setState(() => _category = 'journal'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    _SectionTitle(label: 'TITLE'),
                    TextField(
                      controller: _titleController,
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

                    // Body
                    _SectionTitle(label: 'CONTENT (MARKDOWN SUPPORTED)'),
                    TextField(
                      controller: _bodyController,
                      maxLines: 6,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AxisColors.textHigh,
                            height: 1.4,
                          ),
                      cursorColor: AxisColors.secondary,
                      decoration: InputDecoration(
                        hintText: _category == 'journal'
                            ? 'How is your energy today? What was accomplished? Any blockers?'
                            : 'Write down thoughts, checklists (- [ ] task), or architectural decisions...',
                        hintStyle: TextStyle(color: AxisColors.textDim),
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
                    const SizedBox(height: 14),

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
