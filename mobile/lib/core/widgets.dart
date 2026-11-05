import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:axis/core/theme.dart';
export 'package:axis/core/text_direction.dart';

/// Glass-tier card per DESIGN.md
class AxisCard extends StatelessWidget {
  const AxisCard({
    super.key,
    required this.child,
    this.tier = GlassTier.one,
    this.padding,
    this.borderRadius,
    this.accentBorder = false,
    this.useBlur = false,
  });

  final Widget child;
  final GlassTier tier;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool accentBorder;
  final bool useBlur;

  @override
  Widget build(BuildContext context) {
    final (bgColor, bgAlpha, blurSigma, borderColor) = switch (tier) {
      GlassTier.one => (AxisColors.glassTier1, 0.85, 16.0, AxisColors.borderSubtle),
      GlassTier.two => (AxisColors.glassTier2, 0.90, 20.0, AxisColors.borderGlass2),
    };
    final radius = borderRadius ?? 12.0;
    final border = accentBorder ? AxisColors.borderPrimary : borderColor;

    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );

    if (!useBlur) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: container,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: container,
      ),
    );
  }
}

enum GlassTier { one, two }

/// Pill chip (Space Mono, full-rounded, 24px height)
class AxisChip extends StatelessWidget {
  const AxisChip({
    super.key,
    required this.label,
    this.dotColor,
    this.backgroundColor,
    this.textColor,
    this.onTap,
  });

  final String label;
  final Color? dotColor;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AxisColors.surfaceHigh.withValues(alpha: 0.5);
    final fg = textColor ?? AxisColors.textMuted;

    final chip = Container(
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

    if (onTap == null) return chip;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(child: chip),
        ),
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
      1 => ('P1', AxisColors.warning, AxisColors.warning.withValues(alpha: 0.12)),
      2 => ('P2', AxisColors.primary, AxisColors.primary.withValues(alpha: 0.12)),
      _ => ('P3', AxisColors.textDim, AxisColors.surfaceHigh.withValues(alpha: 0.3)),
    };
    return AxisChip(
      label: label,
      dotColor: dotColor,
      backgroundColor: bg,
      textColor: dotColor,
    );
  }
}

/// XP micro-bar — emerald→cyan gradient, slim track
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress, this.height = 6.0});
  final double progress; // 0.0 → 1.0
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(children: [
        // Track
        Container(
          height: height,
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh,
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
        // Fill
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
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
                color: AxisColors.success.withValues(alpha: 0.35),
                blurRadius: 8, spreadRadius: -2,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ]);
    });
  }
}

/// Streak badge pill with flame + day count + emerald rim glow
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days, this.isActive = true});
  final int days;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? AxisColors.success.withValues(alpha: 0.12)
            : AxisColors.surfaceHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: isActive ? AxisColors.borderEmerald : AxisColors.borderSubtle,
          width: 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(
                color: AxisColors.success.withValues(alpha: 0.25),
                blurRadius: 24, spreadRadius: -4)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 14, color: AxisColors.tertiary),
          const SizedBox(width: 4),
          Text(
            '$days',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isActive ? AxisColors.tertiary : AxisColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom checkbox — 20×20px, 6px radius, emerald spring animation + glow
class AxisCheckbox extends StatefulWidget {
  const AxisCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.enabled = true,
  });
  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool enabled;

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
        vsync: this, duration: const Duration(milliseconds: 280));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    HapticFeedback.mediumImpact();
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onChanged(!widget.checked);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: widget.checked,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _toggle : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: !widget.enabled
                      ? AxisColors.surfaceHigh.withValues(alpha: 0.3)
                      : widget.checked
                          ? AxisColors.success
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: !widget.enabled
                        ? AxisColors.textMuted.withValues(alpha: 0.2)
                        : widget.checked
                            ? AxisColors.success
                            : AxisColors.textMuted.withValues(alpha: 0.4),
                    width: 1.8,
                  ),
                  boxShadow: widget.enabled && widget.checked
                      ? [
                          BoxShadow(
                            color: AxisColors.success.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: -2,
                          )
                        ]
                      : null,
                ),
                child: widget.checked
                    ? Icon(Icons.check_rounded,
                        size: 14,
                        color: widget.enabled ? AxisColors.canvasBase : AxisColors.textDim)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary kinetic button
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
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AxisColors.surfaceHigh.withValues(alpha: 0.6),
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

/// Modal bottom sheet scaffold that enables instant dismissal when clicking outside
/// the sheet (on the backdrop/empty space above the sheet).
class ModalSheetScaffold extends StatelessWidget {
  const ModalSheetScaffold({
    super.key,
    required this.child,
    this.onTapOutside,
    this.alignment = Alignment.bottomCenter,
  });

  final Widget child;
  final VoidCallback? onTapOutside;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapOutside ?? () => Navigator.of(context).pop(),
          ),
        ),
        if (alignment != null)
          Align(
            alignment: alignment!,
            child: child,
          )
        else
          child,
      ],
    );
  }
}

/// A wrapper for the top bar / drag handle of modal sheets that automatically
/// closes the sheet when tapped.
class ModalSheetTopBar extends StatelessWidget {
  const ModalSheetTopBar({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => Navigator.of(context).pop(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: child,
      ),
    );
  }
}
