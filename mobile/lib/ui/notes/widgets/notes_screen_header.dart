import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Top bar for Notes screen including title, subtitle, "+ New Note/Journal" button,
/// and segmented pill switcher between Notes and Journals.
class NotesScreenHeader extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onNewItem;

  const NotesScreenHeader({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.onNewItem,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return Column(
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
                      activeTab == 'journal'
                          ? l10n.journals
                          : (isArabic ? 'الملاحظات واليوميات' : 'Notes & Journal'),
                      style: Theme.of(context).textTheme.displaySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeTab == 'journal'
                          ? (isArabic
                              ? 'تأملات يومية ومذكرات وتدوينات'
                              : 'Daily reflections, logs & prompts')
                          : (isArabic
                              ? 'ملاحظات مصنفة وقاعدة معرفية'
                              : 'Categorized notes & knowledge base'),
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
                onTap: onNewItem,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: activeTab == 'journal'
                          ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
                          : const [AxisColors.secondary, Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: (activeTab == 'journal'
                                ? AxisColors.warning
                                : AxisColors.secondary)
                            .withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activeTab == 'journal'
                            ? Icons.auto_stories_rounded
                            : Icons.edit_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activeTab == 'journal'
                            ? (isArabic ? 'يومية جديدة' : 'New Journal')
                            : (isArabic ? 'ملاحظة جديدة' : 'New Note'),
                        style: const TextStyle(
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

        // Segmented Tab Switcher: Notes vs Journals
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (activeTab != 'notes') onTabChanged('notes');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: activeTab == 'notes'
                            ? AxisColors.secondary.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activeTab == 'notes'
                              ? AxisColors.secondary.withValues(alpha: 0.8)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 15,
                            color: activeTab == 'notes'
                                ? AxisColors.secondary
                                : AxisColors.textDim,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.notes,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: activeTab == 'notes'
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: activeTab == 'notes'
                                  ? AxisColors.textHigh
                                  : AxisColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (activeTab != 'journal') onTabChanged('journal');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: activeTab == 'journal'
                            ? AxisColors.warning.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activeTab == 'journal'
                              ? AxisColors.warning.withValues(alpha: 0.8)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 15,
                            color: activeTab == 'journal'
                                ? AxisColors.warning
                                : AxisColors.textDim,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.journals,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: activeTab == 'journal'
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: activeTab == 'journal'
                                  ? AxisColors.textHigh
                                  : AxisColors.textMuted,
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
    );
  }
}

