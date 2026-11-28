import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/focus_session_service.dart';
import '../../widgets/accent_button.dart';

/// Modal dialog for configuring focus sprint protocol durations and cycle counts.
class DesktopFocusProtocolDialog extends StatefulWidget {
  final VoidCallback onConfigSaved;

  const DesktopFocusProtocolDialog({
    super.key,
    required this.onConfigSaved,
  });

  static void show(BuildContext context, {required VoidCallback onConfigSaved}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => DesktopFocusProtocolDialog(onConfigSaved: onConfigSaved),
    );
  }

  @override
  State<DesktopFocusProtocolDialog> createState() => _DesktopFocusProtocolDialogState();
}

class _DesktopFocusProtocolDialogState extends State<DesktopFocusProtocolDialog> {
  late int _focusMin;
  late int _shortBreakMin;
  late int _longBreakMin;
  late int _cycles;
  late bool _autoStartBreaks;
  late bool _soundscapeAutoPlay;
  late FocusSessionConfig _initial;

  @override
  void initState() {
    super.initState();
    _initial = FocusSessionService().config;
    _focusMin = _initial.focusMinutes;
    _shortBreakMin = _initial.shortBreakMinutes;
    _longBreakMin = _initial.longBreakMinutes;
    _cycles = _initial.cyclesBeforeLongBreak;
    _autoStartBreaks = _initial.autoStartBreaks;
    _soundscapeAutoPlay = _initial.soundscapeAutoPlay;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AxisColors.canvasBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AxisColors.borderGlass2, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 18, color: AxisColors.secondary),
                    const SizedBox(width: 8),
                    Text(
                      isAr ? 'بروتوكول جلسات التركيز' : 'Focus Sprint Protocol',
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AxisColors.textHigh,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Focus Sprint duration options
            Text(
              isAr ? 'مدة جلسة التركيز' : 'FOCUS SPRINT DURATION',
              style: AxisFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.textDim),
            ),
            const SizedBox(height: 6),
            Row(
              children: [15, 25, 45, 60].map((min) {
                final isSel = _focusMin == min;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _focusMin = min),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AxisColors.primary.withValues(alpha: 0.25) : AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isSel ? AxisColors.primary : AxisColors.borderSubtle),
                      ),
                      child: Center(
                        child: Text(
                          isAr ? '$min د' : '${min}m',
                          style: AxisFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? AxisColors.textHigh : AxisColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Short Break duration options
            Text(
              isAr ? 'استراحة استعادة النشاط القصيرة' : 'SHORT REBOOT BREAK',
              style: AxisFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.textDim),
            ),
            const SizedBox(height: 6),
            Row(
              children: [3, 5, 10, 15].map((min) {
                final isSel = _shortBreakMin == min;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _shortBreakMin = min),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AxisColors.warning.withValues(alpha: 0.2) : AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isSel ? AxisColors.warning : AxisColors.borderSubtle),
                      ),
                      child: Center(
                        child: Text(
                          isAr ? '$min د' : '${min}m',
                          style: AxisFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? AxisColors.warning : AxisColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Cycles before long break
            Text(
              isAr ? 'الدورات قبل الاستراحة الطويلة' : 'CYCLES BEFORE LONG RESET',
              style: AxisFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.textDim),
            ),
            const SizedBox(height: 6),
            Row(
              children: [2, 3, 4, 6].map((c) {
                final isSel = _cycles == c;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _cycles = c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AxisColors.secondary.withValues(alpha: 0.2) : AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isSel ? AxisColors.secondary : AxisColors.borderSubtle),
                      ),
                      child: Center(
                        child: Text(
                          isAr ? '$c دورات' : '$c Cycles',
                          style: AxisFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? AxisColors.secondary : AxisColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Auto start breaks switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isAr ? 'بدء استراحات الاستعادة تلقائياً' : 'Auto-start reboot breaks',
                      style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _autoStartBreaks,
                    activeThumbColor: AxisColors.secondary,
                    onChanged: (val) => setState(() => _autoStartBreaks = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    isAr ? 'إلغاء' : 'Cancel',
                    style: AxisFonts.getFont('Geist', color: AxisColors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                AccentButton(
                  label: isAr ? 'حفظ البروتوكول' : 'Save Protocol',
                  onPressed: () {
                    final newConfig = _initial.copyWith(
                      focusMinutes: _focusMin,
                      shortBreakMinutes: _shortBreakMin,
                      longBreakMinutes: _longBreakMin,
                      cyclesBeforeLongBreak: _cycles,
                      autoStartBreaks: _autoStartBreaks,
                      soundscapeAutoPlay: _soundscapeAutoPlay,
                    );
                    FocusSessionService().updateConfig(newConfig);
                    Navigator.of(context).pop();
                    widget.onConfigSaved();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

