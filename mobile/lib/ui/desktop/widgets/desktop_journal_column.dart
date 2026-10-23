import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/markdown_list_text_input_formatter.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';
import 'package:axis/ui/desktop/services/desktop_file_service.dart';

/// Desktop Column 3: Daily Markdown Journal & Next Milestones in Reach.
class DesktopJournalColumn extends StatefulWidget {
  const DesktopJournalColumn({super.key});

  @override
  State<DesktopJournalColumn> createState() => _DesktopJournalColumnState();
}

class _DesktopJournalColumnState extends State<DesktopJournalColumn> {
  final _noteRepo = NoteRepository();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  late final FocusNode _bodyFocusNode;

  Note? _todayJournalNote;
  bool _isPreviewMode = false;
  bool _isSaving = false;
  String _contentHash = '';

  @override
  void initState() {
    super.initState();
    _bodyFocusNode = FocusNode();
    _loadTodayJournal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  void _loadTodayJournal() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _titleController.text = 'Daily Log // $todayStr';

    _noteRepo.watchNotes(category: 'journal').listen((notes) {
      if (!mounted) return;
      final todayNotes = notes.where((n) {
        final dStr = DateFormat('yyyy-MM-dd').format(n.createdAt);
        return dStr == todayStr;
      }).toList();

      if (todayNotes.isNotEmpty) {
        _todayJournalNote = todayNotes.first;
        if (_bodyController.text.isEmpty) {
          _bodyController.text = _todayJournalNote!.bodyMd;
          _updateHash(_bodyController.text);
        }
      } else {
        if (_bodyController.text.isEmpty) {
          _bodyController.text =
              '# Focus & State of Mind\n\nDeep session initiated on desktop workstation.\n\n- [x] Cleared mental backlog & organized projects\n- [ ] Complete scheduled sprints';
          _updateHash(_bodyController.text);
        }
      }
      setState(() {});
    });
  }

  void _updateHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    _contentHash = digest.toString().substring(0, 8);
  }

  Future<void> _saveJournalEntry() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      _updateHash(_bodyController.text);

      if (_todayJournalNote != null) {
        final updated = Note(
          id: _todayJournalNote!.id,
          title: _titleController.text.trim().isEmpty ? 'Daily Log' : _titleController.text.trim(),
          bodyMd: _bodyController.text,
          category: 'journal',
          createdAt: _todayJournalNote!.createdAt,
        );
        await _noteRepo.updateNote(updated);
        _todayJournalNote = updated;
      } else {
        final newNote = Note(
          id: IdGenerator.getJournalEntryId(DateFormat('yyyy-MM-dd').format(now)),
          title: _titleController.text.trim().isEmpty ? 'Daily Log' : _titleController.text.trim(),
          bodyMd: _bodyController.text,
          category: 'journal',
          createdAt: now,
        );
        await _noteRepo.addNote(newNote);
        _todayJournalNote = newNote;
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _attachFile() async {
    final file = await DesktopFileService().pickLocalFileAttachment();
    if (file != null && file.path != null) {
      final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(file.extension?.toLowerCase());
      final markdownLink = isImage
          ? '\n![${file.name}](${file.path})\n'
          : '\n[📎 ${file.name}](${file.path})\n';

      final pos = _bodyController.selection.start;
      final text = _bodyController.text;
      if (pos >= 0) {
        _bodyController.text = text.replaceRange(pos, pos, markdownLink);
      } else {
        _bodyController.text = text + markdownLink;
      }
      await _saveJournalEntry();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attached ${file.name} to Daily Log'),
            backgroundColor: AxisColors.surfaceLow,
          ),
        );
      }
    }
  }

  Future<void> _exportMarkdown() async {
    final path = await DesktopFileService().exportMarkdownFile(
      title: _titleController.text,
      markdownContent: _bodyController.text,
    );
    if (mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $path'),
          backgroundColor: AxisColors.surfaceLow,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _bodyController.text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final readTimeMin = (wordCount / 180).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Daily Journal Section
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF070B16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Journal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_stories_rounded, size: 14, color: AxisColors.secondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _titleController.text.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AxisColors.textHigh,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$wordCount words • $readTimeMin min read',
                            style: const TextStyle(
                              color: AxisColors.textDim,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Attach Local File Button
                        Tooltip(
                          message: 'Attach Local File via Windows Explorer',
                          child: InkWell(
                            onTap: _attachFile,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AxisColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AxisColors.borderSubtle),
                              ),
                              child: const Icon(Icons.attach_file_rounded, size: 13, color: AxisColors.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Export .MD Button
                        Tooltip(
                          message: 'Export to .md File on Disk',
                          child: InkWell(
                            onTap: _exportMarkdown,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: AxisColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AxisColors.borderSubtle),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.download_rounded, size: 12, color: AxisColors.textMuted),
                                  SizedBox(width: 2),
                                  Text(
                                    '.MD',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AxisColors.textHigh,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Live Preview Toggle
                        InkWell(
                          onTap: () => setState(() => _isPreviewMode = !_isPreviewMode),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isPreviewMode ? AxisColors.primary.withValues(alpha: 0.2) : AxisColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Text(
                              _isPreviewMode ? 'Edit' : 'Preview',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Formatting Toolbar (when editing)
                if (!_isPreviewMode) ...[
                  NoteFormatToolbar(controller: _bodyController, focusNode: _bodyFocusNode),
                  const SizedBox(height: 6),
                ],

                // Body Editor or Live Markdown Viewer
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: _isPreviewMode
                        ? SingleChildScrollView(
                            child: AxisMarkdownViewer(
                              markdown: _bodyController.text,
                              onMarkdownChanged: (updatedBody) async {
                                setState(() => _bodyController.text = updatedBody);
                                if (_todayJournalNote != null) {
                                  final updated = _todayJournalNote!.copyWith(bodyMd: updatedBody);
                                  await NoteRepository().updateNote(updated);
                                }
                              },
                            ),
                          )
                        : TextField(
                            controller: _bodyController,
                            focusNode: _bodyFocusNode,
                            maxLines: null,
                            expands: true,
                            inputFormatters: const [
                              MarkdownListTextInputFormatter(),
                            ],
                            onChanged: (_) => _saveJournalEntry(),
                            style: const TextStyle(
                              color: AxisColors.textHigh,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Log your daily thoughts, reflections, and progress...',
                              hintStyle: TextStyle(color: AxisColors.textDim, fontSize: 11),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 6),

                // Telemetry footer with Auto-save Hash
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Auto-saved to Local Vault DB',
                          style: TextStyle(fontSize: 9, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                    if (_contentHash.isNotEmpty)
                      Text(
                        'Hash: $_contentHash',
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          color: AxisColors.tertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const Divider(color: AxisColors.borderSubtle, height: 1),

        // 2. Next Milestones in Reach Section
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF090E1A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.military_tech_rounded, size: 15, color: AxisColors.warning),
                        SizedBox(width: 6),
                        Text(
                          'Milestones in Reach',
                          style: TextStyle(
                            color: AxisColors.textHigh,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AxisColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '+750 XP AVAIL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Milestone 1
                _MilestoneItem(
                  icon: Icons.shield_rounded,
                  title: 'Focus Titan Tier III',
                  reward: '+250 XP & Cyber Ring',
                  progress: 0.88,
                  progressLabel: '880 / 1,000 XP',
                  color: AxisColors.primarySoft,
                ),

                const SizedBox(height: 8),

                // Milestone 2
                _MilestoneItem(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Streak Sovereign',
                  reward: '+500 XP & Vault Key',
                  progress: 0.90,
                  progressLabel: '45 / 50 Days Unbroken',
                  color: AxisColors.warning,
                ),

                const SizedBox(height: 8),

                // Unlocked Badge Spotlight
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AxisColors.tertiary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.verified_rounded, size: 14, color: AxisColors.tertiary),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Obsidian Architect',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.textHigh,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'UNLOCKED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.tertiary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '100 consecutive days of encrypted logs',
                              style: TextStyle(fontSize: 8, color: AxisColors.textDim),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  const _MilestoneItem({
    required this.icon,
    required this.title,
    required this.reward,
    required this.progress,
    required this.progressLabel,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String reward;
  final double progress;
  final String progressLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.textHigh,
                    ),
                  ),
                ],
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Reward: $reward',
            style: const TextStyle(fontSize: 8, color: AxisColors.textDim),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AxisColors.surfaceHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              progressLabel,
              style: const TextStyle(
                fontSize: 8,
                fontFamily: 'monospace',
                color: AxisColors.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
