import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/ui/common/sync_status_modal.dart';

/// Shows an advisory banner when the user is operating in guest/offline mode.
class MeGuestBanner extends StatelessWidget {
  final VoidCallback onExitGuest;

  const MeGuestBanner({
    super.key,
    required this.onExitGuest,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic ? 'وضع الضيف المحلي نشط' : 'LOCAL GUEST MODE ACTIVE',
                    style: TextStyle(
                      color: const Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: isArabic ? 0.0 : 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'مهامك وعاداتك وملاحظاتك مخزنة حالياً على هذا الجهاز فقط. سجّل الدخول بحسابك لمزامنتها فورياً مع التخزين السحابي.'
                  : 'Your tasks, habits, and notes are currently stored only on this device. Sign in with your Supabase account to instantly synchronize with Desktop and cloud storage.',
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                      label: Text(
                        isArabic ? 'تسجيل الدخول للمزامنة' : 'SIGN IN TO SYNC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: isArabic ? 0.0 : 0.5,
                        ),
                      ),
                      onPressed: () => context.go('/auth'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onExitGuest,
                    child: Text(
                      isArabic ? 'خروج من وضع الضيف' : 'EXIT GUEST',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isArabic ? 0.0 : 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays the connected cloud account and real-time synchronization diagnostics trigger.
class MeCloudAccountCard extends StatelessWidget {
  final AuthService auth;

  const MeCloudAccountCard({
    super.key,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final email = auth.currentUser?.email ?? (isArabic ? 'حساب متزامن سحابياً' : 'Cloud Synced Account');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AxisColors.tertiary.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AxisColors.tertiary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_done_rounded,
                color: AxisColors.tertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'الحساب السحابي المتصل' : 'CONNECTED CLOUD ACCOUNT',
                    style: TextStyle(
                      color: AxisColors.tertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: isArabic ? 0.0 : 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      color: AxisColors.textHigh,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => SyncStatusModal.show(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isArabic ? 'التشخيص' : 'Diagnostics',
                        style: const TextStyle(
                          color: AxisColors.primarySoft,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isArabic ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
                        size: 9,
                        color: AxisColors.primarySoft,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sign Out / Connect Cloud action button positioned at the bottom of the Me screen.
class MeSessionActionButton extends StatelessWidget {
  final bool isGuest;
  final VoidCallback onTap;

  const MeSessionActionButton({
    super.key,
    required this.isGuest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          splashColor: (isGuest ? AxisColors.primary : AxisColors.error).withValues(alpha: 0.2),
          highlightColor: (isGuest ? AxisColors.primary : AxisColors.error).withValues(alpha: 0.1),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: (isGuest ? AxisColors.primary : AxisColors.error).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isGuest ? AxisColors.primary : AxisColors.error).withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isGuest ? AxisColors.primary : AxisColors.error).withValues(alpha: 0.06),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isGuest ? Icons.login_rounded : Icons.logout_rounded,
                  color: isGuest ? AxisColors.primary : AxisColors.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isGuest
                      ? (isArabic ? 'تسجيل الدخول / ربط الحساب السحابي' : 'Sign In / Connect Cloud Account')
                      : (isArabic ? 'تسجيل الخروج' : 'Sign Out'),
                  style: TextStyle(
                    color: isGuest ? AxisColors.primary : AxisColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: isArabic ? 0.0 : 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays confirmation dialog to sign out of the active Supabase account.
void showMeConfirmSignOutDialog(BuildContext context) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  HapticFeedback.lightImpact();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AxisColors.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AxisColors.borderPrimary),
      ),
      title: Text(
        isArabic ? 'تسجيل الخروج؟' : 'Sign Out?',
        style: const TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.bold),
      ),
      content: Text(
        isArabic
            ? 'هل أنت متأكد من رغبتك في تسجيل الخروج؟ تظل بياناتك السحابية محفوظة بأمان وستتم مزامنتها تلقائياً عند تسجيل الدخول التالي.'
            : 'Are you sure you want to sign out? Your cloud data remains securely saved and will sync automatically upon your next sign-in.',
        style: const TextStyle(color: AxisColors.textMuted, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            isArabic ? 'إلغاء' : 'Cancel',
            style: const TextStyle(color: AxisColors.textDim),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AxisColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              await AuthService().signOut();
            } catch (_) {}
            if (!context.mounted) return;
            context.go('/auth');
          },
          child: Text(
            isArabic ? 'تسجيل الخروج' : 'Sign Out',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Displays confirmation dialog to exit guest mode.
void showMeConfirmExitGuestModeDialog(BuildContext context) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AxisColors.surfaceLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AxisColors.borderPrimary),
      ),
      title: Text(
        isArabic ? 'الخروج من وضع الضيف؟' : 'Exit Guest Mode?',
        style: const TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.bold),
      ),
      content: Text(
        isArabic
            ? 'سيؤدي هذا إلى إنهاء جلسة الضيف المحلية والعودة إلى شاشة تسجيل الدخول حيث يمكنك تسجيل الدخول إلى حسابك.'
            : 'This will clear your local guest session and return you to the sign-in screen where you can log into your Supabase account.',
        style: const TextStyle(color: AxisColors.textMuted, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            isArabic ? 'إلغاء' : 'Cancel',
            style: const TextStyle(color: AxisColors.textDim),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AxisColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              await AuthService().signOut();
            } catch (_) {}
            if (!context.mounted) return;
            context.go('/auth');
          },
          child: Text(
            isArabic ? 'الخروج إلى تسجيل الدخول' : 'Exit to Login',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

