import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';

/// Reusable section title + subtitle + telemetry badge header for focus settings.
class FocusSectionHeader extends StatelessWidget {
  const FocusSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentVal,
  });

  final String title;
  final String subtitle;
  final String currentVal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AxisColors.textHigh,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AxisColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AxisColors.borderSubtle),
          ),
          child: Text(
            currentVal,
            style: const TextStyle(
              color: AxisColors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Selector chips for the focus wave duration (e.g. 15m, 25m, 45m...).
class FocusWaveDurationSelector extends StatelessWidget {
  const FocusWaveDurationSelector({
    super.key,
    required this.selectedMin,
    required this.presets,
    required this.onSelected,
  });

  final int selectedMin;
  final List<int> presets;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusSectionHeader(
          title: isArabic ? 'مدة موجة التركيز' : 'FOCUS WAVE DURATION',
          subtitle: isArabic
              ? 'مدة الجلسة المتواصلة دون مقاطعة'
              : 'Quantum duration per uninterrupted session',
          currentVal: isArabic ? '$selectedMin دقيقة' : '$selectedMin min',
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((min) {
              final isSel = selectedMin == min;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(isArabic ? '$min د' : '${min}m'),
                  selected: isSel,
                  onSelected: (_) => onSelected(min),
                  selectedColor: AxisColors.primary.withValues(alpha: 0.25),
                  backgroundColor: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                  side: BorderSide(
                    color: isSel ? AxisColors.primary : AxisColors.borderSubtle,
                  ),
                  labelStyle: TextStyle(
                    color: isSel ? AxisColors.primarySoft : AxisColors.textDim,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Selector buttons for break duration (short or long break).
class FocusBreakDurationSelector extends StatelessWidget {
  const FocusBreakDurationSelector({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selectedMin,
    required this.presets,
    required this.accentColor,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final int selectedMin;
  final List<int> presets;
  final Color accentColor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusSectionHeader(
          title: title,
          subtitle: subtitle,
          currentVal: isArabic ? '$selectedMin دقيقة' : '$selectedMin min',
        ),
        const SizedBox(height: 10),
        Row(
          children: presets.map((min) {
            final isSel = selectedMin == min;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => onSelected(min),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel
                          ? accentColor.withValues(alpha: 0.2)
                          : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? accentColor : AxisColors.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isArabic ? '$min د' : '${min}m',
                          style: TextStyle(
                            color: isSel ? accentColor : AxisColors.textDim,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Selector buttons for interval cycles before a long break.
class FocusCyclesIntervalSelector extends StatelessWidget {
  const FocusCyclesIntervalSelector({
    super.key,
    required this.selectedCycles,
    required this.presets,
    required this.onSelected,
  });

  final int selectedCycles;
  final List<int> presets;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusSectionHeader(
          title: isArabic ? 'فاصل الاستراحة الطويلة' : 'LONG BREAK INTERVAL',
          subtitle: isArabic
              ? 'عدد الدورات المكتملة قبل الراحة الممتدة'
              : 'Completed cycles before extended rest',
          currentVal: isArabic
              ? 'كل $selectedCycles دورات'
              : 'Every $selectedCycles Cycles',
        ),
        const SizedBox(height: 10),
        Row(
          children: presets.map((c) {
            final isSel = selectedCycles == c;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => onSelected(c),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AxisColors.warning.withValues(alpha: 0.2)
                          : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? AxisColors.warning : AxisColors.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isArabic ? '$c دورات' : '$c Cycles',
                          style: TextStyle(
                            color: isSel ? AxisColors.warning : AxisColors.textDim,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Card containing automation toggle switches for auto-starting breaks and soundscape playback.
class FocusAutomationSwitchesCard extends StatelessWidget {
  const FocusAutomationSwitchesCard({
    super.key,
    required this.autoStartBreaks,
    required this.soundscapeAutoPlay,
    required this.onAutoStartBreaksChanged,
    required this.onSoundscapeAutoPlayChanged,
  });

  final bool autoStartBreaks;
  final bool soundscapeAutoPlay;
  final ValueChanged<bool> onAutoStartBreaksChanged;
  final ValueChanged<bool> onSoundscapeAutoPlayChanged;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'بدء الاستراحات تلقائياً' : 'Auto-Start Breaks',
                      style: const TextStyle(
                          color: AxisColors.textHigh,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? 'بدء العد التنازلي للاستراحة تلقائياً'
                          : 'Begin countdown automatically',
                      style: const TextStyle(
                          color: AxisColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: autoStartBreaks,
                activeThumbColor: AxisColors.primary,
                onChanged: onAutoStartBreaksChanged,
              ),
            ],
          ),
          const Divider(color: AxisColors.borderSubtle, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'تشغيل الأصوات تلقائياً'
                          : 'Neural Hums Auto-Play',
                      style: const TextStyle(
                          color: AxisColors.textHigh,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? 'تشغيل الخلفية الصوتية عند بدء الجلسة'
                          : 'Play soundscape when session starts',
                      style: const TextStyle(
                          color: AxisColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: soundscapeAutoPlay,
                activeThumbColor: AxisColors.secondary,
                onChanged: onSoundscapeAutoPlayChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
