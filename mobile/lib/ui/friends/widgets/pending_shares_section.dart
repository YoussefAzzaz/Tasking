import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/sharing/companion_share_repository.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// Interactive section showing incoming shared tasks, habits, and notes from companions,
/// plus dismissible notices when a recipient declines a share request, with pre-accept preview.
class PendingSharesSection extends StatefulWidget {
  final List<CompanionShare>? initialPendingShares;
  final List<CompanionShare>? initialDeclinedShares;

  const PendingSharesSection({
    super.key,
    this.initialPendingShares,
    this.initialDeclinedShares,
  });

  @override
  State<PendingSharesSection> createState() => _PendingSharesSectionState();
}

class _PendingSharesSectionState extends State<PendingSharesSection> {
  final Set<String> _locallyDismissedDeclinedIds = <String>{};

  Future<void> _dismissDeclinedNotice(String shareId) async {
    HapticFeedback.selectionClick();
    setState(() {
      _locallyDismissedDeclinedIds.add(shareId);
    });
    await CompanionShareRepository().dismissDeclinedShareNotice(shareId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final shareRepo = CompanionShareRepository();

    final incomingStream = widget.initialPendingShares != null
        ? Stream<List<CompanionShare>>.value(widget.initialPendingShares!)
        : shareRepo.watchPendingIncomingShares();
    final declinedStream = widget.initialDeclinedShares != null
        ? Stream<List<CompanionShare>>.value(widget.initialDeclinedShares!)
        : shareRepo.watchDeclinedSentShares();

    return StreamBuilder<List<CompanionShare>>(
      stream: declinedStream,
      initialData: widget.initialDeclinedShares,
      builder: (context, declinedSnapshot) {
        final declinedShares = (declinedSnapshot.data ?? const <CompanionShare>[])
            .where((s) =>
                !s.isDeclinedDismissed &&
                !_locallyDismissedDeclinedIds.contains(s.id))
            .toList();

        return StreamBuilder<List<CompanionShare>>(
          stream: incomingStream,
          initialData: widget.initialPendingShares,
          builder: (context, pendingSnapshot) {
            final pendingShares =
                pendingSnapshot.data ?? const <CompanionShare>[];

            if (pendingShares.isEmpty && declinedShares.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (declinedShares.isNotEmpty)
                  _DeclinedSharesBanner(
                    declinedShares: declinedShares,
                    isArabic: isArabic,
                    onDismiss: _dismissDeclinedNotice,
                  ),
                if (pendingShares.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AxisColors.primary.withValues(alpha: 0.14),
                          AxisColors.secondary.withValues(alpha: 0.08),
                          AxisColors.surfaceLowest,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AxisColors.primarySoft.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AxisColors.primary.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.move_to_inbox_rounded,
                                size: 16,
                                color: AxisColors.primarySoft,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isArabic
                                    ? 'وارد الأصحاب (مشاركات واردة)'
                                    : 'SHARED WITH YOU',
                                style: AxisFonts.spaceGrotesk(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: isArabic ? 0.0 : 1.1,
                                  color: AxisColors.primarySoft,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AxisColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${pendingShares.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pendingShares.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final share = pendingShares[index];
                            return _PendingShareCard(
                              share: share,
                              isArabic: isArabic,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Reusable banner that surfaces undismissed collaborative task deletion notices
/// anywhere on Tasks or Companions screens (Mobile & Desktop).
class CollaborativeTaskDeletedNoticeBanner extends StatefulWidget {
  final List<CompanionShare>? initialNotices;
  final EdgeInsetsGeometry margin;

  const CollaborativeTaskDeletedNoticeBanner({
    super.key,
    this.initialNotices,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<CollaborativeTaskDeletedNoticeBanner> createState() =>
      _CollaborativeTaskDeletedNoticeBannerState();
}

class _CollaborativeTaskDeletedNoticeBannerState
    extends State<CollaborativeTaskDeletedNoticeBanner> {
  final Set<String> _locallyDismissedIds = <String>{};

  Future<void> _dismiss(String shareId) async {
    HapticFeedback.selectionClick();
    setState(() {
      _locallyDismissedIds.add(shareId);
    });
    await CompanionShareRepository().dismissDeclinedShareNotice(shareId);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final stream = widget.initialNotices != null
        ? Stream<List<CompanionShare>>.value(widget.initialNotices!)
        : CompanionShareRepository().watchCollaborativeTaskDeletedNotices();

    return StreamBuilder<List<CompanionShare>>(
      stream: stream,
      initialData: widget.initialNotices,
      builder: (context, snapshot) {
        final notices = (snapshot.data ?? const <CompanionShare>[])
            .where((s) =>
                s.isCollaborativeTaskDeleted &&
                !s.isDeclinedDismissed &&
                !_locallyDismissedIds.contains(s.id))
            .toList();

        if (notices.isEmpty) {
          return const SizedBox.shrink();
        }

        return _DeclinedSharesBanner(
          declinedShares: notices,
          isArabic: isArabic,
          margin: widget.margin,
          onDismiss: _dismiss,
        );
      },
    );
  }
}

class _DeclinedSharesBanner extends StatelessWidget {
  final List<CompanionShare> declinedShares;
  final bool isArabic;
  final EdgeInsetsGeometry margin;
  final ValueChanged<String> onDismiss;

  const _DeclinedSharesBanner({
    required this.declinedShares,
    required this.isArabic,
    this.margin = const EdgeInsets.only(bottom: 16),
    required this.onDismiss,
  });

  String _entityWord(CompanionShare share, bool arabic) {
    if (arabic) {
      if (share.isHabit) return 'العادة';
      if (share.isNote) return 'الملاحظة';
      if (share.isProject) return 'المشروع';
      return 'المهمة';
    }
    if (share.isHabit) return 'habit';
    if (share.isNote) return 'note';
    if (share.isProject) return 'project';
    return 'task';
  }

  String _resolveActorName(CompanionShare share, bool arabic) {
    if (share.isCollaborativeTaskDeleted) {
      final explicit = share.cancelledByName;
      if (explicit != null &&
          explicit.isNotEmpty &&
          explicit != 'Companion' &&
          explicit != 'A companion') {
        return explicit;
      }
      if (share.cancelledByUserId == share.senderId &&
          share.senderName != 'Companion' &&
          share.senderName.isNotEmpty) {
        return share.senderName;
      }
      if (share.recipientName != 'Companion' &&
          share.recipientName.isNotEmpty) {
        return share.recipientName;
      }
      if (share.senderName != 'Companion' && share.senderName.isNotEmpty) {
        return share.senderName;
      }
      return arabic ? 'صاحب' : 'Companion';
    }
    return share.recipientName != 'Companion'
        ? share.recipientName
        : (share.senderName != 'Companion'
            ? share.senderName
            : (arabic ? 'صاحب' : 'Companion'));
  }

  @override
  Widget build(BuildContext context) {
    final allCollabDeleted =
        declinedShares.every((s) => s.isCollaborativeTaskDeleted);
    final anyCollabDeleted =
        declinedShares.any((s) => s.isCollaborativeTaskDeleted);
    final headerTitle = allCollabDeleted
        ? (isArabic
            ? 'تنبيهات المهام التعاونية'
            : 'COLLABORATIVE TASK NOTICES')
        : (anyCollabDeleted
            ? (isArabic
                ? 'تنبيهات المشاركة والتعاون'
                : 'SHARE & COLLABORATION NOTICES')
            : (isArabic ? 'طلبات مشاركة مرفوضة' : 'DECLINED SHARE REQUESTS'));

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AxisColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AxisColors.error.withValues(alpha: 0.35),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AxisColors.error.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allCollabDeleted
                      ? Icons.delete_sweep_outlined
                      : Icons.cancel_outlined,
                  size: 16,
                  color: AxisColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerTitle,
                  style: AxisFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: isArabic ? 0.0 : 1.0,
                    color: AxisColors.error,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AxisColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${declinedShares.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: declinedShares.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final share = declinedShares[index];
              final actorName = _resolveActorName(share, isArabic);
              final kindWord = _entityWord(share, isArabic);
              final messageText = share.isCollaborativeTaskDeleted
                  ? (isArabic
                      ? 'حذف $actorName المهمة التعاونية "${share.title}" — نُقلت إلى مهامك العادية'
                      : '$actorName deleted collaborative task "${share.title}" — moved to your normal tasks')
                  : (isArabic
                      ? 'رفض $actorName $kindWord "${share.title}"'
                      : '$actorName declined your shared $kindWord "${share.title}"');
              final isActorSender = share.isCollaborativeTaskDeleted &&
                  share.cancelledByUserId == share.senderId;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AxisColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    AvatarWidget(
                      name: actorName,
                      avatarColor: isActorSender
                          ? share.senderAvatarColor
                          : share.recipientAvatarColor,
                      avatarUrl: isActorSender
                          ? share.senderAvatarUrl
                          : share.recipientAvatarUrl,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoDirectionText(
                            messageText,
                            style: AxisFonts.getFont(
                              'Geist',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AxisColors.textHigh,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('dismiss_declined_share_${share.id}'),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AxisColors.textMuted,
                      ),
                      tooltip: isArabic ? 'إخفاء' : 'Dismiss',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onDismiss(share.id),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PendingShareCard extends StatefulWidget {
  final CompanionShare share;
  final bool isArabic;

  const _PendingShareCard({
    required this.share,
    required this.isArabic,
  });

  @override
  State<_PendingShareCard> createState() => _PendingShareCardState();
}

class _PendingShareCardState extends State<_PendingShareCard> {
  bool _isProcessing = false;

  String _entityLabel(CompanionShare share, bool isArabic) {
    if (share.isHabit) return isArabic ? 'عادة' : 'HABIT';
    if (share.isNote) return isArabic ? 'ملاحظة' : 'NOTE';
    if (share.isProject) return isArabic ? 'مشروع' : 'PROJECT';
    return isArabic ? 'مهمة' : 'TASK';
  }

  IconData _entityIcon(CompanionShare share) {
    if (share.isHabit) return Icons.repeat_rounded;
    if (share.isNote) return Icons.sticky_note_2_outlined;
    if (share.isProject) return Icons.folder_outlined;
    return Icons.task_alt_rounded;
  }

  Color _entityColor(CompanionShare share) {
    if (share.isHabit) return AxisColors.success;
    if (share.isNote) return AxisColors.secondary;
    return AxisColors.primarySoft;
  }

  String _senderActionText(CompanionShare share, bool isArabic) {
    if (isArabic) {
      if (share.isHabit) {
        return ' أرسل لك ${share.isCopy ? 'نسخة عادة' : 'عادة تعاونية'}';
      }
      if (share.isNote) {
        return ' أرسل لك ${share.isCopy ? 'نسخة ملاحظة' : 'ملاحظة تعاونية'}';
      }
      if (share.isProject) {
        return ' أرسل لك مشروعاً';
      }
      return ' أرسل لك ${share.isCopy ? 'نسخة مهمة' : 'مهمة تعاونية'}';
    }
    final kind = share.isHabit
        ? 'habit'
        : (share.isNote ? 'note' : (share.isProject ? 'project' : 'task'));
    return share.isCopy
        ? ' shared a $kind copy with you'
        : ' invited you to collaborate on a $kind';
  }

  String _acceptButtonText(CompanionShare share, bool isArabic) {
    if (isArabic) {
      if (share.isHabit) return 'قبول العادة';
      if (share.isNote) return 'قبول الملاحظة';
      if (share.isProject) return 'قبول المشروع';
      return 'قبول المهمة';
    }
    if (share.isHabit) return 'Accept Habit';
    if (share.isNote) return 'Accept Note';
    if (share.isProject) return 'Accept Project';
    return 'Accept Task';
  }

  String _acceptedSuccessMessage(CompanionShare share, bool isArabic) {
    if (isArabic) {
      if (share.isHabit) {
        return 'تمت إضافة العادة "${share.title}" إلى عاداتك!';
      }
      if (share.isNote) {
        return 'تمت إضافة الملاحظة "${share.title}" إلى ملاحظاتك!';
      }
      return 'تم قبول وإضافة "${share.title}" إلى مهامك بنجاح!';
    }
    if (share.isHabit) return 'Added "${share.title}" to your habits!';
    if (share.isNote) return 'Added "${share.title}" to your notes!';
    return 'Added "${share.title}" to your tasks!';
  }

  Future<void> _handleAccept() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      await CompanionShareRepository().acceptShare(widget.share);
      if (mounted) {
        AxisSnackBar.show(
          context,
          message: _acceptedSuccessMessage(widget.share, widget.isArabic),
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        AxisSnackBar.show(
          context,
          message:
              widget.isArabic ? 'تعذر قبول المشاركة: $e' : 'Failed to accept: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleDecline() async {
    HapticFeedback.lightImpact();
    setState(() => _isProcessing = true);

    try {
      await CompanionShareRepository().declineShare(widget.share.id);
      if (mounted) {
        AxisSnackBar.show(
          context,
          message:
              widget.isArabic ? 'تم رفض المشاركة' : 'Share request declined',
          icon: Icons.remove_circle_outline_rounded,
        );
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openPreview() {
    HapticFeedback.selectionClick();
    return SharedItemPreviewDialog.show(
      context,
      share: widget.share,
      isArabic: widget.isArabic,
      onAccept: _handleAccept,
      onDecline: _handleDecline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final share = widget.share;
    final isArabic = widget.isArabic;
    final entityColor = _entityColor(share);

    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _isProcessing ? null : _openPreview,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender Header Row
                Row(
                  children: [
                    AvatarWidget(
                      name: share.senderName,
                      avatarColor: share.senderAvatarColor,
                      avatarUrl: share.senderAvatarUrl,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AxisFonts.getFont('Geist',
                              fontSize: 12, color: AxisColors.textHigh),
                          children: [
                            TextSpan(
                              text: share.senderName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: _senderActionText(share, isArabic),
                              style:
                                  const TextStyle(color: AxisColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: entityColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_entityIcon(share),
                              size: 10, color: entityColor),
                          const SizedBox(width: 3),
                          Text(
                            _entityLabel(share, isArabic),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: entityColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AxisColors.secondary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isArabic
                            ? (share.isCopy ? 'نسخة' : 'تعاون')
                            : (share.isCopy ? 'COPY' : 'LIVE'),
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: AxisColors.secondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Title & Entity Metadata Pills
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AutoDirectionText(
                        share.title,
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textHigh,
                        ),
                      ),
                    ),
                    if (share.isTask && share.priority != null) ...[
                      const SizedBox(width: 6),
                      PriorityChip(priority: share.priority!),
                    ],
                  ],
                ),

                if (share.isHabit &&
                    ((share.scheduleType != null &&
                            share.scheduleType!.isNotEmpty) ||
                        (share.remindTime != null &&
                            share.remindTime!.isNotEmpty))) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (share.scheduleType != null &&
                          share.scheduleType!.isNotEmpty)
                        AxisChip(
                          label: share.scheduleType!,
                          backgroundColor: AxisColors.surfaceLow,
                          textColor: AxisColors.textMuted,
                        ),
                      if (share.remindTime != null &&
                          share.remindTime!.isNotEmpty)
                        AxisChip(
                          label: share.remindTime!,
                          backgroundColor: AxisColors.surfaceLow,
                          textColor: AxisColors.success,
                        ),
                    ],
                  ),
                ],

                if (share.isNote &&
                    share.noteCategory != null &&
                    share.noteCategory!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  AxisChip(
                    label: share.noteCategory!,
                    backgroundColor: AxisColors.surfaceLow,
                    textColor: AxisColors.secondary,
                  ),
                ],

                if (share.notes != null && share.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  AutoDirectionText(
                    share.notes!.trim(),
                    style: AxisFonts.getFont('Geist',
                        fontSize: 11, color: AxisColors.textDim),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),

                // Explicit Preview trigger
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: ValueKey('preview_share_${share.id}'),
                    onPressed: _isProcessing ? null : _openPreview,
                    style: TextButton.styleFrom(
                      foregroundColor: AxisColors.primarySoft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor:
                          AxisColors.primarySoft.withValues(alpha: 0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: Text(
                      isArabic ? 'معاينة التفاصيل' : 'Preview',
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Accept & Decline Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _handleAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AxisColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_rounded, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      _acceptButtonText(share, isArabic),
                                      style: AxisFonts.spaceGrotesk(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _handleDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AxisColors.textDim,
                          side: const BorderSide(color: AxisColors.borderSubtle),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(
                          isArabic ? 'رفض' : 'Decline',
                          style: AxisFonts.spaceGrotesk(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal preview dialog allowing recipients to inspect the full title, description,
/// and metadata of a shared task, habit, or note before accepting or declining.
class SharedItemPreviewDialog extends StatelessWidget {
  final CompanionShare share;
  final bool isArabic;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onDecline;

  const SharedItemPreviewDialog({
    super.key,
    required this.share,
    required this.isArabic,
    this.onAccept,
    this.onDecline,
  });

  static Future<void> show(
    BuildContext context, {
    required CompanionShare share,
    required bool isArabic,
    Future<void> Function()? onAccept,
    Future<void> Function()? onDecline,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => SharedItemPreviewDialog(
        share: share,
        isArabic: isArabic,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  String _entityLabel() {
    if (share.isHabit) return isArabic ? 'عادة' : 'HABIT';
    if (share.isNote) return isArabic ? 'ملاحظة' : 'NOTE';
    if (share.isProject) return isArabic ? 'مشروع' : 'PROJECT';
    return isArabic ? 'مهمة' : 'TASK';
  }

  Color _entityColor() {
    if (share.isHabit) return AxisColors.success;
    if (share.isNote) return AxisColors.secondary;
    return AxisColors.primarySoft;
  }

  List<Widget> _buildMetadataChips() {
    final chips = <Widget>[];
    if (share.isTask) {
      if (share.priority != null) {
        chips.add(PriorityChip(priority: share.priority!));
      }
      if (share.dueDate != null && share.dueDate!.trim().isNotEmpty) {
        chips.add(AxisChip(
          label: share.dueDate!.trim(),
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.textMuted,
        ));
      }
      if (share.dueTime != null && share.dueTime!.trim().isNotEmpty) {
        chips.add(AxisChip(
          label: share.dueTime!.trim(),
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.primarySoft,
        ));
      }
      if (share.estimateMin != null && share.estimateMin! > 0) {
        chips.add(AxisChip(
          label: isArabic
              ? '${share.estimateMin} د'
              : '${share.estimateMin}m',
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.textMuted,
        ));
      }
      if (share.recurrenceRule != null &&
          share.recurrenceRule!.trim().isNotEmpty) {
        chips.add(AxisChip(
          label: share.recurrenceRule!.trim(),
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.secondary,
        ));
      }
      final cleanSenderLower = share.senderName
          .trim()
          .replaceFirst(RegExp(r'^@+'), '')
          .toLowerCase();
      for (final t in share.tags) {
        final clean = t.trim().replaceFirst(RegExp(r'^@+'), '');
        if (clean.isEmpty || clean.toLowerCase() == cleanSenderLower) continue;
        chips.add(AxisChip(
          label: '#$clean',
          backgroundColor: AxisColors.primary.withValues(alpha: 0.10),
          textColor: AxisColors.primarySoft,
        ));
      }
    } else if (share.isHabit) {
      if (share.scheduleType != null &&
          share.scheduleType!.trim().isNotEmpty) {
        chips.add(AxisChip(
          label: share.scheduleType!.trim(),
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.textMuted,
        ));
      }
      if (share.remindTime != null && share.remindTime!.trim().isNotEmpty) {
        chips.add(AxisChip(
          label: share.remindTime!.trim(),
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.success,
        ));
      }
      if (share.targetValue != null && share.targetValue! > 0) {
        chips.add(AxisChip(
          label: '+${share.targetValue} XP',
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.warning,
        ));
      }
      final kind = share.habitKind?.trim() ?? '';
      if (kind.isNotEmpty && kind.toLowerCase() != 'boolean') {
        chips.add(AxisChip(
          label: kind,
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.primarySoft,
        ));
      }
    } else if (share.isNote) {
      if (share.noteCategory != null &&
          share.noteCategory!.trim().isNotEmpty) {
        chips.add(AxisChip(
          label: share.noteCategory!.trim(),
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.secondary,
        ));
      }
      if (share.mood != null && share.mood!.trim().isNotEmpty) {
        chips.add(AxisChip(
          label: share.mood!.trim(),
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.warning,
        ));
      }
      if (share.energy != null && share.energy!.trim().isNotEmpty) {
        chips.add(AxisChip(
          label: share.energy!.trim(),
          backgroundColor: AxisColors.surfaceLow,
          textColor: AxisColors.success,
        ));
      }
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final entityColor = _entityColor();
    final rawDesc = share.isNote
        ? (share.noteBody ?? share.notes ?? '').trim()
        : (share.notes ??
                share.previewData['description']?.toString() ??
                '')
            .trim();
    final displayDesc = rawDesc.isNotEmpty
        ? rawDesc
        : (isArabic ? 'لا يوجد وصف مرفق.' : 'No description provided.');
    final chips = _buildMetadataChips();

    return Dialog(
      backgroundColor: AxisColors.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AxisColors.borderPrimary, width: 1.1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender & Type Header
              Row(
                children: [
                  AvatarWidget(
                    name: share.senderName,
                    avatarColor: share.senderAvatarColor,
                    avatarUrl: share.senderAvatarUrl,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          share.senderName,
                          style: AxisFonts.getFont(
                            'Geist',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AxisColors.textHigh,
                          ),
                        ),
                        Text(
                          isArabic
                              ? (share.isCopy
                                  ? 'مشاركة نسخة'
                                  : 'دعوة تعاون')
                              : (share.isCopy
                                  ? 'Shared copy'
                                  : 'Collaborative invite'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AxisColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: entityColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _entityLabel(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: entityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AxisColors.textMuted,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Title
              AutoDirectionText(
                share.title,
                style: AxisFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
              ),

              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chips,
                ),
              ],

              const SizedBox(height: 14),

              // Description / Content section
              Text(
                isArabic
                    ? (share.isNote ? 'المحتوى' : 'الوصف')
                    : (share.isNote ? 'Content' : 'Description'),
                style: AxisFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: isArabic ? 0.0 : 0.8,
                  color: AxisColors.textDim,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: SingleChildScrollView(
                  child: AutoDirectionText(
                    displayDesc,
                    key: const ValueKey('shared_item_preview_description'),
                    style: AxisFonts.getFont(
                      'Geist',
                      fontSize: 13,
                      height: 1.45,
                      color: rawDesc.isNotEmpty
                          ? AxisColors.textHigh
                          : AxisColors.textDim,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Decline & Accept actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey('preview_dialog_decline_${share.id}'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onDecline?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AxisColors.error,
                        side: BorderSide(
                          color: AxisColors.error.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'رفض' : 'Decline',
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      key: ValueKey('preview_dialog_accept_${share.id}'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onAccept?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AxisColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: Text(
                        isArabic ? 'قبول' : 'Accept',
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
