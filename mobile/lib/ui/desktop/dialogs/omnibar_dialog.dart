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

/// Top-anchored command palette / omnibar dialog with live grouped search.
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

  List<Task> _tasks = [];
  List<Habit> _habits = [];
  List<Note> _notes = [];
  List<Project> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final tasks = await TaskRepository().watchTasks().first;
    final habits = await HabitRepository().watchHabits().first;
    final notes = await NoteRepository().watchNotes().first;
    final projects = await ProjectRepository().watchProjects().first;

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _habits = habits;
        _notes = notes;
        _projects = projects;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();

    final matchingTasks = q.isEmpty
        ? _tasks.take(4).toList()
        : _tasks.where((t) => t.title.toLowerCase().contains(q)).take(5).toList();

    final matchingHabits = q.isEmpty
        ? _habits.take(3).toList()
        : _habits.where((h) => h.name.toLowerCase().contains(q)).take(4).toList();

    final matchingNotes = q.isEmpty
        ? _notes.take(3).toList()
        : _notes.where((n) => n.title.toLowerCase().contains(q) || n.bodyMd.toLowerCase().contains(q)).take(4).toList();

    final matchingProjects = q.isEmpty
        ? _projects.take(2).toList()
        : _projects.where((p) => p.name.toLowerCase().contains(q)).take(3).toList();

    final hasResults = matchingTasks.isNotEmpty ||
        matchingHabits.isNotEmpty ||
        matchingNotes.isNotEmpty ||
        matchingProjects.isNotEmpty;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
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
              constraints: const BoxConstraints(maxHeight: 520),
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
                            onChanged: (val) => setState(() => _query = val),
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
                            splashRadius: 16,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
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
                    child: hasResults
                        ? ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            children: [
                              if (matchingTasks.isNotEmpty) ...[
                                const SectionHeader(
                                  title: 'TASKS',
                                  padding: EdgeInsets.only(top: 6, bottom: 6),
                                ),
                                ...matchingTasks.map((t) => _buildItemRow(
                                      icon: Icons.check_circle_outline_rounded,
                                      title: t.title,
                                      badge: t.priority == 1 ? 'P1' : null,
                                      badgeColor: AxisColors.priorityHigh,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onNavigateToTab(1); // Projects & Tasks
                                      },
                                    )),
                              ],
                              if (matchingProjects.isNotEmpty) ...[
                                const SectionHeader(
                                  title: 'PROJECTS',
                                  padding: EdgeInsets.only(top: 10, bottom: 6),
                                ),
                                ...matchingProjects.map((p) => _buildItemRow(
                                      icon: Icons.folder_outlined,
                                      title: p.name,
                                      subtitle: 'Project Workspace',
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onNavigateToTab(1); // Projects & Tasks
                                      },
                                    )),
                              ],
                              if (matchingHabits.isNotEmpty) ...[
                                const SectionHeader(
                                  title: 'HABITS',
                                  padding: EdgeInsets.only(top: 10, bottom: 6),
                                ),
                                ...matchingHabits.map((h) => _buildItemRow(
                                      icon: Icons.track_changes_rounded,
                                      title: h.name,
                                      subtitle: '${h.streakDays}d streak',
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onNavigateToTab(2); // Prayer & Habits
                                      },
                                    )),
                              ],
                              if (matchingNotes.isNotEmpty) ...[
                                const SectionHeader(
                                  title: 'NOTES & VAULT',
                                  padding: EdgeInsets.only(top: 10, bottom: 6),
                                ),
                                ...matchingNotes.map((n) => _buildItemRow(
                                      icon: Icons.description_outlined,
                                      title: n.title.isEmpty ? 'Untitled Note' : n.title,
                                      subtitle: n.category,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onNavigateToTab(3); // Journal & Vault
                                      },
                                    )),
                              ],
                            ],
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return _SearchItemRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      badge: badge,
      badgeColor: badgeColor,
      onTap: onTap,
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  @override
  State<_SearchItemRow> createState() => _SearchItemRowState();
}

class _SearchItemRowState extends State<_SearchItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
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
              color: _isHovered ? AxisColors.surfaceHigh.withValues(alpha: 0.6) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: _isHovered ? AxisColors.secondary : AxisColors.textMuted,
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
                      color: _isHovered ? AxisColors.textHigh : AxisColors.textMuted,
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
