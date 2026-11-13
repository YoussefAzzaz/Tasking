import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/sharing/companion_share_repository.dart';
import 'package:axis/ui/common/axis_snackbar.dart';

/// Interactive modal sheet allowing users to share a task with an accepted companion.
class ShareTaskSheet extends StatefulWidget {
  final Task task;

  const ShareTaskSheet({
    super.key,
    required this.task,
  });

  static Future<void> show(BuildContext context, Task task) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareTaskSheet(task: task),
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF50D1524),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AxisColors.borderActive.withValues(alpha: 0.6), width: 1.2),
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
              // Top Drag Handle
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
                        color: AxisColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AxisColors.primarySoft.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.share_rounded, color: AxisColors.primarySoft, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'مشاركة المهمة مع صاحب' : 'SHARE TASK WITH COMPANION',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: isArabic ? 0.0 : 1.1,
                              color: AxisColors.textHigh,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic
                                ? 'أرسل نسخة من المهمة أو تعاون عليها مع أصحابك'
                                : 'Send a task copy or collaborate with your circle',
                            style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              const Divider(color: AxisColors.borderSubtle, height: 1),

              // Task Preview Card
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isArabic ? 'مهمة' : 'TASK',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AxisColors.primarySoft,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.task.priority != null) ...[
                            PriorityChip(priority: widget.task.priority!),
                            const SizedBox(width: 6),
                          ],
                          if (widget.task.dueDate != null) ...[
                            AxisChip(
                              label: widget.task.dueDate!,
                              backgroundColor: AxisColors.surfaceLow,
                              textColor: AxisColors.textMuted,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.task.title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textHigh,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.task.notes != null && widget.task.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.task.notes!,
                          style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textDim),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Sharing Mode Selection (Copy vs Collaborative)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeOption(
                        mode: 'copy',
                        title: isArabic ? 'نسخة مستقلة' : 'Send as Copy',
                        subtitle: isArabic ? 'يحصل الصاحب على نسخته الخاصة' : 'Clone into companion’s tasks',
                        icon: Icons.copy_rounded,
                        isSelected: _shareMode == 'copy',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModeOption(
                        mode: 'collaborate',
                        title: isArabic ? 'مهمة تعاونية' : 'Collaborative',
                        subtitle: isArabic ? 'متابعة مشتركة للإنجاز' : 'Work on the task together',
                        icon: Icons.people_outline_rounded,
                        isSelected: _shareMode == 'collaborate',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Companions Selection Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  isArabic ? 'اختر الصاحب المستلم:' : 'CHOOSE RECIPIENT COMPANION:',
                  style: GoogleFonts.spaceGrotesk(
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
                child: StreamBuilder<List<FriendUser>>(
                  stream: _friendRepo.watchAcceptedFriends(),
                  builder: (context, snapshot) {
                    final friends = snapshot.data ?? [];

                    if (snapshot.connectionState == ConnectionState.waiting && friends.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft),
                        ),
                      );
                    }

                    if (friends.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_off_rounded, size: 36, color: AxisColors.textDim.withValues(alpha: 0.5)),
                              const SizedBox(height: 10),
                              Text(
                                isArabic ? 'لا يوجد أصحاب مضافون بعد' : 'No companions in your circle yet',
                                style: const TextStyle(fontSize: 13, color: AxisColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isArabic ? 'أضف أصحابك برمز الصداقة لتتمكن من مشاركة المهام' : 'Add companions via friend code to share tasks',
                                style: const TextStyle(fontSize: 11, color: AxisColors.textDim),
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
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected = _selectedFriendId == friend.userId;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFriendId = friend.userId);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AxisColors.primary.withValues(alpha: 0.12)
                                  : AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AxisColors.primarySoft
                                    : AxisColors.borderSubtle,
                                width: isSelected ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Avatar Circle
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _parseColor(friend.avatarColor).withValues(alpha: 0.2),
                                    border: Border.all(color: _parseColor(friend.avatarColor)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _parseColor(friend.avatarColor),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Friend Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend.name,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? AxisColors.primarySoft : AxisColors.textHigh,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Lv.${friend.level} • ${friend.totalXp} XP',
                                        style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                                      ),
                                    ],
                                  ),
                                ),

                                // Radio Selection
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? AxisColors.primary : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? AxisColors.primary : AxisColors.borderSubtle,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                                      : null,
                                ),
                              ],
                            ),
                          ),
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
                    onPressed: (_selectedFriendId == null || _isSending) ? null : _handleSendShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AxisColors.primary,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AxisColors.surfaceLow,
                      disabledForegroundColor: AxisColors.textDim,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                isArabic ? 'إرسال المهمة للصاحب' : 'Send Task to Companion',
                                style: GoogleFonts.spaceGrotesk(fontSize: 13.5, fontWeight: FontWeight.bold),
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
        setState(() => _shareMode = mode);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AxisColors.primary.withValues(alpha: 0.12) : AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AxisColors.primarySoft : AxisColors.borderSubtle,
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
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? AxisColors.primarySoft : AxisColors.textHigh,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendShare() async {
    if (_selectedFriendId == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isSending = true);

    try {
      await _shareRepo.shareTask(
        task: widget.task,
        recipientId: _selectedFriendId!,
        shareMode: _shareMode,
      );

      if (mounted) {
        Navigator.of(context).pop();
        final isArabic = AppLocalizations.of(context).isArabic;
        AxisSnackBar.show(
          context,
          message: isArabic ? 'تم إرسال المهمة لصاحبك بنجاح!' : 'Task sent to companion!',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        final isArabic = AppLocalizations.of(context).isArabic;
        AxisSnackBar.show(
          context,
          message: isArabic ? 'تعذر إرسال المهمة: $e' : 'Failed to share task: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFF6366F1);
    try {
      final hex = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}
