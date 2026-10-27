import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/stats_repository.dart';
import '../../data/user_profile_repository.dart';
import 'core/desktop_shortcuts.dart';
import 'dialogs/omnibar_dialog.dart';
import 'dialogs/quick_task_dialog.dart';
import 'screens/command_deck_screen.dart';
import 'screens/focus_timers_screen.dart';
import 'screens/journal_vault_screen.dart';
import 'screens/prayer_habits_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/projects_tasks_screen.dart';
import 'shell/desktop_sidebar.dart';
import 'shell/desktop_titlebar.dart';

/// Root desktop shell host managing titlebar, sidebar, keyboard routing, and tab views.
class DesktopCommandCenter extends StatefulWidget {
  const DesktopCommandCenter({super.key});

  @override
  State<DesktopCommandCenter> createState() => _DesktopCommandCenterState();
}

class _DesktopCommandCenterState extends State<DesktopCommandCenter> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    unawaited(UserProfileRepository().getProfile());
    unawaited(StatsRepository().getUserStats());
  }

  void _navigateToTab(int tabIndex) {
    if (tabIndex >= 0 && tabIndex <= 5) {
      setState(() => _selectedTab = tabIndex);
    }
  }

  void _openQuickTask() {
    QuickTaskDialog.show(context);
  }

  void _openOmnibar() {
    OmnibarDialog.show(
      context,
      onNavigateToTab: (index) => _navigateToTab(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        DesktopShortcuts.newTask: _openQuickTask,
        DesktopShortcuts.omnibar: _openOmnibar,
        DesktopShortcuts.tab1: () => _navigateToTab(0),
        DesktopShortcuts.tab2: () => _navigateToTab(1),
        DesktopShortcuts.tab3: () => _navigateToTab(2),
        DesktopShortcuts.tab4: () => _navigateToTab(3),
        DesktopShortcuts.tab5: () => _navigateToTab(4),
        DesktopShortcuts.tab6: () => _navigateToTab(5),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AxisColors.canvasBase,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Titlebar
              DesktopTitlebar(
                onOpenOmnibar: _openOmnibar,
              ),

              // 2. Main Body: Sidebar (270px) + Active Screen Area
              Expanded(
                child: Row(
                  children: [
                    // Sidebar
                    DesktopSidebar(
                      selectedTab: _selectedTab,
                      onSelectTab: _navigateToTab,
                      onNewTask: _openQuickTask,
                    ),

                    // Main Content Area
                    Expanded(
                      child: Container(
                        color: AxisColors.canvasBase,
                        child: IndexedStack(
                          index: _selectedTab,
                          children: [
                            CommandDeckScreen(
                              onNavigateToTab: _navigateToTab,
                              onOpenNewTaskDialog: _openQuickTask,
                            ),
                            ProjectsTasksScreen(
                              onNavigateToTab: _navigateToTab,
                            ),
                            const PrayerHabitsScreen(),
                            const JournalVaultScreen(),
                            const FocusTimersScreen(),
                            const ProfileSettingsScreen(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
