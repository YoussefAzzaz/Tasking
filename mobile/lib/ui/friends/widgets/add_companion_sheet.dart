import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// Bottom sheet allowing users to search candidates by code/username and send requests.
class AddCompanionSheet extends StatefulWidget {
  final String myFriendCode;

  const AddCompanionSheet({
    super.key,
    required this.myFriendCode,
  });

  static Future<void> show(BuildContext context, String myFriendCode) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCompanionSheet(myFriendCode: myFriendCode),
    );
  }

  @override
  State<AddCompanionSheet> createState() => _AddCompanionSheetState();
}

class _AddCompanionSheetState extends State<AddCompanionSheet> {
  final _searchCtrl = TextEditingController();
  final _friendRepo = FriendRepository();
  FriendUser? _foundCandidate;
  bool _isSearching = false;
  bool _isSubmitting = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    _debounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _foundCandidate = null;
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastQuery = clean;
    });

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final candidate = await _friendRepo.searchCandidateCompanion(clean);
        if (mounted) {
          setState(() {
            _foundCandidate = candidate;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _foundCandidate = null;
            _isSearching = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        decoration: const BoxDecoration(
          color: AxisColors.canvasBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AxisColors.borderGlass2, width: 1.5),
            left: BorderSide(color: AxisColors.borderGlass2, width: 0.5),
            right: BorderSide(color: AxisColors.borderGlass2, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black, blurRadius: 36, spreadRadius: 8, offset: Offset(0, -6)),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AxisColors.textDim.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AxisColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: AxisColors.primarySoft),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.addCompanion, style: AxisFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AxisColors.textHigh)),
                        const SizedBox(height: 2),
                        Text(l10n.addCompanionDesc, style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AxisColors.surfaceLowest, AxisColors.surfaceLow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AxisColors.primary.withValues(alpha: 0.35), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AxisColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_rounded, size: 18, color: AxisColors.primarySoft),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.yourFriendCode.toUpperCase(), style: AxisFonts.spaceGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: AxisColors.textDim)),
                          const SizedBox(height: 2),
                          // Root cause: fell back to hardcoded fake 'AX-7842' when empty; show '---' and disable copy.
                          Text(
                            widget.myFriendCode.trim().isNotEmpty ? widget.myFriendCode.trim() : '---',
                            style: AxisFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AxisColors.primarySoft),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: (widget.myFriendCode.trim().isNotEmpty && widget.myFriendCode.trim() != '---')
                          ? () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(ClipboardData(text: widget.myFriendCode.trim()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.copyCodeSuccess),
                                  backgroundColor: AxisColors.surfaceLow,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.copy_rounded, size: 13),
                      label: Text(l10n.copy, style: AxisFonts.getFont('Geist', fontSize: 11.5, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AxisColors.primary.withValues(alpha: 0.22),
                        foregroundColor: AxisColors.primarySoft,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AxisColors.primary.withValues(alpha: 0.45)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              TextField(
                controller: _searchCtrl,
                textCapitalization: TextCapitalization.characters,
                style: AxisFonts.spaceGrotesk(color: AxisColors.textHigh, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: l10n.friendCode,
                  labelStyle: AxisFonts.getFont('Geist', color: AxisColors.textDim, fontSize: 13),
                  hintText: l10n.searchCompanionHint,
                  hintStyle: AxisFonts.getFont('Geist', color: AxisColors.textDim.withValues(alpha: 0.6), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AxisColors.primarySoft),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft),
                          ),
                        )
                      : _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: AxisColors.textDim),
                              onPressed: () {
                                _searchCtrl.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                  filled: true,
                  fillColor: AxisColors.surfaceLowest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AxisColors.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AxisColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AxisColors.primary, width: 1.8)),
                ),
                onChanged: _performSearch,
              ),
              const SizedBox(height: 16),

              if (_foundCandidate != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _foundCandidate!.status == 'accepted' ? AxisColors.success.withValues(alpha: 0.6) : AxisColors.primary.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (_foundCandidate!.status == 'accepted' ? AxisColors.success : AxisColors.primary).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _foundCandidate!.status == 'accepted' ? Icons.check_circle_rounded : Icons.verified_user_rounded,
                                  size: 13,
                                  color: _foundCandidate!.status == 'accepted' ? AxisColors.success : AxisColors.primarySoft,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _foundCandidate!.status == 'accepted'
                                      ? l10n.alreadyFriends
                                      : (_foundCandidate!.status == 'pending' ? l10n.requestAlreadyPending : l10n.candidateFound),
                                  style: AxisFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _foundCandidate!.status == 'accepted' ? AxisColors.success : AxisColors.primarySoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _foundCandidate!.friendCode ?? '',
                            style: AxisFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800, color: AxisColors.textDim),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          AvatarWidget(
                            name: _foundCandidate!.name,
                            avatarColor: _foundCandidate!.avatarColor,
                            avatarUrl: _foundCandidate!.avatarUrl,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_foundCandidate!.name, style: AxisFonts.spaceGrotesk(fontSize: 17, fontWeight: FontWeight.w800, color: AxisColors.textHigh)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(color: AxisColors.surfaceHigh, borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        '${l10n.isArabic ? "المستوى" : "Lv."} ${_foundCandidate!.level}',
                                        style: AxisFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.warning),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(_foundCandidate!.title, style: AxisFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textDim)),
                                    const SizedBox(width: 8),
                                    Text('• ${_foundCandidate!.totalXp} XP', style: AxisFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ] else if (!_isSearching && _lastQuery.length >= 3) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AxisColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: AxisColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l10n.noCompanionFound, style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: (_foundCandidate != null && _foundCandidate!.status == 'none')
                      ? const LinearGradient(colors: [AxisColors.primary, Color(0xFF818CF8)], begin: Alignment.centerLeft, end: Alignment.centerRight)
                      : null,
                  color: (_foundCandidate == null || _foundCandidate!.status != 'none') ? AxisColors.surfaceHigh.withValues(alpha: 0.4) : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting || _foundCandidate == null || _foundCandidate!.status != 'none'
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          try {
                            final success = await _friendRepo.sendFriendRequestToCandidate(_foundCandidate!);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? (l10n.isArabic
                                            ? 'تم إرسال طلب الرفقة بنجاح إلى ${_foundCandidate!.name}!'
                                            : 'Friend request sent successfully to ${_foundCandidate!.name}!')
                                        : (l10n.isArabic ? 'تعذر إرسال الطلب. حاول مرة أخرى.' : 'Could not send request. Please try again.'),
                                  ),
                                  backgroundColor: success ? AxisColors.success : AxisColors.warning,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: AxisColors.error, behavior: SnackBarBehavior.floating),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: AxisColors.textDim,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _foundCandidate != null ? l10n.sendRequestTo(_foundCandidate!.name) : l10n.sendConnectionRequest,
                              style: AxisFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

