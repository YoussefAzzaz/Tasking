import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/ui/common/cyber_search_bar.dart';
import 'daily_journal_card.dart';
import 'note_category_card.dart';

/// Journals tab view containing journal search bar, DailyJournalCard hero prompt,
/// empty states, and journal entries list.
class JournalsTabView extends StatelessWidget {
  final Note? todayJournal;
  final List<Note> journalNotes;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<Note?> onOpenTodayJournal;
  final VoidCallback onStartNewJournal;
  final ValueChanged<Note> onTapNote;

  const JournalsTabView({
    super.key,
    required this.todayJournal,
    required this.journalNotes,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onOpenTodayJournal,
    required this.onStartNewJournal,
    required this.onTapNote,
  });

  Widget _buildEmptySearchState({
    required BuildContext context,
    required String query,
    required VoidCallback onClear,
  }) {
    final isArabic = context.isArabic;
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
                color: AxisColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 32, color: AxisColors.warning),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic
                  ? 'لم يتم العثور على تدوينات لـ "$query"'
                  : 'No journal entries found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'تأكد من صحة الكلمات أو ابحث بكلمة مفتاحية أخرى.'
                  : 'Try checking your spelling or search with a different keyword.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textDim,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AxisColors.warning.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.close_rounded,
                  size: 14, color: AxisColors.warning),
              label: Text(
                isArabic ? 'مسح البحث' : 'Clear Search',
                style: const TextStyle(
                  color: AxisColors.warning,
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
    final isSearching = searchQuery.isNotEmpty;
    final displayedJournalNotes = searchQuery.isEmpty
        ? journalNotes
        : journalNotes
            .where((n) =>
                n.title.toLowerCase().contains(searchQuery) ||
                n.bodyMd.toLowerCase().contains(searchQuery))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar for journals
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CyberSearchBar(
            controller: searchController,
            hintText: context.isArabic
                ? 'البحث في اليوميات والتأملات...'
                : 'Search journals & reflections...',
            accentColor: AxisColors.warning,
            onChanged: onSearchChanged,
            onClear: onSearchCleared,
          ),
        ),
        const SizedBox(height: 12),

        // Daily Journal Card (prominent when no search query)
        if (!isSearching) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DailyJournalCard(
              todayJournal: todayJournal,
              onOpenTodayJournal: onOpenTodayJournal,
              onStartNewJournal: onStartNewJournal,
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Empty search results state
        if (isSearching && displayedJournalNotes.isEmpty)
          _buildEmptySearchState(
            context: context,
            query: searchController.text.trim(),
            onClear: onSearchCleared,
          )
        // No journal entries yet state
        else if (!isSearching && journalNotes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                  const Icon(Icons.menu_book_rounded,
                      size: 38, color: AxisColors.textDim),
                  const SizedBox(height: 12),
                  Text(
                    context.isArabic
                        ? 'لا توجد تدوينات يومية مسجلة بعد'
                        : 'No Journal Entries Recorded Yet',
                    style: const TextStyle(
                      color: AxisColors.textHigh,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.isArabic
                        ? 'سجّل أفكارك اليومية وتأملاتك ورؤاك.'
                        : 'Log your daily thoughts, reflections, and insights.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AxisColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onStartNewJournal,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      context.isArabic
                          ? 'بدء أول يومية'
                          : 'Start First Journal',
                    ),
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
              key: const ValueKey('note_cat_journal'),
              category: NoteCategory(
                id: 'journal',
                name: context.isArabic
                    ? 'سجلات وتأملات يومية'
                    : 'Daily Logs & Reflections',
                icon: 'journal',
                color: '#F59E0B',
              ),
              color: AxisColors.warning,
              notes: displayedJournalNotes,
              forceExpand: true,
              onTapNote: onTapNote,
              onAddNote: onStartNewJournal,
            ),
          ),
        ],
      ],
    );
  }
}

