import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

/// Smooth sliding segmented bar that physically animates a single pill indicator
/// across the track on tap, preventing any duplicate-highlight delay or flash.
class AxisSlidingSegmentedBar extends StatelessWidget {
  const AxisSlidingSegmentedBar({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentSelected,
    this.activeColor = AxisColors.primary,
    this.activeGradient,
    this.height = 42,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onSegmentSelected;
  final Color activeColor;
  final Gradient? activeGradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = segments.length;
          final itemWidth = constraints.maxWidth / count;
          final clampedIndex = selectedIndex.clamp(0, count - 1);

          return Stack(
            children: [
              // Single animated sliding indicator pill
              AnimatedPositionedDirectional(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                start: clampedIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: activeGradient ??
                        LinearGradient(
                          colors: [
                            activeColor,
                            activeColor == AxisColors.primary
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF0284C7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // Segment labels on top
              Row(
                children: List.generate(count, (i) {
                  final isSelected = clampedIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSegmentSelected(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AxisColors.textDim,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: count > 3 ? 11.5 : 12,
                            letterSpacing: Directionality.of(context) == TextDirection.rtl ? 0.0 : (count > 3 ? 0.1 : 0.3),
                          ),
                          child: Text(
                            segments[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
