import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/note_category_repository.dart';
import '../../../../data/note_repository.dart';
import '../../../notes/widgets/daily_review_prompt_card.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import 'journal_deck_streak_calendar.dart';

/// Left-hand navigation pane for browsing notes, journals, categories, and calendar streak.
class JournalVaultNavigatorPane extends StatelessWidget {
  final String activeTab;
  final String selectedCategoryFilter;
  final String searchQuery;
  final TextEditingController searchController;
  final ScrollController vaultScrollController;
  final Note? selectedNote;
  final ValueChanged<String> onSwitchTab;
  final ValueChanged<String> onSelectCategoryFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Note> onSelectNote;
  final ValueChanged<String> onStartNewEntry;

  const JournalVaultNavigatorPane({
    super.key,
    required this.activeTab,
    required this.selectedCategoryFilter,
    required this.searchQuery,
    required this.searchController,
    required this.vaultScrollController,
    required this.selectedNote,
    required this.onSwitchTab,
    required this.onSelectCategoryFilter,
    required this.onSearchChanged,
    required this.onSelectNote,
    required this.onStartNewEntry,
  });

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => onSwitchTab('notes'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: activeTab == 'notes' ? AxisColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeTab == 'notes' ? AxisColors.primary : AxisColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isArabic ? '≡ الملاحظات' : '≡ Notes',
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: activeTab == 'notes' ? AxisColors.textHigh : AxisColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSwitchTab('journal'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: activeTab == 'journal' ? AxisColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeTab == 'journal' ? AxisColors.primary : AxisColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        l10n.journals,
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: activeTab == 'journal' ? AxisColors.textHigh : AxisColors.textMuted,
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
          if (activeTab == 'journal') ...[
            DailyReviewPromptCard(
              onTapRecord: () => onStartNewEntry('journal'),
            ),
            const SizedBox(height: 10),
          ],

          // Note Category Filter Chips if in notes mode
          if (activeTab == 'notes') ...[
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
                      final isSel = selectedCategoryFilter.toLowerCase() == cat.toLowerCase();
                      final displayLabel = isArabic
                          ? (cat.toLowerCase() == 'all'
                              ? 'الكل'
                              : (cat.toLowerCase() == 'general' ? 'عام' : cat))
                          : cat;
                      return GestureDetector(
                        onTap: () => onSelectCategoryFilter(cat),
                        child: Container(
                          margin: const EdgeInsetsDirectional.only(end: 8, bottom: 4),
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
                            displayLabel,
                            style: AxisFonts.spaceGrotesk(
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

          // Search input
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
              decoration: InputDecoration(
                icon: const Icon(Icons.search_rounded, size: 15, color: AxisColors.textDim),
                hintText: isArabic ? 'البحث في الملاحظات والوسوم...' : 'Search notes & tags...',
                hintStyle: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Vault hierarchy section header
          Text(
            isArabic ? 'شجرة الخزينة' : 'VAULT HIERARCHY',
            style: AxisFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AxisColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable Vault Hierarchy List
          Expanded(
            child: StreamBuilder<List<Note>>(
              stream: NoteRepository().watchNotes(category: activeTab == 'notes' ? null : 'journal'),
              builder: (context, snapshot) {
                final allNotes = snapshot.data ?? [];
                var filtered = allNotes;

                if (activeTab == 'notes') {
                  filtered = filtered.where((n) => n.category.toLowerCase() != 'journal').toList();
                } else if (activeTab == 'journal') {
                  filtered = filtered.where((n) => n.category.toLowerCase() == 'journal').toList();
                }

                if (activeTab == 'notes' && selectedCategoryFilter != 'All') {
                  filtered = filtered.where((n) {
                    final cat = (n.category.isEmpty ? 'general' : n.category).toLowerCase();
                    return cat == selectedCategoryFilter.toLowerCase();
                  }).toList();
                }

                if (searchQuery.isNotEmpty) {
                  filtered = filtered.where((n) =>
                      n.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                      n.bodyMd.toLowerCase().contains(searchQuery.toLowerCase())).toList();
                }

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
                        activeTab == 'journal'
                            ? (isArabic ? 'لم يتم تسجيل يوميات بعد' : 'No journals recorded yet')
                            : (isArabic ? 'لم يتم العثور على ملاحظات' : 'No notes found'),
                        style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      ),
                    ),
                  );
                }

                return Scrollbar(
                  controller: vaultScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: vaultScrollController,
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      final isSelected = selectedNote?.id == n.id;
                      final displayTitle = n.title.isEmpty ? (isArabic ? 'بلا عنوان' : 'Untitled') : n.title;
                      return GestureDetector(
                        onTap: () => onSelectNote(n),
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
                                  displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AxisFonts.getFont(
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
                                    style: AxisFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AxisColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                              if ((n.senderUsername ?? '')
                                  .trim()
                                  .replaceFirst(RegExp(r'^@+'), '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AxisColors.primarySoft.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '@${(n.senderUsername ?? '').trim().replaceFirst(RegExp(r'^@+'), '').trim()}',
                                    style: AxisFonts.spaceGrotesk(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AxisColors.primarySoft,
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
          const JournalDeckStreakCalendar(),
        ],
      ),
    );
  }
}

