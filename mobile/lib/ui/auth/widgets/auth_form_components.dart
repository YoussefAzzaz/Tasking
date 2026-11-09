import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Branding header with cyber logo and typography for Auth screen.
class AuthHeaderBranding extends StatelessWidget {
  final bool isDesktop;

  const AuthHeaderBranding({
    super.key,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.primary.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                cacheWidth: 128,
                cacheHeight: 128,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'AXIS COMMAND STATION',
            style: GoogleFonts.spaceGrotesk(
              color: AxisColors.textHigh,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'OFFLINE-FIRST CLOUD SYNC & AUTHENTICATION',
            style: GoogleFonts.spaceGrotesk(
              color: AxisColors.secondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 10,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AxisColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
              cacheWidth: 128,
              cacheHeight: 128,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AXIS',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'OFFLINE-FIRST CLOUD SYNC & AUTH',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AxisColors.primarySoft,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.6,
              ),
        ),
      ],
    );
  }
}

/// Mode toggle selector switching between 'SIGN IN' and 'CREATE ACCOUNT'.
class AuthModeToggle extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool> onModeChanged;
  final bool isDesktop;

  const AuthModeToggle({
    super.key,
    required this.isSignUp,
    required this.onModeChanged,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final borderRadius = isDesktop ? BorderRadius.circular(10) : BorderRadius.circular(14);
    final innerRadius = isDesktop ? BorderRadius.circular(8) : BorderRadius.circular(10);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: borderRadius,
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 9 : 10),
                decoration: BoxDecoration(
                  color: !isSignUp
                      ? AxisColors.primary.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: innerRadius,
                  border: !isSignUp
                      ? Border.all(color: AxisColors.primary.withValues(alpha: 0.6))
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  isArabic ? 'تسجيل الدخول' : 'SIGN IN',
                  style: isDesktop
                      ? GoogleFonts.spaceGrotesk(
                          color: !isSignUp ? AxisColors.primarySoft : AxisColors.textDim,
                          fontWeight: FontWeight.w700,
                          letterSpacing: isArabic ? 0.0 : 1.2,
                          fontSize: 11,
                        )
                      : TextStyle(
                          color: !isSignUp ? AxisColors.primarySoft : AxisColors.textDim,
                          fontWeight: FontWeight.bold,
                          letterSpacing: isArabic ? 0.0 : 1.2,
                          fontSize: 12,
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 9 : 10),
                decoration: BoxDecoration(
                  color: isSignUp
                      ? AxisColors.primary.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: innerRadius,
                  border: isSignUp
                      ? Border.all(color: AxisColors.primary.withValues(alpha: 0.6))
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  isArabic ? 'إنشاء حساب' : 'CREATE ACCOUNT',
                  style: isDesktop
                      ? GoogleFonts.spaceGrotesk(
                          color: isSignUp ? AxisColors.primarySoft : AxisColors.textDim,
                          fontWeight: FontWeight.w700,
                          letterSpacing: isArabic ? 0.0 : 1.2,
                          fontSize: 11,
                        )
                      : TextStyle(
                          color: isSignUp ? AxisColors.primarySoft : AxisColors.textDim,
                          fontWeight: FontWeight.bold,
                          letterSpacing: isArabic ? 0.0 : 1.2,
                          fontSize: 12,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alert banner showing cleaned error message.
class AuthErrorBanner extends StatelessWidget {
  final String errorMessage;

  const AuthErrorBanner({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AxisColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AxisColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AxisColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient submit button with loading indicator.
class AuthSubmitButton extends StatelessWidget {
  final bool isLoading;
  final bool isSignUp;
  final bool isDesktop;
  final VoidCallback onSubmit;

  const AuthSubmitButton({
    super.key,
    required this.isLoading,
    required this.isSignUp,
    this.isDesktop = false,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final height = isDesktop ? 48.0 : 52.0;
    final borderRadius = isDesktop ? BorderRadius.circular(10) : BorderRadius.circular(12);

    return MouseRegion(
      cursor: isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isLoading ? null : onSubmit,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AxisColors.primary, AxisColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: AxisColors.primary.withValues(alpha: isDesktop ? 0.35 : 0.4),
                blurRadius: isDesktop ? 14 : 18,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSignUp ? Icons.person_add_rounded : Icons.login_rounded,
                      color: Colors.white,
                      size: isDesktop ? 17 : 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSignUp
                          ? (isArabic
                              ? (isDesktop ? 'تهيئة الحساب' : 'تسجيل حساب جديد')
                              : (isDesktop ? 'INITIALIZE ACCOUNT' : 'REGISTER ACCOUNT'))
                          : (isArabic
                              ? (isDesktop ? 'دخول محطة القيادة' : 'الدخول إلى النظام')
                              : (isDesktop ? 'ENTER COMMAND STATION' : 'ENTER SYSTEM')),
                      style: isDesktop
                          ? GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: isArabic ? 0.0 : 1.0,
                              fontSize: 12,
                            )
                          : TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: isArabic ? 0.0 : 1.4,
                              fontSize: 13,
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Outlined button to enter offline mode.
class AuthOfflineButton extends StatelessWidget {
  final bool isLoading;
  final bool isDesktop;
  final VoidCallback onContinueOffline;

  const AuthOfflineButton({
    super.key,
    required this.isLoading,
    this.isDesktop = false,
    required this.onContinueOffline,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return SizedBox(
      height: isDesktop ? 40 : 44,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onContinueOffline,
        icon: Icon(
          Icons.cloud_off_rounded,
          size: isDesktop ? 15 : 16,
          color: AxisColors.textMuted,
        ),
        label: Text(
          isArabic ? 'المتابعة في وضع عدم الاتصال' : 'CONTINUE IN OFFLINE MODE',
          style: isDesktop
              ? GoogleFonts.spaceGrotesk(
                  color: AxisColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: isArabic ? 0.0 : 1.0,
                )
              : TextStyle(
                  color: AxisColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: isArabic ? 0.0 : 1.1,
                ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AxisColors.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 10 : 12),
          ),
        ),
      ),
    );
  }
}

/// Architecture and security notice at bottom of auth views.
class AuthSecurityNote extends StatelessWidget {
  final bool isDesktop;

  const AuthSecurityNote({
    super.key,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          color: AxisColors.tertiary,
          size: isDesktop ? 13 : 14,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isDesktop
                ? (isArabic
                    ? 'عزل معرّف المستخدم عبر PowerSync نشط • قاعدة بيانات AES SQLite محلية'
                    : 'PowerSync user_id isolation active • Local AES SQLite database')
                : (isArabic
                    ? 'عزل المستخدم عبر PowerSync نشط'
                    : 'PowerSync user_id isolation active'),
            overflow: TextOverflow.ellipsis,
            style: isDesktop
                ? GoogleFonts.spaceGrotesk(
                    color: AxisColors.textDim,
                    fontSize: 10,
                    letterSpacing: isArabic ? 0.0 : 0.5,
                  )
                : Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AxisColors.textDim,
                      fontSize: 11,
                      letterSpacing: isArabic ? 0.0 : 0.8,
                    ),
          ),
        ),
      ],
    );
  }
}

