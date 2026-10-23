import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/powersync_db.dart' show globalUserLevel;
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'package:axis/ui/desktop/services/desktop_file_service.dart';

/// Desktop Left Navigation Rail and Local Storage Hub.
class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onQuickTask,
  });

  final int selectedTab; // 0=Command Deck, 1=Prayer & Habits, 2=Projects, 3=Timers, 4=Journal & XP
  final ValueChanged<int> onTabSelected;
  final VoidCallback onQuickTask;

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  String _dbSize = '18.4 MB';

  @override
  void initState() {
    super.initState();
    _loadDatabaseSize();
  }

  Future<void> _loadDatabaseSize() async {
    final size = await DesktopFileService().getLocalDatabaseSize();
    if (mounted) setState(() => _dbSize = size);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF070B16),
        border: Border(
          right: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Operator Profile Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: ValueListenableBuilder<UserProfile>(
              valueListenable: UserProfileRepository().profileNotifier,
              builder: (context, profile, _) {
                return Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: 0.78,
                            strokeWidth: 2,
                            backgroundColor: AxisColors.borderSubtle,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AxisColors.primary,
                            ),
                          ),
                        ),
                        AvatarWidget(
                          avatarUrl: profile.avatarUrl,
                          name: profile.name,
                          avatarColor: profile.avatarColor,
                          size: 32,
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.name.isNotEmpty ? profile.name : 'Operator',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AxisColors.textHigh,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              ValueListenableBuilder<int>(
                                valueListenable: globalUserLevel,
                                builder: (context, lvl, _) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AxisColors.secondary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'L$lvl',
                                    style: const TextStyle(
                                      color: AxisColors.secondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Local Vault • Synced',
                            style: TextStyle(
                              color: AxisColors.tertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. Primary CTA: Quick Task
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AxisColors.primary.withValues(alpha: 0.15),
                foregroundColor: AxisColors.primary,
                side: BorderSide(color: AxisColors.primary.withValues(alpha: 0.5)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: widget.onQuickTask,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Quick Task',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Ctrl+N',
                    style: TextStyle(
                      fontSize: 9,
                      color: AxisColors.textDim,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Navigation Items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  _SidebarNavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Command Deck',
                    shortcut: 'Ctrl+1',
                    isSelected: widget.selectedTab == 0,
                    onTap: () => widget.onTabSelected(0),
                  ),
                  _SidebarNavItem(
                    icon: Icons.loop_rounded,
                    label: 'Prayer & Habits',
                    shortcut: 'Ctrl+2',
                    badge: '8',
                    isSelected: widget.selectedTab == 1,
                    onTap: () => widget.onTabSelected(1),
                  ),
                  _SidebarNavItem(
                    icon: Icons.folder_special_rounded,
                    label: 'Projects & Tasks',
                    shortcut: 'Ctrl+3',
                    badge: '12',
                    isSelected: widget.selectedTab == 2,
                    onTap: () => widget.onTabSelected(2),
                  ),
                  _SidebarNavItem(
                    icon: Icons.timer_outlined,
                    label: 'Task Timers',
                    shortcut: 'Ctrl+4',
                    isSelected: widget.selectedTab == 3,
                    onTap: () => widget.onTabSelected(3),
                  ),
                  _SidebarNavItem(
                    icon: Icons.auto_stories_rounded,
                    label: 'Journal & XP',
                    shortcut: 'Ctrl+5',
                    isSelected: widget.selectedTab == 4,
                    onTap: () => widget.onTabSelected(4),
                  ),
                ],
              ),
            ),
          ),

          // 4. Windows File Vault & Local Storage Section
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 13, color: AxisColors.primary),
                        SizedBox(width: 5),
                        Text(
                          'Local Vault DB',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _dbSize,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.tertiary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    value: 0.24,
                    minHeight: 3,
                    backgroundColor: AxisColors.surfaceHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(AxisColors.primary),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final path = await DesktopFileService().exportBackupJson();
                          if (context.mounted && path != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Backup exported to $path'),
                                backgroundColor: AxisColors.surfaceLow,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AxisColors.borderSubtle),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 11, color: AxisColors.textMuted),
                              SizedBox(width: 3),
                              Text(
                                'Export .json',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () => DesktopFileService().openLocalVaultFolder(),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AxisColors.borderSubtle),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 11, color: AxisColors.textMuted),
                              SizedBox(width: 3),
                              Text(
                                'Open Vault',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String shortcut;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AxisColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AxisColors.primary.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AxisColors.primarySoft : AxisColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AxisColors.textHigh : AxisColors.textMuted,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.textDim,
                    ),
                  ),
                )
              else
                Text(
                  shortcut,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AxisColors.textDim,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
