import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/note_repository.dart';
import '../../../../data/reading_preferences_service.dart';
import '../../../common/axis_markdown_viewer.dart';
import '../../widgets/desktop_card.dart';

/// Right-hand live preview pane rendering formatted markdown with font size controls.
class JournalLivePreviewPane extends StatelessWidget {
  final String editorText;
  final Note? selectedNote;
  final ValueChanged<String> onMarkdownChanged;

  const JournalLivePreviewPane({
    super.key,
    required this.editorText,
    required this.selectedNote,
    required this.onMarkdownChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;
    final emptyPlaceholder = isAr ? '# ملاحظة فارغة\n\nلا يوجد محتوى بعد.' : '# Empty Note\n\nNo content yet.';
    final markdown = editorText.isNotEmpty
        ? editorText
        : (selectedNote?.bodyMd ?? emptyPlaceholder);

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isAr ? '● المعاينة' : '● PREVIEW',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AxisFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AxisColors.tertiary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<double>(
                valueListenable: ReadingPreferencesService().fontScaleNotifier,
                builder: (context, scale, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: ReadingPreferencesService().decreaseScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Text(
                              'A-',
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: ReadingPreferencesService().resetScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Text(
                              '${(scale * 100).round()}%',
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: ReadingPreferencesService().increaseScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Text(
                              'A+',
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Markdown viewer container with live font scale
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle, width: 1),
              ),
              child: SingleChildScrollView(
                child: ValueListenableBuilder<double>(
                  valueListenable: ReadingPreferencesService().fontScaleNotifier,
                  builder: (context, scale, _) {
                    return AxisMarkdownViewer(
                      markdown: markdown,
                      fontScale: scale,
                      onMarkdownChanged: onMarkdownChanged,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

