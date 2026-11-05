import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// Dialog allowing desktop users to search companions by friend code or username.
class DesktopAddCompanionDialog extends StatefulWidget {
  final String myFriendCode;

  const DesktopAddCompanionDialog({
    super.key,
    required this.myFriendCode,
  });

  static Future<void> show(BuildContext context, String myFriendCode) {
    return showDialog<void>(
      context: context,
      builder: (_) => DesktopAddCompanionDialog(myFriendCode: myFriendCode),
    );
  }

  @override
  State<DesktopAddCompanionDialog> createState() => _DesktopAddCompanionDialogState();
}

class _DesktopAddCompanionDialogState extends State<DesktopAddCompanionDialog> {
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
    if (clean.length < 3) return;

    setState(() {
      _isSearching = true;
      _lastQuery = clean;
    });

    _debounce = Timer(const Duration(milliseconds: 260), () async {
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AxisColors.canvasBase,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
          boxShadow: const [
            BoxShadow(color: Colors.black, blurRadius: 28, offset: Offset(0, 10)),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, size: 20, color: AxisColors.primarySoft),
                const SizedBox(width: 10),
                Text(
                  l10n.addCompanion,
                  style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AxisColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_rounded, size: 18, color: AxisColors.primarySoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.yourFriendCode.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 9, color: AxisColors.textDim)),
                        Text(widget.myFriendCode.isNotEmpty ? widget.myFriendCode : 'AX-7842', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: AxisColors.primarySoft)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.myFriendCode));
                      AxisSnackBar.show(context, message: l10n.copyCodeSuccess, icon: Icons.copy_rounded);
                    },
                    child: Text(l10n.copy, style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _searchCtrl,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh, fontSize: 14),
              decoration: InputDecoration(
                labelText: l10n.friendCode,
                hintText: l10n.searchCompanionHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AxisColors.primarySoft),
                suffixIcon: _isSearching
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft)))
                    : null,
                filled: true,
                fillColor: AxisColors.surfaceLowest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AxisColors.borderSubtle)),
              ),
              onChanged: _performSearch,
            ),
            const SizedBox(height: 14),

            if (_foundCandidate != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AxisColors.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    AvatarWidget(name: _foundCandidate!.name, avatarColor: _foundCandidate!.avatarColor, avatarUrl: _foundCandidate!.avatarUrl, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_foundCandidate!.name, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: AxisColors.textHigh)),
                          Text('Lv. ${_foundCandidate!.level} · ${_foundCandidate!.friendCode ?? ""}', style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else if (!_isSearching && _lastQuery.length >= 3) ...[
              Text(l10n.noCompanionFound, style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.warning), textAlign: TextAlign.center),
              const SizedBox(height: 14),
            ],

            ElevatedButton(
              onPressed: _isSubmitting || _foundCandidate == null || _foundCandidate!.status != 'none'
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      try {
                        final success = await _friendRepo.sendFriendRequestToCandidate(_foundCandidate!);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          AxisSnackBar.show(context, message: success ? 'Companion request sent!' : 'Could not send request.', icon: success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, isError: !success);
                        }
                      } finally {
                        if (mounted) setState(() => _isSubmitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AxisColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              child: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.sendConnectionRequest, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

