import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Modal bottom sheet for configuring task duration / estimate timer
class TaskDurationPickerSheet extends StatefulWidget {
  const TaskDurationPickerSheet({
    super.key,
    this.initialEstimateMin,
    required this.onApplied,
    required this.onCleared,
  });

  final int? initialEstimateMin;
  final ValueChanged<int> onApplied;
  final VoidCallback onCleared;

  static Future<void> show({
    required BuildContext context,
    required int? initialEstimateMin,
    required ValueChanged<int> onApplied,
    required VoidCallback onCleared,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => TaskDurationPickerSheet(
        initialEstimateMin: initialEstimateMin,
        onApplied: (val) {
          onApplied(val);
          Navigator.pop(sheetCtx);
        },
        onCleared: () {
          onCleared();
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  @override
  State<TaskDurationPickerSheet> createState() => _TaskDurationPickerSheetState();
}

class _TaskDurationPickerSheetState extends State<TaskDurationPickerSheet> {
  late int current;
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    current = widget.initialEstimateMin ?? 15;
    controller = TextEditingController(text: current.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMicro = current <= 15 && current > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AxisColors.borderPrimary, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AxisColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isMicro ? AxisColors.secondary : AxisColors.primary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isMicro ? Icons.bolt_rounded : Icons.timer_outlined,
                  color: isMicro ? AxisColors.secondary : AxisColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.isArabic ? 'مؤقت مدة المهمة' : 'TASK DURATION TIMER',
                      style: const TextStyle(
                        color: AxisColors.textHigh,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      context.isArabic
                          ? 'قدّر الوقت الذي ستستغرقه هذه المهمة منك'
                          : 'Estimate how much time this task will take from you',
                      style: const TextStyle(
                        color: AxisColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Micro-slot indicator banner (≤ 15 min detection)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMicro
                  ? AxisColors.secondary.withValues(alpha: 0.15)
                  : AxisColors.surfaceHigh.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMicro ? AxisColors.secondary : AxisColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMicro
                      ? Icons.bolt_rounded
                      : Icons.hourglass_empty_rounded,
                  color: isMicro ? AxisColors.secondary : AxisColors.textDim,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMicro
                            ? (context.isArabic
                                ? 'جاهزة لفترة مصغرة 15 د (≤ 15 دقيقة)'
                                : '15M MICRO-SLOT READY (≤ 15 MIN)')
                            : (context.isArabic
                                ? 'مهمة عادية (> 15 دقيقة)'
                                : 'STANDARD TASK (> 15 MIN)'),
                        style: TextStyle(
                          color: isMicro
                              ? AxisColors.secondary
                              : AxisColors.textHigh,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMicro
                            ? (context.isArabic
                                ? 'تُجدول تلقائياً في فترات الـ 15 دقيقة بلوحة اليوم.'
                                : 'Auto-scheduled in 15M Micro Slots on Today dashboard.')
                            : (context.isArabic
                                ? 'تُجدول في جلسات تركيز أطول وسباقات المشاريع.'
                                : 'Scheduled in longer focus blocks and project sprints.'),
                        style: const TextStyle(
                          color: AxisColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stepper & Large display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: current > 5
                    ? () {
                        setState(() {
                          current = (current - 5).clamp(1, 480);
                          controller.text = current.toString();
                        });
                      }
                    : null,
                icon: const Icon(Icons.remove_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AxisColors.surfaceHigh,
                  foregroundColor: AxisColors.textHigh,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMicro
                        ? AxisColors.secondary
                        : AxisColors.primary,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$current',
                      style: const TextStyle(
                        color: AxisColors.textHigh,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.isArabic ? 'دقيقة' : 'MIN',
                      style: const TextStyle(
                        color: AxisColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    current = (current + 5).clamp(1, 480);
                    controller.text = current.toString();
                  });
                },
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AxisColors.surfaceHigh,
                  foregroundColor: AxisColors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [5, 10, 15, 25, 30, 45, 60, 90, 120].map((m) {
              final isSelected = current == m;
              final isMicroPreset = m <= 15;
              return ChoiceChip(
                avatar: isMicroPreset
                    ? const Icon(Icons.bolt_rounded,
                        size: 14, color: AxisColors.secondary)
                    : null,
                label: Text(
                  m == 25
                      ? (context.isArabic ? '25 د (بومودورو)' : '25m (Pomo)')
                      : (context.isArabic ? '$m د' : '${m}m'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? (isMicroPreset
                            ? AxisColors.secondary
                            : AxisColors.primary)
                        : AxisColors.textMuted,
                  ),
                ),
                selected: isSelected,
                selectedColor:
                    (isMicroPreset ? AxisColors.secondary : AxisColors.primary)
                        .withValues(alpha: 0.2),
                backgroundColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected
                        ? (isMicroPreset
                            ? AxisColors.secondary
                            : AxisColors.primary)
                        : AxisColors.borderSubtle,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      current = m;
                      controller.text = current.toString();
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCleared,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AxisColors.textDim,
                    side: const BorderSide(color: AxisColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(context.isArabic ? 'إلغاء المؤقت' : 'Clear Timer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => widget.onApplied(current),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMicro
                        ? AxisColors.secondary
                        : AxisColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    context.isArabic ? 'تطبيق مؤقت $current دقيقة' : 'Apply ${current}m Timer',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

