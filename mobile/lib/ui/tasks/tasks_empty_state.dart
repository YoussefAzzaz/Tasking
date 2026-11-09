import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

class TasksEmptyState extends StatelessWidget {
  const TasksEmptyState({
    super.key,
    this.isFiltered = false,
    this.onReset,
  });

  final bool isFiltered;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_list_off_rounded : Icons.inbox_rounded,
            size: 48,
            color: AxisColors.textDim,
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered
                ? (isArabic ? 'لا توجد مهام تطابق عوامل التصفية' : 'No tasks match active filters')
                : (isArabic ? 'لا توجد مهام' : 'No tasks found'),
            style: const TextStyle(
              color: AxisColors.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFiltered
                ? (isArabic
                    ? 'حاول تعديل خيارات التصفية أو إعادة تعيينها'
                    : 'Try adjusting or resetting your filter studio selections')
                : (isArabic
                    ? 'انقر على "+ مهمة جديدة" لإنشاء هدفك الأول'
                    : 'Tap "+ New Task" to create your first objective'),
            style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
          if (isFiltered && onReset != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: Text(isArabic ? 'إعادة تعيين الفلاتر' : 'Reset Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AxisColors.primary,
                side: const BorderSide(color: AxisColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
