import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:axis/core/theme.dart';

/// Glass-tier card per DESIGN.md — backdrop blur, chromatic edge border.
class AxisCard extends StatelessWidget {
  const AxisCard({
    super.key,
    required this.child,
    this.tier = GlassTier.one,
    this.padding,
    this.borderRadius,
    this.accentBorder = false,
  });

  final Widget child;
  final GlassTier tier;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool accentBorder;

  @override
  Widget build(BuildContext context) {
    final (bgColor, bgAlpha, blurSigma) = switch (tier) {
      GlassTier.one => (AxisColors.glassTier1, 0.65, 16.0),
      GlassTier.two => (AxisColors.glassTier2, 0.82, 20.0),
    };
    final radius = borderRadius ?? 12.0;
    final borderColor = accentBorder
        ? AxisColors.borderPrimary
        : AxisColors.borderSubtle;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor.withOpacity(bgAlpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

enum GlassTier { one, two }

/// Pill chip used for tags, priority, estimates (Space Mono, 24-28px height)
class AxisChip extends StatelessWidget {
  const AxisChip({
    super.key,
    required this.label,
    this.dotColor,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final Color? dotColor;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AxisColors.surfaceHigh.withOpacity(0.5);
    final fg = textColor ?? AxisColors.textMuted;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AxisColors.borderSubtle, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 4, height: 4,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Priority chip — P1 amber, P2 indigo, P3 muted
class PriorityChip extends StatelessWidget {
  const PriorityChip({super.key, required this.priority});
  final int priority;

  @override
  Widget build(BuildContext context) {
    final (label, dotColor, bg) = switch (priority) {
      1 => ('P1', AxisColors.warning, AxisColors.warning.withOpacity(0.12)),
      2 => ('P2', AxisColors.primary, AxisColors.primary.withOpacity(0.12)),
      _ => ('P3', AxisColors.textDim, AxisColors.surfaceHigh.withOpacity(0.3)),
    };
    return AxisChip(
      label: label,
      dotColor: dotColor,
      backgroundColor: bg,
      textColor: dotColor,
    );
  }
}

/// XP micro-bar — emerald→cyan gradient, 6px height
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress, this.height = 6.0});
  final double progress; // 0.0 → 1.0
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh,
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          height: height,
          width: constraints.maxWidth * progress.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AxisColors.success, AxisColors.secondary],
            ),
            borderRadius: BorderRadius.circular(9999),
            boxShadow: [
              BoxShadow(
                color: AxisColors.success.withOpacity(0.35),
                blurRadius: 8, spreadRadius: -2,
              ),
            ],
          ),
        ),
      ]);
    });
  }
}

/// Streak badge pill with flame + day count
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days, this.isActive = true});
  final int days;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AxisColors.success.withOpacity(0.12)
            : AxisColors.surfaceHigh.withOpacity(0.4),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: isActive
              ? AxisColors.success.withOpacity(0.4)
              : AxisColors.borderSubtle,
          width: 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(
                color: AxisColors.success.withOpacity(0.2),
                blurRadius: 12, spreadRadius: -2)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$days',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isActive ? AxisColors.successBright : AxisColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom checkbox per DESIGN.md — 20x20px geometric, spring animation
class AxisCheckbox extends StatefulWidget {
  const AxisCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
  });
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  State<AxisCheckbox> createState() => _AxisCheckboxState();
}

class _AxisCheckboxState extends State<AxisCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onChanged(!widget.checked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: widget.checked ? AxisColors.success : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.checked
                  ? AxisColors.success
                  : AxisColors.textMuted.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: widget.checked
                ? [BoxShadow(
                    color: AxisColors.success.withOpacity(0.4),
                    blurRadius: 10, spreadRadius: -2)]
                : null,
          ),
          child: widget.checked
              ? const Icon(Icons.check, size: 12, color: AxisColors.canvasBase)
              : null,
        ),
      ),
    );
  }
}

/// Primary kinetic button per DESIGN.md
class AxisButton extends StatelessWidget {
  const AxisButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == ButtonVariant.primary) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AxisColors.primary,
          foregroundColor: AxisColors.textHigh,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AxisColors.textHigh)),
          ],
        ),
      );
    }
    // Secondary glass
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AxisColors.surfaceHigh.withOpacity(0.6),
        foregroundColor: AxisColors.textHigh,
        side: const BorderSide(color: AxisColors.borderSubtle, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

enum ButtonVariant { primary, secondary }
