import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/common/axis_sliding_segmented_bar.dart';
import 'package:axis/ui/notes/widgets/note_detail_sheet.dart';
import 'package:axis/ui/notes/widgets/note_card_widget.dart';
import 'package:axis/ui/notes/widgets/daily_review_prompt_card.dart';
import 'package:axis/ui/notes/widgets/note_date_filter_toolbar.dart';

export 'package:axis/ui/notes/widgets/note_detail_sheet.dart';
export 'package:axis/ui/notes/widgets/note_card_widget.dart';
export 'package:axis/ui/notes/widgets/daily_review_prompt_card.dart';
export 'package:axis/ui/notes/widgets/note_date_filter_toolbar.dart';

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

  void _openCreateNote({String category = 'note', Note? noteToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateNoteSheet(
        initialCategory: category,
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
        onEdit: () => _openCreateNote(noteToEdit: note),
        onDelete: () async {
          await _repo.deleteNote(note.id);
          setState(() {});
        },
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
                    category:
                        _selectedSegment == 'journal' ? 'journal' : 'note',
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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

          // Smooth sliding segmented bar: All Notes | Notes | Journal
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
            child: NoteDateFilterToolbar(
              filterDate: _filterDate,
              onPickDate: _pickFilterDate,
              onClearDate: () => setState(() => _filterDate = null),
              onSelectDate: (date) => setState(() => _filterDate = date),
            ),
          ),
          const SizedBox(height: 12),

          // Daily Review Prompt Card (when in All or Journal view)
          if (_selectedSegment == 'all' || _selectedSegment == 'journal')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DailyReviewPromptCard(
                onTapRecord: () => _openCreateNote(category: 'journal'),
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
                      child: CircularProgressIndicator(
                          color: AxisColors.secondary),
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
                                  border: Border.all(
                                      color: AxisColors.borderSubtle),
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
                              child: NoteCardWidget(note: note),
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
