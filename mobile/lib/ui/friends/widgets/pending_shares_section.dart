import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/sharing/companion_share_repository.dart';
import 'package:axis/ui/common/axis_snackbar.dart';

/// Interactive section showing incoming shared tasks and items from companions,
/// with instant offline-first one-tap cloning and acceptance.
class PendingSharesSection extends StatelessWidget {
  const PendingSharesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final shareRepo = CompanionShareRepository();

    return StreamBuilder<List<CompanionShare>>(
      stream: shareRepo.watchPendingIncomingShares(),
      builder: (context, snapshot) {
        final shares = snapshot.data ?? [];
        if (shares.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AxisColors.primary.withValues(alpha: 0.14),
                const Color(0xFF38BDF8).withValues(alpha: 0.08),
                AxisColors.surfaceLowest,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AxisColors.primarySoft.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with count badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.move_to_inbox_rounded, size: 16, color: AxisColors.primarySoft),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'وارد الأصحاب (مهام مشتركة)' : 'SHARED WITH YOU',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: isArabic ? 0.0 : 1.1,
                      color: AxisColors.primarySoft,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AxisColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${shares.length}',
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

              // Pending Shares List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shares.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final share = shares[index];
                  return _PendingShareCard(share: share, isArabic: isArabic);
                },
              ),
            ],
          ),
        );
      },
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

  Future<void> _handleAccept() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      await CompanionShareRepository().acceptShare(widget.share);
      if (mounted) {
        AxisSnackBar.show(
          context,
          message: widget.isArabic
              ? 'تم قبول وإضافة "${widget.share.title}" إلى جدول مهامك بنجاح!'
              : 'Added "${widget.share.title}" to your tasks!',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AxisSnackBar.show(
          context,
          message: widget.isArabic ? 'تعذر قبول المهمة: $e' : 'Failed to accept: $e',
          icon: Icons.error_outline_rounded,
        );
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
          message: widget.isArabic ? 'تم رفض المهمة المشتركة' : 'Share request declined',
          icon: Icons.remove_circle_outline_rounded,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final share = widget.share;
    final isArabic = widget.isArabic;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender Header Row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _parseColor(share.senderAvatarColor).withValues(alpha: 0.2),
                  border: Border.all(color: _parseColor(share.senderAvatarColor)),
                ),
                child: Center(
                  child: Text(
                    share.senderName.isNotEmpty ? share.senderName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _parseColor(share.senderAvatarColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    children: [
                      TextSpan(
                        text: share.senderName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: isArabic
                            ? ' أرسل لك ${share.isCopy ? 'نسخة مهمة' : 'مهمة تعاونية'}'
                            : ' sent you a ${share.isCopy ? 'task copy' : 'collaborative task'}',
                        style: const TextStyle(color: AxisColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isArabic
                      ? (share.isCopy ? 'نسخة' : 'تعاون')
                      : (share.isCopy ? 'COPY' : 'LIVE'),
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF38BDF8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Title & Priority
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  share.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AxisColors.textHigh,
                  ),
                ),
              ),
              if (share.priority != null) ...[
                const SizedBox(width: 6),
                PriorityChip(priority: share.priority!),
              ],
            ],
          ),

          if (share.notes != null && share.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              share.notes!,
              style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'قبول المهمة' : 'Accept Task',
                                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(
                    isArabic ? 'رفض' : 'Decline',
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
