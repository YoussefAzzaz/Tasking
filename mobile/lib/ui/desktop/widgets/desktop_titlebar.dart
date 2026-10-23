import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/data/powersync_db.dart' show globalUserLevel;

/// Windows Acrylic & Titlebar Chrome.
/// Houses the brand logo, Omnibar global search, real-time sync telemetry, and window controls.
class DesktopTitlebar extends StatefulWidget {
  const DesktopTitlebar({
    super.key,
    required this.onSearchTap,
    this.searchQuery = '',
    this.onSearchChanged,
  });

  final VoidCallback onSearchTap;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;

  @override
  State<DesktopTitlebar> createState() => _DesktopTitlebarState();
}

class _DesktopTitlebarState extends State<DesktopTitlebar> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(_now);
    final timezoneOffset = _now.timeZoneOffset.isNegative
        ? 'UTC-${_now.timeZoneOffset.inHours.abs()}'
        : 'UTC+${_now.timeZoneOffset.inHours}';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF070B16),
        border: const Border(
          bottom: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Left: App Brand & Version Tag
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    cacheWidth: 52,
                    cacheHeight: 52,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AXIS // Command Center',
                style: TextStyle(
                  color: AxisColors.textHigh,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: const Text(
                  'v2.4',
                  style: TextStyle(
                    color: AxisColors.textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Center: Omnibar Global Search Bar
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: InkWell(
                  onTap: widget.onSearchTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 14,
                          color: AxisColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.searchQuery.isEmpty
                                ? 'Search tasks, habits, projects, notes...'
                                : widget.searchQuery,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.searchQuery.isEmpty
                                  ? AxisColors.textDim
                                  : AxisColors.textHigh,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLow,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: const Text(
                            'Ctrl + K',
                            style: TextStyle(
                              color: AxisColors.textDim,
                              fontSize: 9,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Right: Real-time Telemetry & Sync Status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cloud Sync Status Pill
              ValueListenableBuilder<bool>(
                valueListenable: NetworkService().isOnlineNotifier,
                builder: (context, isOnline, _) {
                  final dotColor = isOnline ? AxisColors.tertiary : AxisColors.warning;
                  final label = isOnline ? 'SYNC: ONLINE' : 'SYNC: LOCAL DB';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: dotColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            color: dotColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(width: 10),

              // Player Level Capsule
              ValueListenableBuilder<int>(
                valueListenable: globalUserLevel,
                builder: (context, lvl, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AxisColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AxisColors.secondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: AxisColors.secondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'LVL $lvl',
                          style: const TextStyle(
                            color: AxisColors.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(width: 12),

              // Clock & Telemetry
              Text(
                '$timeStr $timezoneOffset',
                style: const TextStyle(
                  color: AxisColors.textDim,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(width: 16),

              // Windows Window Controls (Minimize, Maximize, Close)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WindowControlIcon(
                    icon: Icons.remove_rounded,
                    tooltip: 'Minimize',
                    onTap: () {},
                  ),
                  const SizedBox(width: 4),
                  _WindowControlIcon(
                    icon: Icons.crop_square_rounded,
                    tooltip: 'Maximize',
                    onTap: () {},
                  ),
                  const SizedBox(width: 4),
                  _WindowControlIcon(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    isClose: true,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WindowControlIcon extends StatelessWidget {
  const _WindowControlIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: isClose
            ? Colors.red.withValues(alpha: 0.8)
            : AxisColors.surfaceHighest,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: AxisColors.textMuted,
          ),
        ),
      ),
    );
  }
}
