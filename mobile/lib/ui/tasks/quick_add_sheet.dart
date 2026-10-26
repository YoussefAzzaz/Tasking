import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/text_direction.dart';
import 'package:axis/domain/quick_add_parser.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/domain/id_generator.dart';

/// Public sheet — called directly from the nav bar orb
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, required this.onTaskAdded});
  final VoidCallback onTaskAdded;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  QuickAddResult? _parsed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _parsed = _controller.text.trim().isEmpty
          ? null
          : QuickAddParser.parse(_controller.text);
    });
  }

  void _insertToken(String token) {
    final text = _controller.text;
    final space = text.isNotEmpty && !text.endsWith(' ') ? ' ' : '';
    _controller.text = '$text$space$token ';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);

    final parsed = QuickAddParser.parse(text);
    final task = Task(
      id: IdGenerator.generateDeterministicId(
          'task_${DateTime.now().microsecondsSinceEpoch}_$text'),
      title: parsed.title.isEmpty ? text : parsed.title,
      priority: parsed.priority,
      projectId: parsed.project,
      dueDate: parsed.dueDate,
      dueTime: parsed.dueTime,
      estimateMin: parsed.estimate,
      recurrenceRule: parsed.recurrence,
      tags: parsed.tags.join(','),
    );

    await TaskRepository().addTask(task);

    for (final tag in parsed.tags) {
      final clean = tag.trim().replaceAll('@', '');
      if (clean.isNotEmpty) {
        await TagRepository().addTag(clean);
      }
    }

    if (mounted) Navigator.pop(context);
    widget.onTaskAdded();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return FocusScope(
      autofocus: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: SafeArea(
            bottom: true,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
        decoration: BoxDecoration(
          color: const Color(0xF5131A2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AxisColors.borderGlass2,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.flash_on_rounded,
                            color: AxisColors.primary, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'QUICK ADD TASK',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AxisColors.primarySoft,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AxisColors.textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Input field
              AutoDirectionScope(
                controller: _controller,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: false,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AxisColors.textHigh,
                      ),
                  cursorColor: AxisColors.primary,
                  decoration: InputDecoration(
                    hintText: 'e.g. Finish report p1 @work #core today 30m',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AxisColors.textDim,
                        ),
                    filled: true,
                    fillColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AxisColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AxisColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AxisColors.primary, width: 1.5),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: _saving
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AxisColors.primary),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded,
                                color: AxisColors.primary, size: 20),
                            onPressed: _save,
                          ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: 14),

              // Live parsed tokens (when typing)
              if (_parsed != null) ...[
                Text(
                  'DETECTED ATTRIBUTES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AxisColors.primarySoft,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLow.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AxisColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (_parsed!.title.isNotEmpty)
                        _AttributeBadge(
                          icon: Icons.title_rounded,
                          label: 'Task',
                          value: _parsed!.title,
                          color: AxisColors.textHigh,
                        ),
                      if (_parsed!.priority != null)
                        _AttributeBadge(
                          icon: Icons.flag_rounded,
                          label: 'Priority',
                          value: 'P${_parsed!.priority}',
                          color: _parsed!.priority == 1
                              ? AxisColors.priorityHigh
                              : _parsed!.priority == 2
                                  ? AxisColors.priorityMed
                                  : AxisColors.priorityLow,
                        ),
                      if (_parsed!.project != null)
                        _AttributeBadge(
                          icon: Icons.folder_rounded,
                          label: 'Project',
                          value: '#${_parsed!.project}',
                          color: AxisColors.secondary,
                        ),
                      ..._parsed!.tags.map((t) => _AttributeBadge(
                            icon: Icons.label_rounded,
                            label: 'Tag',
                            value: '@$t',
                            color: AxisColors.primary,
                          )),
                      if (_parsed!.dueDate != null)
                        _AttributeBadge(
                          icon: Icons.calendar_today_rounded,
                          label: 'Due Date',
                          value: _parsed!.dueDate!,
                          color: AxisColors.tertiary,
                        ),
                      if (_parsed!.dueTime != null)
                        _AttributeBadge(
                          icon: Icons.access_time_rounded,
                          label: 'Due Time',
                          value: _parsed!.dueTime!,
                          color: AxisColors.primarySoft,
                        ),
                      if (_parsed!.estimate != null)
                        _AttributeBadge(
                          icon: Icons.timer_outlined,
                          label: 'Duration',
                          value: '${_parsed!.estimate}m',
                          color: AxisColors.secondarySoft,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Quick tap helper tokens
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TAP TO ADD TOKEN',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AxisColors.textMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TokenInsertChip(
                      label: 'p1 (High)',
                      color: AxisColors.priorityHigh,
                      onTap: () => _insertToken('p1'),
                    ),
                    const SizedBox(width: 6),
                    _TokenInsertChip(
                      label: 'p2 (Med)',
                      color: AxisColors.priorityMed,
                      onTap: () => _insertToken('p2'),
                    ),
                    const SizedBox(width: 6),
                    _TokenInsertChip(
                      label: '@tag (Tag)',
                      color: AxisColors.primary,
                      onTap: () => _insertToken('@'),
                    ),
                    const SizedBox(width: 6),
                    _TokenInsertChip(
                      label: '#work (Project)',
                      color: AxisColors.secondary,
                      onTap: () => _insertToken('#work'),
                    ),
                    const SizedBox(width: 6),
                    _TokenInsertChip(
                      label: 'today (Date)',
                      color: AxisColors.tertiary,
                      onTap: () => _insertToken('today'),
                    ),
                    const SizedBox(width: 6),
                    _TokenInsertChip(
                      label: 'tmr (Date)',
                      color: AxisColors.tertiary,
                      onTap: () => _insertToken('tmr'),
                    ),
                    const SizedBox(width: 6),
                    _TokenInsertChip(
                      label: '30m (Est)',
                      color: AxisColors.secondarySoft,
                      onTap: () => _insertToken('30m'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Format meaning guide
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLow.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: AxisColors.secondary),
                        const SizedBox(width: 6),
                        Text(
                          'SYNTAX GUIDE (WHAT EACH PART MEANS)',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AxisColors.secondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _GuideRow(
                      part: 'Task Name',
                      meaning: 'Any plain text at the start',
                      example: 'Review budget',
                      color: AxisColors.textHigh,
                    ),
                    const Divider(color: AxisColors.borderSubtle, height: 12),
                    _GuideRow(
                      part: 'Priority',
                      meaning: 'p1 = High, p2 = Medium, p3 = Low',
                      example: 'p1',
                      color: AxisColors.priorityHigh,
                    ),
                    const Divider(color: AxisColors.borderSubtle, height: 12),
                    _GuideRow(
                      part: 'Tag',
                      meaning: 'Starts with @ (categories/contexts)',
                      example: '@finance, @urgent',
                      color: AxisColors.primary,
                    ),
                    const Divider(color: AxisColors.borderSubtle, height: 12),
                    _GuideRow(
                      part: 'Project',
                      meaning: 'Starts with # (group related tasks)',
                      example: '#launch, #core',
                      color: AxisColors.secondary,
                    ),
                    const Divider(color: AxisColors.borderSubtle, height: 12),
                    _GuideRow(
                      part: 'Due Date',
                      meaning: 'today, tmr, mon, or YYYY-MM-DD',
                      example: 'today, tmr, at 5pm',
                      color: AxisColors.tertiary,
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
),
);
}
}

class _AttributeBadge extends StatelessWidget {
  const _AttributeBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenInsertChip extends StatelessWidget {
  const _TokenInsertChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.part,
    required this.meaning,
    required this.example,
    required this.color,
  });

  final String part;
  final String meaning;
  final String example;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 75,
          child: Text(
            part,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            meaning,
            style: const TextStyle(
              fontSize: 11,
              color: AxisColors.textDim,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            example,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: AxisColors.textHigh,
            ),
          ),
        ),
      ],
    );
  }
}

/// Standalone orb button (used in screens, separate from nav bar orb)
class QuickAddButton extends StatelessWidget {
  const QuickAddButton({super.key, required this.onTaskAdded});
  final VoidCallback onTaskAdded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => QuickAddSheet(onTaskAdded: onTaskAdded),
      ),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AxisColors.primary, AxisColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AxisColors.primary.withValues(alpha: 0.45),
              blurRadius: 20,
              spreadRadius: -4,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded,
            color: AxisColors.textHigh, size: 28),
      ),
    );
  }
}
