import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/sharing/companion_share_repository.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// Interactive modal sheet allowing users to share a Task, Habit, or Note
/// with an accepted companion.
class ShareTaskSheet extends StatefulWidget {
  final Task? task;
  final Habit? habit;
  final Note? note;
  final List<FriendUser>? initialFriends;
  final Set<String>? initialAlreadySharedCompanionIds;

  const ShareTaskSheet({
    super.key,
    this.task,
    this.habit,
    this.note,
    this.initialFriends,
    this.initialAlreadySharedCompanionIds,
  }) : assert(task != null || habit != null || note != null);

  static Future<void> show(BuildContext context, Task task) {
    if (task.isCompleted) {
      final isAr = AppLocalizations.of(context).isArabic;
      AxisSnackBar.show(
        context,
        message: isAr
            ? 'لا يمكن مشاركة المهام المكتملة أو التعاون عليها'
            : 'Completed tasks cannot be shared or collaborated on',
        icon: Icons.info_outline_rounded,
      );
      return Future.value();
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareTaskSheet(task: task),
    );
  }

  static Future<void> showForHabit(BuildContext context, Habit habit) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareTaskSheet(habit: habit),
    );
  }

  static Future<void> showForNote(BuildContext context, Note note) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareTaskSheet(note: note),
    );
  }

  @override
  State<ShareTaskSheet> createState() => _ShareTaskSheetState();
}

class _ShareTaskSheetState extends State<ShareTaskSheet> {
  final _friendRepo = FriendRepository();
  final _shareRepo = CompanionShareRepository();

  String? _selectedFriendId;
  String _shareMode = 'copy'; // 'copy' or 'collaborate'
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFriends == null) {
      unawaited(_friendRepo.syncAllFriendData());
    }
  }

  String get _entityType {
    if (widget.task != null) return 'task';
    if (widget.habit != null) return 'habit';
    return 'note';
  }

  String get _entityId =>
      widget.task?.id ?? widget.habit?.id ?? widget.note!.id;

  String get _itemTitle {
    if (widget.task != null) return widget.task!.title;
    if (widget.habit != null) return widget.habit!.name;
    return widget.note!.title;
  }

  String? get _itemSubtitle {
    if (widget.task != null) return widget.task!.notes;
    if (widget.note != null) return widget.note!.bodyMd;
    return null;
  }

  Color get _accentColor {
    if (widget.habit != null) return AxisColors.success;
    if (widget.note != null) return AxisColors.secondary;
    return AxisColors.primarySoft;
  }

  IconData get _headerIcon {
    if (widget.habit != null) return Icons.repeat_rounded;
    if (widget.note != null) return Icons.sticky_note_2_outlined;
    return Icons.share_rounded;
  }

  String _headerTitle(bool isArabic) {
    switch (_entityType) {
      case 'habit':
        return isArabic
            ? 'مشاركة العادة مع صاحب'
            : 'SHARE HABIT WITH COMPANION';
      case 'note':
        return isArabic
            ? 'مشاركة الملاحظة مع صاحب'
            : 'SHARE NOTE WITH COMPANION';
      default:
        return isArabic
            ? 'مشاركة المهمة مع صاحب'
            : 'SHARE TASK WITH COMPANION';
    }
  }

  String _headerSubtitle(bool isArabic) {
    switch (_entityType) {
      case 'habit':
        return isArabic
            ? 'أرسل نسخة من العادة إلى أصحابك'
            : 'Send a copy of this habit to your companion';
      case 'note':
        return isArabic
            ? 'أرسل نسخة من الملاحظة إلى أصحابك'
            : 'Send a copy of this note to your companion';
      default:
        return isArabic
            ? 'أرسل نسخة من المهمة أو تعاون عليها مع أصحابك'
            : 'Send a task copy or collaborate with your circle';
    }
  }

  String _badgeLabel(bool isArabic) {
    switch (_entityType) {
      case 'habit':
        return isArabic ? 'عادة' : 'HABIT';
      case 'note':
        return isArabic ? 'ملاحظة' : 'NOTE';
      default:
        return isArabic ? 'مهمة' : 'TASK';
    }
  }

  String _sendButtonLabel(bool isArabic) {
    switch (_entityType) {
      case 'habit':
        return isArabic ? 'إرسال العادة للصاحب' : 'Send Habit to Companion';
      case 'note':
        return isArabic ? 'إرسال الملاحظة للصاحب' : 'Send Note to Companion';
      default:
        return isArabic ? 'إرسال المهمة للصاحب' : 'Send Task to Companion';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF50D1524),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
                color: AxisColors.borderActive.withValues(alpha: 0.6),
                width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 32,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AxisColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _accentColor.withValues(alpha: 0.35)),
                          ),
                          child: Icon(_headerIcon,
                              color: _accentColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _headerTitle(isArabic),
                                style: AxisFonts.spaceGrotesk(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: isArabic ? 0.0 : 1.1,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _headerSubtitle(isArabic),
                                style: AxisFonts.getFont('Geist',
                                    fontSize: 11.5,
                                    color: AxisColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AxisColors.textDim),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: AxisColors.borderSubtle, height: 1),

                  // Preview Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _accentColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _badgeLabel(isArabic),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (widget.task?.priority != null)
                                PriorityChip(priority: widget.task!.priority!),
                              if (widget.task?.dueDate != null)
                                AxisChip(
                                  label: widget.task!.dueDate!,
                                  backgroundColor: AxisColors.surfaceLow,
                                  textColor: AxisColors.textMuted,
                                ),
                              if (widget.habit != null) ...[
                                AxisChip(
                                  label: widget.habit!.scheduleType,
                                  backgroundColor: AxisColors.surfaceLow,
                                  textColor: AxisColors.textMuted,
                                ),
                                if (widget.habit!.remindTime != null &&
                                    widget.habit!.remindTime!.isNotEmpty)
                                  AxisChip(
                                    label: widget.habit!.remindTime!,
                                    backgroundColor: AxisColors.surfaceLow,
                                    textColor: AxisColors.success,
                                  ),
                              ],
                              if (widget.note != null &&
                                  widget.note!.category.isNotEmpty)
                                AxisChip(
                                  label: widget.note!.category,
                                  backgroundColor: AxisColors.surfaceLow,
                                  textColor: AxisColors.secondary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AutoDirectionText(
                            _itemTitle,
                            style: AxisFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.textHigh,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_itemSubtitle != null &&
                              _itemSubtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            AutoDirectionText(
                              _itemSubtitle!.trim(),
                              style: AxisFonts.getFont('Geist',
                                  fontSize: 11.5, color: AxisColors.textDim),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Sharing Mode Selection (Tasks only: Copy vs Collaborative)
                  if (widget.task != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      child: _ShareModeSelector(
                        shareMode: _shareMode,
                        isArabic: isArabic,
                        onChanged: (m) => setState(() => _shareMode = m),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Companions Selection Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      isArabic
                          ? 'اختر الصاحب المستلم:'
                          : 'CHOOSE RECIPIENT COMPANION:',
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AxisColors.textDim,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Companions List
                  Flexible(
                    child: StreamBuilder<Set<String>>(
                      stream: widget.initialAlreadySharedCompanionIds != null
                          ? Stream.value(
                              widget.initialAlreadySharedCompanionIds!)
                          : _shareRepo.watchSharedCompanionIdsForItem(
                              entityType: _entityType,
                              entityId: _entityId,
                            ),
                      builder: (context, sharedSnapshot) {
                        final alreadySharedCompanionIds =
                            sharedSnapshot.data ?? const <String>{};
                        return StreamBuilder<List<FriendUser>>(
                          stream: widget.initialFriends != null
                              ? Stream.value(widget.initialFriends!)
                              : _friendRepo.watchAcceptedFriends(),
                          builder: (context, snapshot) {
                            final friends = snapshot.data ?? [];

                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                friends.isEmpty) {
                              return const SingleChildScrollView(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AxisColors.primarySoft),
                                ),
                              );
                            }

                            if (friends.isEmpty) {
                              return SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.group_off_rounded,
                                          size: 36,
                                          color: AxisColors.textDim
                                              .withValues(alpha: 0.5)),
                                      const SizedBox(height: 10),
                                      Text(
                                        isArabic
                                            ? 'لا يوجد أصحاب مضافون بعد'
                                            : 'No companions in your circle yet',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AxisColors.textMuted),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isArabic
                                            ? 'أضف أصحابك برمز الصداقة لتتمكن من المشاركة'
                                            : 'Add companions via friend code to start sharing',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AxisColors.textDim),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: friends.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final friend = friends[index];
                                final isAlreadyShared =
                                    alreadySharedCompanionIds
                                        .contains(friend.userId);
                                final isSelected = !isAlreadyShared &&
                                    _selectedFriendId == friend.userId;

                                return InkWell(
                                  onTap: isAlreadyShared
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _selectedFriendId =
                                              friend.userId);
                                        },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Opacity(
                                    opacity: isAlreadyShared ? 0.65 : 1.0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AxisColors.primary
                                                .withValues(alpha: 0.12)
                                            : AxisColors.surfaceLowest,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AxisColors.primarySoft
                                              : AxisColors.borderSubtle,
                                          width: isSelected ? 1.4 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          AvatarWidget(
                                            name: friend.name,
                                            avatarColor: friend.avatarColor,
                                            avatarUrl: friend.avatarUrl,
                                            size: 38,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  friend.name,
                                                  style:
                                                      AxisFonts.spaceGrotesk(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isSelected
                                                        ? AxisColors.primarySoft
                                                        : AxisColors.textHigh,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  'Lv.${friend.level} • ${friend.totalXp} XP',
                                                  style: AxisFonts.getFont(
                                                      'Geist',
                                                      fontSize: 11,
                                                      color:
                                                          AxisColors.textDim),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isAlreadyShared)
                                            Container(
                                              key: ValueKey(
                                                  'already_shared_companion_${friend.userId}'),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AxisColors.primary
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AxisColors.primary
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                isArabic
                                                    ? 'تمت المشاركة'
                                                    : 'ALREADY SHARED',
                                                style: AxisFonts.spaceGrotesk(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.4,
                                                  color: AxisColors.primarySoft,
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? AxisColors.primary
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? AxisColors.primary
                                                      : AxisColors.borderSubtle,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check_rounded,
                                                      size: 14,
                                                      color: Colors.black)
                                                  : null,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom Send Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: (_selectedFriendId == null || _isSending)
                            ? null
                            : _handleSendShare,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AxisColors.primary,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: AxisColors.surfaceLow,
                          disabledForegroundColor: AxisColors.textDim,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _sendButtonLabel(isArabic),
                                    style: AxisFonts.spaceGrotesk(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
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

  Future<void> _handleSendShare() async {
    if (_selectedFriendId == null) return;
    if (widget.task != null && widget.task!.isCompleted) return;
    HapticFeedback.lightImpact();
    setState(() => _isSending = true);

    try {
      if (widget.task != null) {
        await _shareRepo.shareTask(
          task: widget.task!,
          recipientId: _selectedFriendId!,
          shareMode: _shareMode,
        );
      } else if (widget.habit != null) {
        await _shareRepo.shareHabit(
          habit: widget.habit!,
          recipientId: _selectedFriendId!,
          shareMode: 'copy',
        );
      } else if (widget.note != null) {
        await _shareRepo.shareNote(
          note: widget.note!,
          recipientId: _selectedFriendId!,
          shareMode: 'copy',
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        final isArabic = AppLocalizations.of(context).isArabic;
        AxisSnackBar.show(
          context,
          message: isArabic
              ? 'تم إرسال $_itemTitle لصاحبك بنجاح!'
              : 'Shared "$_itemTitle" with companion!',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        final isArabic = AppLocalizations.of(context).isArabic;
        final rawMessage = e.toString().replaceFirst('Bad state: ', '').trim();
        AxisSnackBar.show(
          context,
          message: isArabic
              ? 'تعذر إرسال المشاركة: $rawMessage'
              : rawMessage.isNotEmpty
                  ? rawMessage
                  : 'Failed to share item: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }
}

/// Interactive two-step modal sheet launched from a Companion Profile:
/// Step 1: Choose what to share (Task, Habit, or Note) & share mode
/// Step 2: Search and pick the specific item to send to that companion
class ShareWithCompanionSheet extends StatefulWidget {
  final String companionUserId;
  final String companionName;
  final String? companionAvatarColor;
  final String? companionAvatarUrl;
  final List<Task>? initialTasks;
  final List<Habit>? initialHabits;
  final List<Note>? initialNotes;
  final Set<String>? initialAlreadySharedEntityIds;
  final Future<void> Function(String entityType, dynamic item, String shareMode)?
      onShareOverride;

  const ShareWithCompanionSheet({
    super.key,
    required this.companionUserId,
    required this.companionName,
    this.companionAvatarColor,
    this.companionAvatarUrl,
    this.initialTasks,
    this.initialHabits,
    this.initialNotes,
    this.initialAlreadySharedEntityIds,
    this.onShareOverride,
  });

  static Future<void> show(
    BuildContext context, {
    required String companionUserId,
    required String companionName,
    String? companionAvatarColor,
    String? companionAvatarUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareWithCompanionSheet(
        companionUserId: companionUserId,
        companionName: companionName,
        companionAvatarColor: companionAvatarColor,
        companionAvatarUrl: companionAvatarUrl,
      ),
    );
  }

  @override
  State<ShareWithCompanionSheet> createState() =>
      _ShareWithCompanionSheetState();
}

class _ShareWithCompanionSheetState extends State<ShareWithCompanionSheet> {
  final _shareRepo = CompanionShareRepository();
  final _searchController = TextEditingController();

  String? _selectedEntityType; // null => Step 1, 'task'|'habit'|'note' => Step 2
  String _shareMode = 'copy';
  String _searchQuery = '';
  Task? _selectedTask;
  Habit? _selectedHabit;
  Note? _selectedNote;
  bool _isSending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasSelectedItem =>
      _selectedTask != null || _selectedHabit != null || _selectedNote != null;

  void _selectType(String type) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedEntityType = type;
      _shareMode = 'copy';
      _selectedTask = null;
      _selectedHabit = null;
      _selectedNote = null;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF50D1524),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
                color: AxisColors.borderActive.withValues(alpha: 0.6),
                width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 32,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AxisColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with companion avatar & step navigation
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
                    child: Row(
                      children: [
                        if (_selectedEntityType != null) ...[
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                size: 20, color: AxisColors.textHigh),
                            tooltip: isArabic ? 'رجوع' : 'Back',
                            onPressed: () {
                              setState(() {
                                _selectedEntityType = null;
                                _selectedTask = null;
                                _selectedHabit = null;
                                _selectedNote = null;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                          ),
                          const SizedBox(width: 6),
                        ],
                        AvatarWidget(
                          name: widget.companionName,
                          avatarColor: widget.companionAvatarColor,
                          avatarUrl: widget.companionAvatarUrl,
                          size: 38,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic
                                    ? 'مشاركة مع ${widget.companionName}'
                                    : 'SHARE WITH ${widget.companionName.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AxisFonts.spaceGrotesk(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: isArabic ? 0.0 : 0.8,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedEntityType == null
                                    ? (isArabic
                                        ? 'ماذا تريد أن تشارك؟'
                                        : 'What would you like to share?')
                                    : _pickPrompt(isArabic),
                                style: AxisFonts.getFont('Geist',
                                    fontSize: 11.5,
                                    color: AxisColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AxisColors.textDim),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: AxisColors.borderSubtle, height: 1),

                  if (_selectedEntityType == null)
                    Flexible(
                      child: SingleChildScrollView(
                        child: _buildStepOneTypeChooser(isArabic),
                      ),
                    )
                  else
                    ..._buildStepTwoItemPicker(isArabic),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _pickPrompt(bool isArabic) {
    switch (_selectedEntityType) {
      case 'habit':
        return isArabic ? 'اختر العادة للمشاركة' : 'Choose which habit to share';
      case 'note':
        return isArabic ? 'اختر الملاحظة للمشاركة' : 'Choose which note to share';
      default:
        return isArabic ? 'اختر المهمة للمشاركة' : 'Choose which task to share';
    }
  }

  Widget _buildStepOneTypeChooser(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEntityTypeCard(
            type: 'task',
            icon: Icons.task_alt_rounded,
            color: AxisColors.primarySoft,
            title: isArabic ? 'مهمة' : 'Task',
            subtitle: isArabic
                ? 'شارك مهمة غير مكتملة أو تعاون عليها مع صاحبك'
                : 'Share or collaborate on an uncompleted task',
          ),
          const SizedBox(height: 10),
          _buildEntityTypeCard(
            type: 'habit',
            icon: Icons.repeat_rounded,
            color: AxisColors.success,
            title: isArabic ? 'عادة' : 'Habit',
            subtitle: isArabic
                ? 'أرسل نسخة من عادة يومية وتوقيت التذكير'
                : 'Send a copy of a daily habit',
          ),
          const SizedBox(height: 10),
          _buildEntityTypeCard(
            type: 'note',
            icon: Icons.sticky_note_2_outlined,
            color: AxisColors.secondary,
            title: isArabic ? 'ملاحظة' : 'Note',
            subtitle: isArabic
                ? 'أرسل نسخة من ملاحظة أو تدوينة من خزينتك'
                : 'Send a copy of a note or journal entry',
          ),
        ],
      ),
    );
  }

  Widget _buildEntityTypeCard({
    required String type,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      key: ValueKey('share_type_$type'),
      onTap: () => _selectType(type),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AxisColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AxisFonts.getFont('Geist',
                        fontSize: 11.5, color: AxisColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AxisColors.textDim),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStepTwoItemPicker(bool isArabic) {
    return [
      // Search input + Share Mode compact switcher (Tasks only)
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          children: [
            if (_selectedEntityType == 'task') ...[
              _ShareModeSelector(
                shareMode: _shareMode,
                isArabic: isArabic,
                onChanged: (m) => setState(() => _shareMode = m),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
              style: const TextStyle(color: AxisColors.textHigh, fontSize: 13),
              decoration: InputDecoration(
                hintText: isArabic ? 'ابحث بالعنوان...' : 'Search by title...',
                hintStyle:
                    const TextStyle(color: AxisColors.textDim, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceLowest,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  borderSide: const BorderSide(color: AxisColors.primarySoft),
                ),
              ),
            ),
          ],
        ),
      ),

      // Item List
      Flexible(
        child: _buildItemsListForSelectedType(isArabic),
      ),

      // Confirm Share Button
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: (!_hasSelectedItem || _isSending)
                ? null
                : _handleSendSelectedToCompanion,
            style: ElevatedButton.styleFrom(
              backgroundColor: AxisColors.primary,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AxisColors.surfaceLow,
              disabledForegroundColor: AxisColors.textDim,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isArabic
                              ? 'إرسال إلى ${widget.companionName}'
                              : 'Share with ${widget.companionName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AxisFonts.spaceGrotesk(
                              fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ];
  }

  Widget _buildItemsListForSelectedType(bool isArabic) {
    final alreadySharedStream = widget.initialAlreadySharedEntityIds != null
        ? Stream.value(widget.initialAlreadySharedEntityIds!)
        : _shareRepo.watchSharedEntityIdsForCompanion(
            companionUserId: widget.companionUserId,
            entityType: _selectedEntityType!,
          );

    return StreamBuilder<Set<String>>(
      stream: alreadySharedStream,
      builder: (context, sharedSnapshot) {
        final alreadySharedIds = sharedSnapshot.data ?? const <String>{};

        if (_selectedEntityType == 'task') {
          final stream = widget.initialTasks != null
              ? Stream.value(widget.initialTasks!)
              : TaskRepository().watchTasks();
          return StreamBuilder<List<Task>>(
            stream: stream,
            builder: (context, snapshot) {
              final allTasks = snapshot.data ?? [];
              final seenTitles = <String>{};
              final filtered = <Task>[];
              for (final t in allTasks) {
                if (t.isCompleted) continue;
                if (alreadySharedIds.contains(t.id)) continue;
                if (t.shareId != null &&
                    t.shareId!.isNotEmpty &&
                    alreadySharedIds.contains(t.shareId)) {
                  continue;
                }
                final matchesSearch = _searchQuery.isEmpty ||
                    t.title.toLowerCase().contains(_searchQuery) ||
                    (t.notes?.toLowerCase().contains(_searchQuery) ?? false);
                if (!matchesSearch) continue;
                final normTitle = t.title.trim().toLowerCase();
                if (normTitle.isNotEmpty && !seenTitles.add(normTitle)) continue;
                filtered.add(t);
              }

              if (filtered.isEmpty) {
                return _buildEmptyItemsState(
                  isArabic
                      ? 'لا توجد مهام غير مكتملة متاحة للمشاركة'
                      : 'No uncompleted tasks available to share',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = filtered[i];
                  final isSelected = _selectedTask?.id == t.id;
                  return _buildSelectableItemRow(
                    key: ValueKey('pick_task_${t.id}'),
                    title: t.title,
                    subtitle: [
                      if (t.dueDate != null && t.dueDate!.isNotEmpty)
                        t.dueDate!,
                      if (t.notes != null && t.notes!.trim().isNotEmpty)
                        t.notes!.trim(),
                    ].join(' • '),
                    icon: Icons.task_alt_rounded,
                    accentColor: AxisColors.primarySoft,
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTask = t);
                    },
                  );
                },
              );
            },
          );
        }

        if (_selectedEntityType == 'habit') {
          final stream = widget.initialHabits != null
              ? Stream.value(widget.initialHabits!)
              : HabitRepository().watchHabits();
          return StreamBuilder<List<Habit>>(
            stream: stream,
            builder: (context, snapshot) {
              final allHabits = snapshot.data ?? [];
              final seenNames = <String>{};
              final filtered = <Habit>[];
              for (final h in allHabits) {
                if (alreadySharedIds.contains(h.id)) continue;
                final matchesSearch = _searchQuery.isEmpty ||
                    h.name.toLowerCase().contains(_searchQuery) ||
                    h.category.toLowerCase().contains(_searchQuery);
                if (!matchesSearch) continue;
                final normName = h.name.trim().toLowerCase();
                if (normName.isNotEmpty && !seenNames.add(normName)) continue;
                filtered.add(h);
              }

              if (filtered.isEmpty) {
                return _buildEmptyItemsState(
                  isArabic
                      ? 'لا توجد عادات مطابقة'
                      : 'No habits available to share',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final h = filtered[i];
                  final isSelected = _selectedHabit?.id == h.id;
                  return _buildSelectableItemRow(
                    key: ValueKey('pick_habit_${h.id}'),
                    title: h.name,
                    subtitle: [
                      h.scheduleType,
                      if (h.category.isNotEmpty) h.category,
                      if (h.remindTime != null && h.remindTime!.isNotEmpty)
                        h.remindTime!,
                    ].join(' • '),
                    icon: Icons.repeat_rounded,
                    accentColor: AxisColors.success,
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedHabit = h);
                    },
                  );
                },
              );
            },
          );
        }

        // Notes
        final stream = widget.initialNotes != null
            ? Stream.value(widget.initialNotes!)
            : NoteRepository().watchNotes();
        return StreamBuilder<List<Note>>(
          stream: stream,
          builder: (context, snapshot) {
            final allNotes = snapshot.data ?? [];
            final seenTitles = <String>{};
            final filtered = <Note>[];
            for (final n in allNotes) {
              if (alreadySharedIds.contains(n.id)) continue;
              final matchesSearch = _searchQuery.isEmpty ||
                  n.title.toLowerCase().contains(_searchQuery) ||
                  n.bodyMd.toLowerCase().contains(_searchQuery);
              if (!matchesSearch) continue;
              final normKey = n.title.trim().isNotEmpty
                  ? n.title.trim().toLowerCase()
                  : n.bodyMd.trim().toLowerCase();
              if (normKey.isNotEmpty && !seenTitles.add(normKey)) continue;
              filtered.add(n);
            }

            if (filtered.isEmpty) {
              return _buildEmptyItemsState(
                isArabic
                    ? 'لا توجد ملاحظات مطابقة'
                    : 'No notes available to share',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = filtered[i];
                final isSelected = _selectedNote?.id == n.id;
                return _buildSelectableItemRow(
                  key: ValueKey('pick_note_${n.id}'),
                  title: n.title,
                  subtitle: [
                    n.category,
                    if (n.bodyMd.trim().isNotEmpty) n.bodyMd.trim(),
                  ].join(' • '),
                  icon: Icons.sticky_note_2_outlined,
                  accentColor: AxisColors.secondary,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedNote = n);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyItemsState(String message) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 13, color: AxisColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSelectableItemRow({
    Key? key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : AxisColors.borderSubtle,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoDirectionText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accentColor : AxisColors.textHigh,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    AutoDirectionText(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AxisFonts.getFont('Geist',
                          fontSize: 11, color: AxisColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : AxisColors.borderSubtle,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendSelectedToCompanion() async {
    if (!_hasSelectedItem) return;
    if (_selectedTask != null && _selectedTask!.isCompleted) return;
    HapticFeedback.lightImpact();
    setState(() => _isSending = true);

    final effectiveMode = _selectedEntityType == 'task' ? _shareMode : 'copy';

    try {
      String sentTitle = '';
      if (widget.onShareOverride != null) {
        final item = _selectedTask ?? _selectedHabit ?? _selectedNote;
        sentTitle = _selectedTask?.title ??
            _selectedHabit?.name ??
            _selectedNote?.title ??
            '';
        await widget.onShareOverride!(
          _selectedEntityType!,
          item,
          effectiveMode,
        );
      } else if (_selectedTask != null) {
        sentTitle = _selectedTask!.title;
        await _shareRepo.shareTask(
          task: _selectedTask!,
          recipientId: widget.companionUserId,
          shareMode: effectiveMode,
        );
      } else if (_selectedHabit != null) {
        sentTitle = _selectedHabit!.name;
        await _shareRepo.shareHabit(
          habit: _selectedHabit!,
          recipientId: widget.companionUserId,
          shareMode: 'copy',
        );
      } else if (_selectedNote != null) {
        sentTitle = _selectedNote!.title;
        await _shareRepo.shareNote(
          note: _selectedNote!,
          recipientId: widget.companionUserId,
          shareMode: 'copy',
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        final isArabic = AppLocalizations.of(context).isArabic;
        AxisSnackBar.show(
          context,
          message: isArabic
              ? 'تمت مشاركة "$sentTitle" مع ${widget.companionName} بنجاح!'
              : 'Shared "$sentTitle" with ${widget.companionName}!',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        final isArabic = AppLocalizations.of(context).isArabic;
        final rawMessage = e.toString().replaceFirst('Bad state: ', '').trim();
        AxisSnackBar.show(
          context,
          message: isArabic
              ? 'تعذر إرسال المشاركة: $rawMessage'
              : rawMessage.isNotEmpty
                  ? rawMessage
                  : 'Failed to share: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }
}

class _ShareModeSelector extends StatelessWidget {
  final String shareMode;
  final bool isArabic;
  final ValueChanged<String> onChanged;

  const _ShareModeSelector({
    required this.shareMode,
    required this.isArabic,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildModeOption(
            mode: 'copy',
            title: isArabic ? 'نسخة مستقلة' : 'Send as Copy',
            subtitle: isArabic
                ? 'يحصل الصاحب على نسخته الخاصة'
                : 'Clone into companion’s library',
            icon: Icons.copy_rounded,
            isSelected: shareMode == 'copy',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildModeOption(
            mode: 'collaborate',
            title: isArabic ? 'مشاركة تعاونية' : 'Collaborative',
            subtitle: isArabic
                ? 'تحديث ومزامنة مشتركة مباشرة'
                : 'Live synced updates together',
            icon: Icons.people_outline_rounded,
            isSelected: shareMode == 'collaborate',
          ),
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(mode);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.primary.withValues(alpha: 0.12)
              : AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? AxisColors.primarySoft : AxisColors.borderSubtle,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AxisColors.primarySoft : AxisColors.textDim,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AxisFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? AxisColors.primarySoft : AxisColors.textHigh,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AxisFonts.getFont('Geist',
                  fontSize: 10, color: AxisColors.textDim),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
