import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../data/auth_service.dart';
import '../../../data/powersync_db.dart' show globalUserLevel;
import '../../../data/stats_repository.dart';
import '../../../data/user_profile_repository.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/ghost_button.dart';

/// Desktop left sidebar (270px) with Operator profile, Navigation, and Log Out action.
class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
    this.onNewTask,
  });

  final int selectedTab;
  final ValueChanged<int> onSelectTab;
  final VoidCallback? onNewTask;

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  StreamSubscription<UserStats>? _statsSub;

  @override
  void initState() {
    super.initState();
    UserProfileRepository().getProfile();
    StatsRepository().getUserStats();
    _statsSub = StatsRepository().watchStats().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DesktopLayout.sidebarWidth,
      decoration: const BoxDecoration(
        color: AxisColors.surfaceLowest,
        border: Border(
          right: BorderSide(
            color: AxisColors.borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Block A — Operator Profile (top reorganized title)
          _buildOperatorProfile(),

          const SizedBox(height: 12),

          // Block B — Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              children: [
                _NavItem(
                  index: 0,
                  label: 'Command Deck',
                  shortcut: 'Ctrl + 1',
                  icon: Icons.space_dashboard_rounded,
                  isSelected: widget.selectedTab == 0,
                  onTap: () => widget.onSelectTab(0),
                ),
                _NavItem(
                  index: 1,
                  label: 'Projects & Tasks',
                  shortcut: 'Ctrl + 2',
                  icon: Icons.assignment_rounded,
                  isSelected: widget.selectedTab == 1,
                  onTap: () => widget.onSelectTab(1),
                ),
                _NavItem(
                  index: 2,
                  label: 'Prayer & Habits',
                  shortcut: 'Ctrl + 3',
                  icon: Icons.track_changes_rounded,
                  isSelected: widget.selectedTab == 2,
                  onTap: () => widget.onSelectTab(2),
                ),
                _NavItem(
                  index: 3,
                  label: 'Journal & Vault',
                  shortcut: 'Ctrl + 4',
                  icon: Icons.menu_book_rounded,
                  isSelected: widget.selectedTab == 3,
                  onTap: () => widget.onSelectTab(3),
                ),
                _NavItem(
                  index: 4,
                  label: 'Focus Timers',
                  shortcut: 'Ctrl + 5',
                  icon: Icons.timer_rounded,
                  isSelected: widget.selectedTab == 4,
                  onTap: () => widget.onSelectTab(4),
                ),
                _NavItem(
                  index: 5,
                  label: 'Companions',
                  shortcut: 'Ctrl + 6',
                  icon: Icons.people_alt_rounded,
                  isSelected: widget.selectedTab == 5,
                  onTap: () => widget.onSelectTab(5),
                ),
                _NavItem(
                  index: 6,
                  label: 'Profile & Settings',
                  shortcut: 'Ctrl + 7',
                  icon: Icons.manage_accounts_rounded,
                  isSelected: widget.selectedTab == 6,
                  onTap: () => widget.onSelectTab(6),
                ),
              ],
            ),
          ),

          // Block C — Log Out Button Footer
          _buildLogoutFooter(),
        ],
      ),
    );
  }

  Widget _buildOperatorProfile() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository().profileNotifier,
      builder: (context, profile, _) {
        final name = profile.name.trim().isEmpty ? 'OPERATOR' : profile.name.toUpperCase();
        final avatarUrl = profile.avatarUrl;

        return ValueListenableBuilder<int>(
          valueListenable: globalUserLevel,
          builder: (context, dynamicLevel, _) {
            final effectiveLevel = dynamicLevel > 0
                ? dynamicLevel
                : (profile.level > 0 ? profile.level : 1);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AxisColors.borderSubtle,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Avatar with XP halo
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AxisColors.primarySoft,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? _buildAvatarImage(avatarUrl)
                          : _avatarFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AxisColors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'OPERATOR • LVL $effectiveLevel',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AxisColors.secondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Settings button
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: AxisColors.textMuted,
                    ),
                    tooltip: 'Profile & Settings',
                    onPressed: () => widget.onSelectTab(6),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarImage(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _avatarFallback(),
      );
    }
    // Use async file existence check to avoid blocking the UI isolate
    return FutureBuilder<bool>(
      future: File(url).exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(
            File(url),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _avatarFallback(),
          );
        }
        return _avatarFallback();
      },
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: AxisColors.surfaceHigh,
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          size: 20,
          color: AxisColors.textHigh,
        ),
      ),
    );
  }

  Widget _buildLogoutFooter() {
    final isGuest = AuthService().isGuest;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AxisColors.borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      child: isGuest
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AccentButton(
                  label: 'Sign In to Sync',
                  icon: Icons.cloud_upload_rounded,
                  color: const Color(0xFFF59E0B),
                  isFullWidth: true,
                  onPressed: () => context.go('/auth'),
                ),
                const SizedBox(height: 8),
                GhostButton(
                  label: 'Exit Guest',
                  icon: Icons.logout_rounded,
                  color: AxisColors.textMuted,
                  borderColor: AxisColors.borderSubtle,
                  hoverBackgroundColor: AxisColors.surfaceHigh,
                  isFullWidth: true,
                  onPressed: () async {
                    await AuthService().signOut();
                    if (mounted) {
                      context.go('/auth');
                    }
                  },
                ),
              ],
            )
          : GhostButton(
              label: 'Log Out',
              icon: Icons.logout_rounded,
              color: AxisColors.priorityHigh,
              borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
              hoverBackgroundColor: AxisColors.priorityHigh.withValues(alpha: 0.12),
              isFullWidth: true,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AxisColors.surfaceLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AxisColors.borderSubtle),
                    ),
                    title: Text(
                      'Log Out',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to end your current session?',
                      style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textMuted),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel', style: TextStyle(color: AxisColors.textMuted)),
                      ),
                      AccentButton(
                        label: 'Log Out',
                        color: AxisColors.priorityHigh,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await AuthService().signOut();
                  if (mounted) {
                    context.go('/auth');
                  }
                }
              },
            ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.index,
    required this.label,
    required this.shortcut,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final int index;
  final String label;
  final String shortcut;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color textColor = AxisColors.textMuted;
    Color iconColor = AxisColors.textDim;

    if (widget.isSelected) {
      bg = AxisColors.primary.withValues(alpha: 0.16);
      textColor = AxisColors.textHigh;
      iconColor = AxisColors.primarySoft;
    } else if (_isHovered) {
      bg = AxisColors.surfaceHigh.withValues(alpha: 0.4);
      textColor = AxisColors.textHigh;
      iconColor = AxisColors.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // 3px indicator rail on active
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: widget.isSelected ? AxisColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(
                  widget.icon,
                  size: 17,
                  color: iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.getFont(
                      'Geist',
                      fontSize: 13,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                ),
                Text(
                  widget.shortcut,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isSelected ? AxisColors.primarySoft : AxisColors.textDim,
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
