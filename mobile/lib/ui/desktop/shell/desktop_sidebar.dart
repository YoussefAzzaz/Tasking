import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme.dart';
import '../../../data/user_profile_repository.dart';
import '../core/desktop_layout.dart';
import '../services/desktop_file_service.dart';
import '../widgets/accent_button.dart';
import '../widgets/progress_gauge.dart';
import '../widgets/telemetry_chip.dart';

/// Desktop left sidebar (270px) with Operator profile, CTA, Navigation, and Local Vault telemetry.
class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
    required this.onNewTask,
  });

  final int selectedTab;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onNewTask;

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  String _dbSize = '18.4 MB';

  @override
  void initState() {
    super.initState();
    UserProfileRepository().getProfile();
    _loadStorageTelemetry();
  }

  Future<void> _loadStorageTelemetry() async {
    final size = await DesktopFileService().getLocalDatabaseSize();
    if (mounted) setState(() => _dbSize = size);
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
          // Block A — Operator Profile (top)
          _buildOperatorProfile(),

          // Block B — New Task CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: AccentButton(
              label: 'New Task',
              shortcutLabel: 'Ctrl + N',
              isFullWidth: true,
              icon: Icons.add_rounded,
              onPressed: widget.onNewTask,
            ),
          ),

          const SizedBox(height: 8),

          // Block C — Navigation Items
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
                  label: 'Prayer & Habits',
                  shortcut: 'Ctrl + 2',
                  icon: Icons.track_changes_rounded,
                  isSelected: widget.selectedTab == 1,
                  onTap: () => widget.onSelectTab(1),
                ),
                _NavItem(
                  index: 2,
                  label: 'Projects & Tasks',
                  shortcut: 'Ctrl + 3',
                  icon: Icons.assignment_rounded,
                  isSelected: widget.selectedTab == 2,
                  onTap: () => widget.onSelectTab(2),
                ),
                _NavItem(
                  index: 3,
                  label: 'Focus Timers',
                  shortcut: 'Ctrl + 4',
                  icon: Icons.timer_rounded,
                  isSelected: widget.selectedTab == 3,
                  onTap: () => widget.onSelectTab(3),
                ),
                _NavItem(
                  index: 4,
                  label: 'Journal & Vault',
                  shortcut: 'Ctrl + 5',
                  icon: Icons.menu_book_rounded,
                  isSelected: widget.selectedTab == 4,
                  onTap: () => widget.onSelectTab(4),
                ),
                _NavItem(
                  index: 5,
                  label: 'Profile & Settings',
                  shortcut: 'Ctrl + 6',
                  icon: Icons.tune_rounded,
                  isSelected: widget.selectedTab == 5,
                  onTap: () => widget.onSelectTab(5),
                ),
              ],
            ),
          ),

          // Block D — Local Vault (pinned to bottom)
          _buildLocalVaultFooter(),
        ],
      ),
    );
  }

  Widget _buildOperatorProfile() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository().profileNotifier,
      builder: (context, profile, _) {
        final name = profile.name.trim().isEmpty ? 'OPERATOR' : profile.name.toUpperCase();
        final level = profile.level > 0 ? profile.level : 1;
        final avatarUrl = profile.avatarUrl;

        return Container(
          padding: const EdgeInsets.all(16.0),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AxisColors.primarySoft,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _avatarFallback(),
                        )
                      : _avatarFallback(),
                ),
              ),
              const SizedBox(width: 12),
              // Name + Level
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$name // OPERATOR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'LEVEL $level • CORE PRO',
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
              // Settings gear icon
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: AxisColors.textMuted,
                ),
                splashRadius: 18,
                tooltip: 'Profile & Settings (Ctrl + 6)',
                onPressed: () => widget.onSelectTab(5),
              ),
            ],
          ),
        );
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

  Widget _buildLocalVaultFooter() {
    return Container(
      margin: const EdgeInsets.all(12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: DesktopLayout.borderRadiusBadge,
        border: Border.all(
          color: AxisColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.storage_rounded,
                      size: 13,
                      color: AxisColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'LOCAL-FIRST SQLITE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AxisColors.textHigh,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const TelemetryChip(
                label: 'INTEGRITY OK',
                color: AxisColors.tertiary,
                dotColor: AxisColors.tertiary,
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$_dbSize / 1,280 rows',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AxisColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          const ProgressGauge(
            value: 0.28,
            color: AxisColors.secondary,
            height: 4.0,
          ),
        ],
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
