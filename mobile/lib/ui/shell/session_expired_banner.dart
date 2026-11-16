import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/powersync_db.dart';

/// Interactive notification banner displayed when the user's authentication
/// session has expired or deprecated.
class SessionExpiredBanner extends StatefulWidget {
  const SessionExpiredBanner({super.key});

  @override
  State<SessionExpiredBanner> createState() => _SessionExpiredBannerState();
}

class _SessionExpiredBannerState extends State<SessionExpiredBanner> {
  bool _isReAuthenticating = false;

  Future<void> _handleQuickReAuth() async {
    if (_isReAuthenticating) return;
    setState(() => _isReAuthenticating = true);

    final isArabic = context.isArabic;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      final success = await AuthService().trySilentReAuthWithSavedCredentials();
      if (success) {
        await ensurePowerSyncConnected();
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? 'تمت إعادة المصادقة واستئناف المزامنة السحابية بنجاح!'
                    : 'Session restored! Cloud sync resumed successfully.',
              ),
              backgroundColor: AxisColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // If silent re-authentication was unsuccessful, direct user to auth screen
      if (mounted) {
        router.push('/auth');
      }
    } catch (_) {
      if (mounted) {
        router.push('/auth');
      }
    } finally {
      if (mounted) {
        setState(() => _isReAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService().sessionExpiredNotifier,
      builder: (context, isExpired, _) {
        if (!isExpired) {
          return const SizedBox.shrink();
        }

        final auth = AuthService();
        final isArabic = context.isArabic;
        final hasSavedCreds = auth.hasSavedCredentials;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AxisColors.danger.withValues(alpha: 0.16),
                AxisColors.warning.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AxisColors.danger.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AxisColors.danger.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AxisColors.danger.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_problem_rounded,
                  color: AxisColors.danger,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArabic ? 'انتهت صلاحية الجلسة' : 'SESSION EXPIRED',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? 'العمل محفوظ محلياً بأمان. سجّل الدخول لاستئناف المزامنة.'
                          : 'Work is saved locally. Log in to resume cloud sync.',
                      style: GoogleFonts.getFont(
                        'Geist',
                        fontSize: 11,
                        color: AxisColors.textDim,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isReAuthenticating ? null : _handleQuickReAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AxisColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isReAuthenticating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        hasSavedCreds
                            ? (isArabic ? 'إعادة الدخول' : 'RE-LOGIN')
                            : (isArabic ? 'تسجيل الدخول' : 'SIGN IN'),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
