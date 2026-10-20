import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/common/axis_sliding_segmented_bar.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _repo = NoteRepository();
  int _selectedSegmentIndex = 0; // 0: 'all', 1: 'note', 2: 'journal'
  DateTime? _filterDate;

  static const _segmentKeys = ['all', 'note', 'journal'];
  static const _segmentLabels = ['All Notes', 'Notes', 'Journal'];

  String get _selectedSegment => _segmentKeys[_selectedSegmentIndex];

  void _openCreateNote({String category = 'note'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateNoteSheet(
        initialCategory: category,
        onNoteCreated: () => setState(() {}),
      ),
    );
  }

  void _showNoteDetail(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xF50C1626),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AxisColors.borderGlass2,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        note.category == 'journal'
                            ? Icons.auto_stories_rounded
                            : Icons.article_rounded,
                        color: AxisColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        note.category.toUpperCase(),
                        style: const TextStyle(
                          color: AxisColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AxisColors.secondary, size: 20),
                        tooltip: 'Edit Entry',
                        onPressed: () {
                          Navigator.pop(ctx);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => CreateNoteSheet(
                              noteToEdit: note,
                              onNoteCreated: () => setState(() {}),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AxisColors.error, size: 20),
                        tooltip: 'Delete Entry',
                        onPressed: () {
                          _repo.deleteNote(note.id);
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AxisColors.textHigh,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, d MMM yyyy • HH:mm').format(note.createdAt),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AxisColors.textMuted),
              ),
              if (note.mood != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AxisColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AxisColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 14, color: AxisColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        note.mood!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(color: AxisColors.borderSubtle, height: 28),
              Text(
                note.bodyMd.isEmpty
                    ? 'No additional notes provided.'
                    : note.bodyMd,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AxisColors.textHigh,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CreateNoteSheet(
                        noteToEdit: note,
                        onNoteCreated: () => setState(() {}),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Entry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AxisColors.secondary,
                    side: const BorderSide(color: AxisColors.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: AxisTheme.dark.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AxisColors.secondary,
              onPrimary: Colors.black,
              surface: AxisColors.surfaceHigh,
              onSurface: AxisColors.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) {
      return 'Today • ${DateFormat('EEEE, MMM d').format(date)}';
    } else if (diff == 1) {
      return 'Yesterday • ${DateFormat('EEEE, MMM d').format(date)}';
    } else if (diff == -1) {
      return 'Tomorrow • ${DateFormat('EEEE, MMM d').format(date)}';
    } else if (date.year == now.year) {
      return DateFormat('EEEE, MMM d').format(date);
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    }
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
                        'Notes & Journal',
                        style: Theme.of(context).textTheme.displaySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Markdown logs & daily reflections',
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
                      category: _selectedSegment == 'journal' ? 'journal' : 'note'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AxisColors.secondary, Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.secondary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'New Entry',
                          style: TextStyle(
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

          // Smooth sliding segmented bar: All Notes | Notes | Journal (Voice removed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AxisSlidingSegmentedBar(
              segments: _segmentLabels,
              selectedIndex: _selectedSegmentIndex,
              activeColor: AxisColors.secondary,
              activeGradient: const LinearGradient(
                colors: [AxisColors.secondary, Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onSegmentSelected: (index) {
                setState(() => _selectedSegmentIndex = index);
              },
            ),
          ),
          const SizedBox(height: 14),

          // Date Filter Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Active / Pick Date filter button
                InkWell(
                  onTap: _pickFilterDate,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filterDate != null
                          ? AxisColors.secondary.withValues(alpha: 0.2)
                          : AxisColors.surfaceHigh.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _filterDate != null
                            ? AxisColors.secondary
                            : AxisColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: _filterDate != null
                              ? AxisColors.secondary
                              : AxisColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _filterDate != null
                              ? DateFormat('d MMM yyyy').format(_filterDate!)
                              : 'Filter by Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _filterDate != null
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _filterDate != null
                                ? AxisColors.textHigh
                                : AxisColors.textMuted,
                          ),
                        ),
                        if (_filterDate != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _filterDate = null),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: AxisColors.secondary),
                          ),
                        ] else ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down_rounded,
                              size: 16, color: AxisColors.textDim),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Quick Today Chip
                _QuickDateChip(
                  label: 'Today',
                  isSelected: _filterDate != null &&
                      _isSameDay(_filterDate!, DateTime.now()),
                  onTap: () {
                    final today = DateTime.now();
                    setState(() {
                      if (_filterDate != null &&
                          _isSameDay(_filterDate!, today)) {
                        _filterDate = null;
                      } else {
                        _filterDate = today;
                      }
                    });
                  },
                ),
                const SizedBox(width: 6),

                // Quick Yesterday Chip
                _QuickDateChip(
                  label: 'Yesterday',
                  isSelected: _filterDate != null &&
                      _isSameDay(
                          _filterDate!,
                          DateTime.now().subtract(const Duration(days: 1))),
                  onTap: () {
                    final yest =
                        DateTime.now().subtract(const Duration(days: 1));
                    setState(() {
                      if (_filterDate != null &&
                          _isSameDay(_filterDate!, yest)) {
                        _filterDate = null;
                      } else {
                        _filterDate = yest;
                      }
                    });
                  },
                ),
                if (_filterDate != null) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _filterDate = null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Show All',
                        style: TextStyle(
                            color: AxisColors.secondary, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Daily Review Prompt Card (when in All or Journal view)
          if (_selectedSegment == 'all' || _selectedSegment == 'journal')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AxisCard(
                tier: GlassTier.two,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_rounded,
                                color: AxisColors.warning, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'DAILY REVIEW PROMPT',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AxisColors.warning,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ],
                        ),
                        Text(
                          DateFormat('d MMM').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AxisColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '"What single accomplishment will make today feel like a victory?"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AxisColors.textHigh,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _openCreateNote(category: 'journal'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Tap to record your energy & thoughts...',
                                style: TextStyle(
                                    color: AxisColors.textDim, fontSize: 12)),
                            Icon(Icons.arrow_forward_rounded,
                                size: 14, color: AxisColors.secondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Notes List separated by Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<Note>>(
              stream: _repo.watchNotes(category: _selectedSegment),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child:
                          CircularProgressIndicator(color: AxisColors.secondary),
                    ),
                  );
                }

                var notes = snapshot.data ?? [];

                // Filter by date if filter active
                if (_filterDate != null) {
                  notes = notes
                      .where((n) => _isSameDay(n.createdAt, _filterDate!))
                      .toList();
                }

                if (notes.isEmpty) {
                  return AxisCard(
                    tier: GlassTier.two,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.notes_rounded,
                              size: 40, color: AxisColors.textDim),
                          const SizedBox(height: 8),
                          Text(
                            _filterDate != null
                                ? 'No entries found for ${DateFormat.yMMMd().format(_filterDate!)}'
                                : 'No entries in this view',
                            style: const TextStyle(color: AxisColors.textDim),
                          ),
                          const SizedBox(height: 12),
                          if (_filterDate != null)
                            OutlinedButton(
                              onPressed: () =>
                                  setState(() => _filterDate = null),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AxisColors.secondary),
                              ),
                              child: const Text('Clear Date Filter',
                                  style:
                                      TextStyle(color: AxisColors.secondary)),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => _openCreateNote(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create New Entry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AxisColors.secondary,
                                foregroundColor: Colors.black,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                // Group notes by calendar date
                final Map<DateTime, List<Note>> grouped = {};
                for (final note in notes) {
                  final key = DateTime(
                    note.createdAt.year,
                    note.createdAt.month,
                    note.createdAt.day,
                  );
                  grouped.putIfAbsent(key, () => []).add(note);
                }

                // Sort dates descending
                final sortedDates = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedDates.map((date) {
                    final dayNotes = grouped[date]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Group Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AxisColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDateHeader(date).toUpperCase(),
                                    style: const TextStyle(
                                      color: AxisColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AxisColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: AxisColors.borderSubtle),
                                ),
                                child: Text(
                                  '${dayNotes.length} ${dayNotes.length == 1 ? 'entry' : 'entries'}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AxisColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Notes for this date
                        ...dayNotes.map((note) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => _showNoteDetail(note),
                              borderRadius: BorderRadius.circular(12),
                              child: _NoteCardWidget(note: note),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.secondary.withValues(alpha: 0.22)
              : AxisColors.surfaceHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AxisColors.secondary : AxisColors.borderSubtle,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? AxisColors.secondary : AxisColors.textDim,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NoteCardWidget extends StatelessWidget {
  const _NoteCardWidget({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final isJournal = note.category == 'journal';
    final icon =
        isJournal ? Icons.auto_stories_rounded : Icons.article_rounded;
    final dateStr = DateFormat('h:mm a • MMM d').format(note.createdAt);

    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isJournal
                  ? AxisColors.secondary.withValues(alpha: 0.15)
                  : AxisColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                color: isJournal ? AxisColors.secondary : AxisColors.primary,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.pinned)
                      const Icon(Icons.push_pin_rounded,
                          size: 14, color: AxisColors.warning),
                  ],
                ),
                const SizedBox(height: 4),
                if (note.bodyMd.isNotEmpty)
                  Text(
                    note.bodyMd,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AxisColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 11, color: AxisColors.textDim)),
                    if (note.mood != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AxisColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          note.mood!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
