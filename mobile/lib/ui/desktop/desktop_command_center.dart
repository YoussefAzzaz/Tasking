import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/desktop/widgets/desktop_titlebar.dart';
import 'package:axis/ui/desktop/widgets/desktop_sidebar.dart';
import 'package:axis/ui/desktop/widgets/desktop_habits_column.dart';
import 'package:axis/ui/desktop/widgets/desktop_tasks_column.dart';
import 'package:axis/ui/desktop/widgets/desktop_journal_column.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/focus/focus_screen.dart';
import 'package:axis/ui/me/me_screen.dart';

/// Top-level Windows 11 Desktop Command Center.
/// Matches the Stitch generated design and includes the 3-column workspace layout.
class DesktopCommandCenter extends StatefulWidget {
  const DesktopCommandCenter({super.key});

  @override
  State<DesktopCommandCenter> createState() => _DesktopCommandCenterState();
}

class _DesktopCommandCenterState extends State<DesktopCommandCenter> {
  int _selectedTab = 0; // 0=Command Deck, 1=Habits, 2=Projects, 3=Timers, 4=Journal & Me
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openQuickTask() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTaskSheet(onTaskCreated: () {}),
    );
  }

  void _openOmnibarDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AxisColors.surfaceLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AxisColors.borderPrimary, width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: AxisColors.primary),
              SizedBox(width: 8),
              Text(
                'Global Omnibar Search',
                style: TextStyle(
                  color: AxisColors.textHigh,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AxisColors.textHigh, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tasks, habits, projects, notes...',
                hintStyle: const TextStyle(color: AxisColors.textDim, fontSize: 13),
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AxisColors.textDim),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Clear', style: TextStyle(color: AxisColors.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AxisColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const _QuickTaskIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): const _OmnibarIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1): const _SwitchTabIntent(0),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2): const _SwitchTabIntent(1),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3): const _SwitchTabIntent(2),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit4): const _SwitchTabIntent(3),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit5): const _SwitchTabIntent(4),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _QuickTaskIntent: CallbackAction<_QuickTaskIntent>(
            onInvoke: (_) => _openQuickTask(),
          ),
          _OmnibarIntent: CallbackAction<_OmnibarIntent>(
            onInvoke: (_) => _openOmnibarDialog(),
          ),
          _SwitchTabIntent: CallbackAction<_SwitchTabIntent>(
            onInvoke: (intent) {
              setState(() => _selectedTab = intent.tabIndex);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: const Color(0xFF050811),
            body: Column(
              children: [
                // Top Windows Acrylic Titlebar Chrome
                DesktopTitlebar(
                  onSearchTap: _openOmnibarDialog,
                  searchQuery: _searchQuery,
                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                ),

                // Main Workspace Layout
                Expanded(
                  child: Row(
                    children: [
                      // Left Navigation Sidebar
                      DesktopSidebar(
                        selectedTab: _selectedTab,
                        onTabSelected: (tab) => setState(() => _selectedTab = tab),
                        onQuickTask: _openQuickTask,
                      ),

                      // Center/Main Content View
                      Expanded(
                        child: _buildMainView(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    switch (_selectedTab) {
      case 0: // Command Deck (3-Column Layout from Stitch)
      case 1: // Prayer & Habits
      case 2: // Projects & Tasks
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Column 1: Habits & Prayer Cadence
            Expanded(
              flex: 3,
              child: DesktopHabitsColumn(searchFilter: _searchQuery),
            ),

            // Column 2: Master Task Matrix & Projects Deck
            Expanded(
              flex: 4,
              child: DesktopTasksColumn(
                searchFilter: _searchQuery,
                onAddTask: _openQuickTask,
              ),
            ),

            // Column 3: Daily Markdown Journal & Milestones
            const Expanded(
              flex: 3,
              child: DesktopJournalColumn(),
            ),
          ],
        );
      case 3: // Task Timers / Focus Mode
        return const FocusScreen();
      case 4: // Journal & Me / Stats
        return const MeScreen();
      default:
        return const SizedBox();
    }
  }
}

class _QuickTaskIntent extends Intent {
  const _QuickTaskIntent();
}

class _OmnibarIntent extends Intent {
  const _OmnibarIntent();
}

class _SwitchTabIntent extends Intent {
  const _SwitchTabIntent(this.tabIndex);
  final int tabIndex;
}
