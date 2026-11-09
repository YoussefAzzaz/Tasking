import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';

/// Card displayed when habit search yields no results.
class HabitSearchEmptyState extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const HabitSearchEmptyState({
    super.key,
    required this.query,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
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
                color: AxisColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 32,
                color: AxisColors.success,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic
                  ? 'لم يتم العثور على عادات لـ "$query"'
                  : 'No habits found for "$query"',
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
                  color: AxisColors.success.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AxisColors.success,
              ),
              label: Text(
                isArabic ? 'مسح البحث' : 'Clear Search',
                style: const TextStyle(
                  color: AxisColors.success,
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
}

/// Placeholder widget shown when the user has not configured any habits or categories yet.
class HabitsNoCategoriesEmptyState extends StatelessWidget {
  const HabitsNoCategoriesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 36, color: AxisColors.textDim),
            const SizedBox(height: 12),
            Text(
              isArabic
                  ? 'لا توجد فئات عادات بعد'
                  : 'No Habit Categories Yet',
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'اضغط "+ إضافة عادة" أعلاه لإنشاء عادتك الأولى أو تصنيف مخصص.'
                  : 'Tap "+ Add Habit" above to create your first habit or custom category.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textDim,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

