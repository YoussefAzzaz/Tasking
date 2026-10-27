import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../data/habit_repository.dart';
import '../../../data/note_repository.dart';
import '../../../data/project_repository.dart';
import '../../../data/task_repository.dart';
import '../widgets/section_header.dart';
import '../widgets/telemetry_chip.dart';

class _OmnibarItem {
  final String category;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _OmnibarItem({
    required this.category,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });
}

/// Top-anchored command palette / omnibar dialog with live grouped search
/// and full arrow-key and Enter keyboard navigation.
class OmnibarDialog extends StatefulWidget {
  const OmnibarDialog({
    super.key,
    required this.onNavigateToTab,
  });

  final ValueChanged<int> onNavigateToTab;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<int> onNavigateToTab,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) => OmnibarDialog(
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }

  @override
  State<OmnibarDialog> createState() => _OmnibarDialogState();
}

class _OmnibarDialogState extends State<OmnibarDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  int _selectedIndex = 0;

  List<Task> _tasks = [];
  List<Habit> _habits = [];
  List<Note> _notes = [];
  List<Project> _projects = [];

  StreamSubscription<List<Task>>? _tasksSub;
  StreamSubscription<List<Habit>>? _habitsSub;
  StreamSubscription<List<Note>>? _notesSub;
  StreamSubscription<List<Project>>? _projectsSub;

  @override
  void initState() {
    super.initState();
    _subscribeToLiveStreams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tasksSub?.cancel();
    _habitsSub?.cancel();
    _notesSub?.cancel();
    _projectsSub?.cancel();
    super.dispose();
  }

  void _subscribeToLiveStreams() {
    _tasksSub = TaskRepository().watchTasks().listen((tasks) {
      if (mounted) setState(() => _tasks = tasks);
    });
    _habitsSub = HabitRepository().watchHabits().listen((habits) {
      if (mounted) setState(() => _habits = habits);
    });
    _notesSub = NoteRepository().watchNotes().listen((notes) {
      if (mounted) setState(() => _notes = notes);
    });
    _projectsSub = ProjectRepository().watchProjects().listen((projects) {
      if (mounted) setState(() => _projects = projects);
    });
  }

  List<_OmnibarItem> _buildItemList(String q) {
    final items = <_OmnibarItem>[];

    // Tasks
    final matchingTasks = q.isEmpty
        ? _tasks.take(4).toList()
        : _tasks.where((t) => t.title.toLowerCase().contains(q)).take(5).toList();
    for (final t in matchingTasks) {
      items.add(_OmnibarItem(
        category: 'TASKS',
        icon: Icons.check_circle_outline_rounded,
        title: t.title,
        badge: t.priority == 1 ? 'P1' : null,
        badgeColor: AxisColors.priorityHigh,
        onTap: () {
          Navigator.of(context).pop();
          widget.onNavigateToTab(1); // Projects & Tasks
        },
      ));
    }

    // Projects
    final matchingProjects = q.isEmpty
        ? _projects.take(2).toList()
        : _projects.where((p) => p.name.toLowerCase().contains(q)).take(3).toList();
    for (final p in matchingProjects) {
      items.add(_OmnibarItem(
        category: 'PROJECTS',
        icon: Icons.folder_outlined,
        title: p.name,
        subtitle: 'Project Workspace',
        onTap: () {
          Navigator.of(context).pop();
          widget.onNavigateToTab(1); // Projects & Tasks
        },
      ));
    }

    // Habits
    final matchingHabits = q.isEmpty
        ? _habits.take(3).toList()
        : _habits.where((h) => h.name.toLowerCase().contains(q)).take(4).toList();
    for (final h in matchingHabits) {
      items.add(_OmnibarItem(
        category: 'HABITS',
        icon: Icons.track_changes_rounded,
        title: h.name,
        subtitle: '${h.streakDays}d streak',
        onTap: () {
          Navigator.of(context).pop();
          widget.onNavigateToTab(2); // Prayer & Habits
        },
      ));
    }

    // Notes & Vault
    final matchingNotes = q.isEmpty
        ? _notes.take(3).toList()
        : _notes.where((n) => n.title.toLowerCase().contains(q) || n.bodyMd.toLowerCase().contains(q)).take(4).toList();
    for (final n in matchingNotes) {
      items.add(_OmnibarItem(
        category: 'NOTES & VAULT',
        icon: Icons.description_outlined,
        title: n.title.isEmpty ? 'Untitled Note' : n.title,
        subtitle: n.category,
        onTap: () {
          Navigator.of(context).pop();
          widget.onNavigateToTab(3); // Journal & Vault
        },
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = _buildItemList(q);

    // Keep selected index within bounds
    if (items.isNotEmpty && _selectedIndex >= items.length) {
      _selectedIndex = items.length - 1;
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown && items.isNotEmpty) {
            setState(() {
              _selectedIndex = (_selectedIndex + 1) % items.length;
            });
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && items.isNotEmpty) {
            setState(() {
              _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
            });
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter && items.isNotEmpty) {
            if (_selectedIndex >= 0 && _selectedIndex < items.length) {
              items[_selectedIndex].onTap();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 80.0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 640,
              constraints: const BoxConstraints(maxHeight: 540),
              decoration: BoxDecoration(
                color: AxisColors.canvasBase,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AxisColors.borderGlass2,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Input Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AxisColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AxisColors.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            autofocus: true,
                            onChanged: (val) {
                              setState(() {
                                _query = val;
                                _selectedIndex = 0;
                              });
                            },
                            style: GoogleFonts.getFont(
                              'Geist',
                              fontSize: 14,
                              color: AxisColors.textHigh,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search tasks, projects, habits, notes or jump to...',
                              hintStyle: GoogleFonts.getFont(
                                'Geist',
                                fontSize: 14,
                                color: AxisColors.textDim,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            color: AxisColors.textDim,
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _selectedIndex = 0;
                              });
                            },
                          ),
                        const TelemetryChip(
                          label: 'ESC',
                          color: AxisColors.textDim,
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      ],
                    ),
                  ),

                  // Results list
                  Flexible(
                    child: items.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isFirstInCategory =
                                  index == 0 || items[index - 1].category != item.category;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isFirstInCategory)
                                    SectionHeader(
                                      title: item.category,
                                      padding: EdgeInsets.only(
                                        top: index == 0 ? 4 : 12,
                                        bottom: 6,
                                      ),
                                    ),
                                  _SearchItemRow(
                                    icon: item.icon,
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    badge: item.badge,
                                    badgeColor: item.badgeColor,
                                    isSelected: index == _selectedIndex,
                                    onTap: item.onTap,
                                  ),
                                ],
                              );
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36.0),
                            child: Center(
                              child: Text(
                                'No matching records found',
                                style: GoogleFonts.getFont(
                                  'Geist',
                                  fontSize: 13,
                                  color: AxisColors.textDim,
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Keyboard Navigation Footer
                  Container(
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
                          style: GoogleFonts.spaceGrotesk(
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
                          style: GoogleFonts.spaceGrotesk(
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
                          style: GoogleFonts.spaceGrotesk(
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchItemRow extends StatefulWidget {
  const _SearchItemRow({
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
  State<_SearchItemRow> createState() => _SearchItemRowState();
}

class _SearchItemRowState extends State<_SearchItemRow> {
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
                    style: GoogleFonts.getFont(
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
                    style: GoogleFonts.spaceGrotesk(
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
