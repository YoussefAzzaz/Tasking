import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';

import '../../../../core/theme.dart';
import '../../widgets/telemetry_chip.dart';

/// Item representation inside the Omnibar command dialog.
class OmnibarItem {
  final String category;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const OmnibarItem({
    required this.category,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });
}

/// Interactive row item for search query results in the omnibar palette.
class SearchItemRow extends StatefulWidget {
  const SearchItemRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<SearchItemRow> createState() => _SearchItemRowState();
}

class _SearchItemRowState extends State<SearchItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _isHovered;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AxisColors.surfaceHigh.withValues(alpha: 0.6) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.isSelected ? AxisColors.secondary.withValues(alpha: 0.4) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: active ? AxisColors.secondary : AxisColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AxisFonts.getFont(
                      'Geist',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: active ? AxisColors.textHigh : AxisColors.textMuted,
                    ),
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.subtitle!,
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 11,
                      color: AxisColors.textDim,
                    ),
                  ),
                ],
                if (widget.badge != null) ...[
                  const SizedBox(width: 8),
                  TelemetryChip(
                    label: widget.badge!,
                    color: widget.badgeColor ?? AxisColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keyboard navigation shortcut indicator footer for omnibar dialog.
class OmnibarFooter extends StatelessWidget {
  const OmnibarFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AxisColors.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Navigate',
            style: AxisFonts.spaceGrotesk(
              fontSize: 10,
              color: AxisColors.textDim,
            ),
          ),
          const SizedBox(width: 4),
          const TelemetryChip(
            label: '↑ ↓',
            color: AxisColors.textDim,
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          ),
          const SizedBox(width: 12),
          Text(
            'Open',
            style: AxisFonts.spaceGrotesk(
              fontSize: 10,
              color: AxisColors.textDim,
            ),
          ),
          const SizedBox(width: 4),
          const TelemetryChip(
            label: '↵',
            color: AxisColors.textDim,
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          ),
          const SizedBox(width: 12),
          Text(
            'Close',
            style: AxisFonts.spaceGrotesk(
              fontSize: 10,
              color: AxisColors.textDim,
            ),
          ),
          const SizedBox(width: 4),
          const TelemetryChip(
            label: 'ESC',
            color: AxisColors.textDim,
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          ),
        ],
      ),
    );
  }
}
