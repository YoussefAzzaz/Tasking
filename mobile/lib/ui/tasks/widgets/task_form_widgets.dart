import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Styled uppercase field label for dark theme forms
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.tr(context),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AxisColors.textMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

/// Priority selector toggle button with glowing active state
class PriorityButton extends StatelessWidget {
  const PriorityButton({
    super.key,
    required this.priorityNumber,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final int priorityNumber;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.22)
                : AxisColors.surfaceHigh.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AxisColors.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AxisColors.textDim,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick date shortcut pill (Today, Tomorrow, In 3 Days)
class QuickDateChip extends StatelessWidget {
  const QuickDateChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.secondary.withValues(alpha: 0.2)
              : AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AxisColors.secondary : AxisColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AxisColors.secondarySoft : AxisColors.textDim,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Generic dropdown item option with support for icons, color dots, and action styles
class DropdownOption extends StatelessWidget {
  const DropdownOption({
    super.key,
    this.icon,
    this.iconColor,
    this.colorDot,
    required this.title,
    this.isSelected = false,
    this.isAction = false,
    required this.onTap,
  });

  final IconData? icon;
  final Color? iconColor;
  final Color? colorDot;
  final String title;
  final bool isSelected;
  final bool isAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.surfaceHigh.withValues(alpha: 0.6)
              : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: AxisColors.borderSubtle, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (colorDot != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorDot,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorDot!.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? AxisColors.textMuted),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isAction
                      ? (iconColor ?? AxisColors.secondary)
                      : (isSelected
                          ? AxisColors.textHigh
                          : AxisColors.textMuted),
                  fontSize: 13,
                  fontWeight: isSelected || isAction
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: AxisColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Header bar with pill grabber, title, and close action for task sheets
class TaskSheetHeader extends StatelessWidget {
  const TaskSheetHeader({
    super.key,
    required this.isEdit,
    required this.onClose,
  });

  final bool isEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AxisColors.borderGlass2,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_task_rounded,
                        color: AxisColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit
                        ? (AppLocalizations.of(context).isArabic ? 'تعديل المهمة' : 'EDIT TASK')
                        : (AppLocalizations.of(context).isArabic ? 'مهمة جديدة' : 'NEW TASK'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AxisColors.textHigh,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AxisColors.textMuted, size: 22),
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gradient submit button for task creation and editing
class TaskSubmitButton extends StatelessWidget {
  const TaskSubmitButton({
    super.key,
    required this.isEdit,
    required this.isSaving,
    required this.onPressed,
  });

  final bool isEdit;
  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AxisColors.primary,
              Color(0xFF6366F1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AxisColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEdit
                          ? (AppLocalizations.of(context).isArabic ? 'حفظ التغييرات' : 'SAVE CHANGES')
                          : (AppLocalizations.of(context).isArabic ? 'إنشاء مهمة' : 'CREATE TASK'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
