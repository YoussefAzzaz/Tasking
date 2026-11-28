import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/data/powersync_db.dart';

/// Interactive, dismissible notification banner displayed ONLY when online and the user's
/// authentication session has been confirmed expired/revoked by the server.
class SessionExpiredBanner extends StatefulWidget {
  const SessionExpiredBanner({super.key});

  @override
  State<SessionExpiredBanner> createState() => _SessionExpiredBannerState();
}

class _SessionExpiredBannerState extends State<SessionExpiredBanner> {
  bool _isReAuthenticating = false;
  bool _isLoggingOut = false;

  Future<void> _handleQuickReAuth() async {
    if (_isReAuthenticating || _isLoggingOut) return;
    setState(() => _isReAuthenticating = true);

    final isArabic = context.isArabic;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.maybeOf(context);

    try {
      final auth = AuthService();
      if (auth.hasSavedCredentials) {
        final success = await auth.trySilentReAuthWithSavedCredentials(
          timeout: const Duration(seconds: 6),
        );
        if (success) {
          await ensurePowerSyncConnected();
          if (mounted) {
            messenger?.showSnackBar(
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
      }

      // Direct user to /auth so they can sign in again (router permits /auth while expired)
      if (mounted) {
        router?.go('/auth');
      }
    } catch (_) {
      if (mounted) {
        router?.go('/auth');
      }
    } finally {
      if (mounted) {
        setState(() => _isReAuthenticating = false);
      }
    }
  }

  Future<void> _handleLogOut() async {
    if (_isLoggingOut || _isReAuthenticating) return;
    setState(() => _isLoggingOut = true);

    final router = GoRouter.maybeOf(context);
    try {
      await AuthService().signOut();
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoggingOut = false);
      router?.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService().isOnlineNotifier,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: AuthService().sessionExpiredNotifier,
          builder: (context, isExpired, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: AuthService().sessionExpiredDismissedNotifier,
              builder: (context, isDismissed, _) {
                if (!isExpired || !isOnline || isDismissed) {
                  return const SizedBox.shrink();
                }

                final auth = AuthService();
                final isArabic = context.isArabic;
                final hasSavedCreds = auth.hasSavedCredentials;
                final isBusy = _isReAuthenticating || _isLoggingOut;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic ? 'انتهت صلاحية الجلسة' : 'SESSION EXPIRED',
                              style: AxisFonts.spaceGrotesk(
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
                              style: AxisFonts.getFont(
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
                      const SizedBox(width: 8),
                      ElevatedButton(
                        key: const ValueKey('session_expired_relogin_button'),
                        onPressed: isBusy ? null : _handleQuickReAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AxisColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                style: AxisFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: isArabic ? 'تسجيل الخروج' : 'Log Out',
                        child: IconButton(
                          key: const ValueKey('session_expired_logout_button'),
                          onPressed: isBusy ? null : _handleLogOut,
                          icon: _isLoggingOut
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AxisColors.danger,
                                  ),
                                )
                              : const Icon(
                                  Icons.logout_rounded,
                                  size: 16,
                                  color: AxisColors.textHigh,
                                ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Tooltip(
                        message: isArabic ? 'إخفاء التنبيه' : 'Dismiss',
                        child: IconButton(
                          key: const ValueKey('session_expired_dismiss_button'),
                          onPressed: () => AuthService().dismissSessionExpiredBanner(),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AxisColors.textDim,
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
