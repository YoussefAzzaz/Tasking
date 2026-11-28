import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/typography.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:powersync/powersync.dart' show SyncStatus;
import 'package:window_manager/window_manager.dart';

import '../../../core/theme.dart';
import '../../../core/l10n/locale_service.dart';
import '../../../data/auth_service.dart';
import '../../../data/friend_repository.dart';
import '../../../data/network_service.dart';
import '../../../data/powersync_db.dart';
import '../core/desktop_layout.dart';
import '../widgets/telemetry_chip.dart';
import '../widgets/desktop_live_clock.dart';

/// Top desktop titlebar (44px) with window drag, omnibar trigger, clock, sync status,
/// and native window control buttons (Minimize, Maximize / Fullscreen, Exit) pinned to the max right.
class DesktopTitlebar extends StatefulWidget {
  const DesktopTitlebar({
    super.key,
    this.onOpenOmnibar,
  });

  final VoidCallback? onOpenOmnibar;

  @override
  State<DesktopTitlebar> createState() => _DesktopTitlebarState();
}

class _DesktopTitlebarState extends State<DesktopTitlebar> with WindowListener {
  bool _isMaximized = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        windowManager.addListener(this);
        _checkWindowState();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        windowManager.removeListener(this);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _checkWindowState() async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final max = await windowManager.isMaximized();
        final fs = await windowManager.isFullScreen();
        if (mounted) {
          setState(() {
            _isMaximized = max;
            _isFullScreen = fs;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullScreen = false);
  }

  @override
  void onWindowRestore() {
    _checkWindowState();
  }

  @override
  void onWindowResized() {
    _checkWindowState();
  }

  Future<void> _handleMinimize() async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final isMin = await windowManager.isMinimized();
        if (isMin) {
          await windowManager.restore();
        } else {
          await windowManager.minimize();
        }
      }
    } catch (e) {
      debugPrint('[Titlebar] Minimize error: $e');
    }
  }

  Future<void> _handleMaximizeOrFullscreen() async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        if (_isFullScreen) {
          await windowManager.setFullScreen(false);
          if (mounted) setState(() => _isFullScreen = false);
        } else {
          final isMax = await windowManager.isMaximized();
          if (isMax) {
            await windowManager.unmaximize();
            if (mounted) setState(() => _isMaximized = false);
          } else {
            await windowManager.maximize();
            if (mounted) setState(() => _isMaximized = true);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isMaximized = !_isMaximized;
            _isFullScreen = _isMaximized;
          });
        }
      }
    } catch (e) {
      debugPrint('[Titlebar] Maximize/Fullscreen error: $e');
      if (mounted) {
        setState(() => _isMaximized = !_isMaximized);
      }
    }
  }

  Future<void> _handleClose() async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await windowManager.close();
      } else {
        await SystemNavigator.pop();
      }
    } catch (e) {
      debugPrint('[Titlebar] Close error: $e');
      try {
        await SystemNavigator.pop();
      } catch (_) {}
    }
  }

  Widget _buildClockWidget() {
    return DesktopLiveClock(
      builder: (context, now) {
        final dateStr = DateFormat('EEE, d MMM').format(now);
        final timeStr = DateFormat('hh:mm a').format(now);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLowest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AxisColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 11,
                color: AxisColors.secondary,
              ),
              const SizedBox(width: 5),
              Text(
                dateStr,
                style: AxisFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AxisColors.textHigh,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 10,
                color: AxisColors.borderSubtle,
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.schedule_rounded,
                size: 11,
                color: AxisColors.primarySoft,
              ),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: AxisFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.primarySoft,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOmnibarTrigger() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenOmnibar,
        child: Container(
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
                  LocaleService().isArabic
                      ? 'ابحث في المهام، المشاريع، العادات، أو اكتب أمراً...'
                      : 'Search tasks, projects, habits, telemetry, or enter command...',
                  overflow: TextOverflow.ellipsis,
                  style: AxisFonts.getFont(
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
                  style: AxisFonts.spaceGrotesk(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Desktop top bar remains strictly in LTR layout so brand logo/clock stay on the left
    // and native window controls stay pinned to the top right even in Arabic RTL mode.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final canCenterGlobally = totalWidth >= 1150;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Edge-to-edge draggable window title bar background with double-click maximize/restore
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: _handleMaximizeOrFullscreen,
                  child: const DragToMoveArea(
                    child: SizedBox.expand(),
                  ),
                ),
              ),

              // 2. Left Cluster: Logo + AXIS + Separator + Clock + Sync Status (Pinned to Left: 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Logo & Title
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: AxisColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AXIS',
                            style: AxisFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AxisColors.textHigh,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Separator Divider
                    Container(
                      width: 1,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: AxisColors.borderSubtle,
                    ),

                    // Dynamic Clock Widget
                    _buildClockWidget(),
                    const SizedBox(width: 8),

                    // Sync Status Pill
                    ValueListenableBuilder<bool>(
                      valueListenable: AuthService().sessionExpiredNotifier,
                      builder: (context, isExpired, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: AuthService().authStateNotifier,
                          builder: (context, isAuthState, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: NetworkService().isOnlineNotifier,
                              builder: (context, isOnline, _) {
                                return StreamBuilder<SyncStatus>(
                                  stream: isDatabaseInitialized
                                      ? db.statusStream
                                      : const Stream<SyncStatus>.empty(),
                                  initialData:
                                      isDatabaseInitialized ? db.currentStatus : null,
                                  builder: (context, snapshot) {
                                    final syncStatus = snapshot.data;
                                    final hasDb = isDatabaseInitialized;
                                    final isDbConnected =
                                        syncStatus?.connected ?? (hasDb && db.connected);
                                    final isDbConnecting =
                                        syncStatus?.connecting ?? false;
                                    final hasSyncError = syncStatus?.anyError != null;
                                    final isAuth =
                                        isAuthState || AuthService().isAuthenticated;

                                    if (!Platform.environment.containsKey('FLUTTER_TEST') &&
                                        isOnline &&
                                        hasDb &&
                                        isAuth &&
                                        !isExpired &&
                                        !isDbConnected &&
                                        !isDbConnecting &&
                                        !hasSyncError) {
                                      unawaited(ensurePowerSyncConnected());
                                    }

                                    final String label;
                                    final Color chipColor;
                                    if (!isOnline) {
                                      label = 'OFFLINE';
                                      chipColor = AxisColors.warning;
                                    } else if (isExpired) {
                                      label = 'EXPIRED';
                                      chipColor = AxisColors.error;
                                    } else if (!hasDb || !isAuth) {
                                      label = 'ONLINE';
                                      chipColor = AxisColors.tertiary;
                                    } else if (hasSyncError) {
                                      label = 'SYNC ERR';
                                      chipColor = AxisColors.error;
                                    } else if (isDbConnected) {
                                      label = 'SYNCED';
                                      chipColor = AxisColors.tertiary;
                                    } else if (isDbConnecting) {
                                      label = 'SYNCING';
                                      chipColor = AxisColors.secondary;
                                    } else {
                                      label = 'LOCAL';
                                      chipColor = AxisColors.warning;
                                    }

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          if (isOnline && isExpired) {
                                            final router = GoRouter.maybeOf(context);
                                            AuthService().trySilentReAuthWithSavedCredentials().then((ok) {
                                              if (ok) {
                                                ensurePowerSyncConnected(forceReconnect: true);
                                              } else {
                                                router?.go('/auth');
                                              }
                                            });
                                            return;
                                          }
                                          unawaited(
                                            ensurePowerSyncConnected(
                                              forceReconnect: true,
                                            ),
                                          );
                                          unawaited(
                                            FriendRepository().syncAllFriendData(),
                                          );
                                        },
                                        child: TelemetryChip(
                                          label: label,
                                          dotColor: chipColor,
                                          color: chipColor,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 3. Center Cluster: Omnibar Search Trigger or Terminal Status Banner
              if (widget.onOpenOmnibar != null) ...[
                if (canCenterGlobally)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _buildOmnibarTrigger(),
                    ),
                  )
                else
                  Positioned(
                    left: 375,
                    right: 145,
                    top: 7,
                    bottom: 7,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _buildOmnibarTrigger(),
                      ),
                    ),
                  ),
              ] else ...[
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 13,
                        color: AxisColors.primarySoft,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'OPERATOR ACCESS TERMINAL // POWERSYNC GATEWAY',
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 4. Right Cluster: Window Control Buttons PINNED FLUSH TO TOP-RIGHT CORNER (right: 0)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  height: DesktopLayout.titlebarHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Tooltip(
                        message: 'Minimize',
                        waitDuration: const Duration(milliseconds: 300),
                        child: WindowCaptionButton.minimize(
                          brightness: Brightness.dark,
                          onPressed: _handleMinimize,
                        ),
                      ),
                      Tooltip(
                        message: (_isMaximized || _isFullScreen) ? 'Restore' : 'Maximize / Fullscreen',
                        waitDuration: const Duration(milliseconds: 300),
                        child: (_isMaximized || _isFullScreen)
                            ? WindowCaptionButton.unmaximize(
                                brightness: Brightness.dark,
                                onPressed: _handleMaximizeOrFullscreen,
                              )
                            : WindowCaptionButton.maximize(
                                brightness: Brightness.dark,
                                onPressed: _handleMaximizeOrFullscreen,
                              ),
                      ),
                      Tooltip(
                        message: 'Exit',
                        waitDuration: const Duration(milliseconds: 300),
                        child: WindowCaptionButton.close(
                          brightness: Brightness.dark,
                          onPressed: _handleClose,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
    );
  }
}
