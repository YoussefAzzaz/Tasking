import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme.dart';
import '../../../data/network_service.dart';
import '../core/desktop_layout.dart';
import '../widgets/telemetry_chip.dart';

/// Top desktop titlebar (44px) with window drag, omnibar trigger, sync status, and window controls.
class DesktopTitlebar extends StatefulWidget {
  const DesktopTitlebar({
    super.key,
    required this.onOpenOmnibar,
  });

  final VoidCallback onOpenOmnibar;

  @override
  State<DesktopTitlebar> createState() => _DesktopTitlebarState();
}

class _DesktopTitlebarState extends State<DesktopTitlebar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this);
      _checkMaximized();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final max = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = max);
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Container(
      height: DesktopLayout.titlebarHeight,
      decoration: const BoxDecoration(
        color: AxisColors.canvasBase,
        border: Border(
          bottom: BorderSide(
            color: AxisColors.borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. App logo & branding (left)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AxisColors.primary, AxisColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: AxisColors.primary.withValues(alpha: 0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.blur_on_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AXIS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AxisColors.textHigh,
                  ),
                ),
                const SizedBox(width: 8),
                const TelemetryChip(
                  label: 'v2.4.0',
                  color: AxisColors.textDim,
                  backgroundColor: Color(0x15FFFFFF),
                  borderColor: Color(0x22FFFFFF),
                  textColor: AxisColors.textDim,
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
              ],
            ),
          ),

          // 2. Drag area & Center Omnibar
          const Expanded(
            child: DragToMoveArea(
              child: SizedBox.expand(),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onOpenOmnibar,
              child: Container(
                width: 440,
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AxisColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: AxisColors.textDim,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search tasks, projects, habits, telemetry, or enter command...',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.getFont(
                          'Geist',
                          fontSize: 11,
                          color: AxisColors.textDim,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AxisColors.borderSubtle, width: 1),
                      ),
                      child: Text(
                        'Ctrl + K',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AxisColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(
            child: DragToMoveArea(
              child: SizedBox.expand(),
            ),
          ),

          // 3. Sync Status Pill
          ValueListenableBuilder<bool>(
            valueListenable: NetworkService().isOnlineNotifier,
            builder: (context, isOnline, _) {
              return TelemetryChip(
                label: isOnline ? 'ONLINE' : 'OFFLINE',
                dotColor: isOnline ? AxisColors.tertiary : AxisColors.warning,
                color: isOnline ? AxisColors.tertiary : AxisColors.warning,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              );
            },
          ),
          const SizedBox(width: 12),

          // 4. Window Control Buttons
          if (isDesktopPlatform) ...[
            _WindowButton(
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon: _isMaximized ? Icons.crop_square_rounded : Icons.crop_din_rounded,
              tooltip: _isMaximized ? 'Restore' : 'Maximize',
              onPressed: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              isClose: true,
              onPressed: () => windowManager.close(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color iconColor = AxisColors.textMuted;

    if (_isHovered) {
      bg = widget.isClose ? const Color(0xFFE81123) : AxisColors.surfaceHighest;
      iconColor = widget.isClose ? Colors.white : AxisColors.textHigh;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 44,
          height: DesktopLayout.titlebarHeight,
          color: bg,
          child: Center(
            child: Icon(
              widget.icon,
              size: 14,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
