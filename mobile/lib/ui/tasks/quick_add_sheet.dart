import 'package:flutter/material.dart';

import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/domain/quick_add_parser.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/id_generator.dart';

/// The floating Quick-Add orb + bottom sheet — Obsidian Kinetic design
class QuickAddButton extends StatelessWidget {
  const QuickAddButton({super.key, required this.onTaskAdded});
  final VoidCallback onTaskAdded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AxisColors.primary, AxisColors.secondary],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AxisColors.primary.withOpacity(0.45),
              blurRadius: 20, spreadRadius: -4,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded,
            color: AxisColors.textHigh, size: 28),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickAddSheet(onTaskAdded: onTaskAdded),
    );
  }
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({required this.onTaskAdded});
  final VoidCallback onTaskAdded;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _controller = TextEditingController();
  QuickAddResult? _parsed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _parsed = _controller.text.trim().isEmpty
          ? null
          : QuickAddParser.parse(_controller.text);
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;

    setState(() => _saving = true);
    final parsed = QuickAddParser.parse(text);
    final task = Task(
      id: IdGenerator.generateDeterministicId('task_${DateTime.now().microsecondsSinceEpoch}_$text'),
      title: parsed.title.isEmpty ? text : parsed.title,
      priority: parsed.priority,
      dueDate: parsed.dueDate,
      dueTime: parsed.dueTime,
      estimateMin: parsed.estimate,
      recurrenceRule: parsed.recurrence,
      tags: parsed.tags.join(','),
    );

    await TaskRepository().addTask(task);
    if (mounted) Navigator.pop(context);
    widget.onTaskAdded();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: AxisCard(
        tier: GlassTier.two,
        accentBorder: true,
        borderRadius: 20,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AxisColors.borderSubtle,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),

            // Input
            TextField(
              controller: _controller,
              autofocus: true,
              style: Theme.of(context).textTheme.bodyLarge,
              cursorColor: AxisColors.primary,
              decoration: InputDecoration(
                hintText: 'Buy milk p1 @groceries today...',
                hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AxisColors.textDim,
                ),
                filled: true,
                fillColor: AxisColors.surfaceHigh.withOpacity(0.5),
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded,
                          color: AxisColors.primary, size: 20),
                  onPressed: _save,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),

            // Live-parsed chips
            if (_parsed != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: [
                  if (_parsed!.title.isNotEmpty)
                    AxisChip(
                      label: _parsed!.title,
                      backgroundColor: AxisColors.surfaceHigh.withOpacity(0.5),
                      textColor: AxisColors.textHigh,
                    ),
                  if (_parsed!.priority != null)
                    PriorityChip(priority: _parsed!.priority!),
                  if (_parsed!.dueDate != null)
                    AxisChip(
                      label: _parsed!.dueDate!,
                      dotColor: AxisColors.secondary,
                      backgroundColor: AxisColors.secondary.withOpacity(0.10),
                      textColor: AxisColors.secondarySoft,
                    ),
                  if (_parsed!.dueTime != null)
                    AxisChip(
                      label: '⏰ ${_parsed!.dueTime!}',
                      backgroundColor: AxisColors.primary.withOpacity(0.10),
                      textColor: AxisColors.primarySoft,
                    ),
                  if (_parsed!.estimate != null)
                    AxisChip(
                      label: '${_parsed!.estimate}m',
                      backgroundColor: AxisColors.secondary.withOpacity(0.10),
                      textColor: AxisColors.secondary,
                    ),
                  if (_parsed!.recurrence != null)
                    AxisChip(
                      label: '↻ daily',
                      dotColor: AxisColors.success,
                      backgroundColor: AxisColors.success.withOpacity(0.10),
                      textColor: AxisColors.successBright,
                    ),
                  ..._parsed!.tags.map((t) => AxisChip(
                    label: '@$t',
                    backgroundColor: AxisColors.primary.withOpacity(0.08),
                    textColor: AxisColors.primarySoft,
                  )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
