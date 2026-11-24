import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/ui/auth/widgets/auth_ambient_glows.dart';
import 'package:axis/ui/auth/widgets/auth_form_components.dart';
import 'package:axis/ui/auth/widgets/auth_text_field.dart';
import 'package:axis/ui/auth/widgets/auth_language_switcher.dart';

/// Full mobile presentation for the Axis Authentication screen.
class MobileAuthView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Animation<double> fadeAnim;
  final bool isSignUp;
  final bool obscurePassword;
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;
  final VoidCallback onContinueOffline;
  final bool rememberMe;
  final ValueChanged<bool>? onRememberMeChanged;

  const MobileAuthView({
    super.key,
    required this.formKey,
    required this.fadeAnim,
    required this.isSignUp,
    required this.obscurePassword,
    required this.isLoading,
    required this.errorMessage,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.onModeChanged,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
    required this.onContinueOffline,
    this.rememberMe = true,
    this.onRememberMeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: Stack(
        children: [
          // Ambient Background Glows
          const AuthAmbientGlows(isDesktop: false),

          // Main Interactive Scroll Canvas
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: bottomInset > 0 ? bottomInset + 20 : 32,
                ),
                child: FadeTransition(
                  opacity: fadeAnim,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Bar: Guest Mode return + Language Switcher
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (AuthService().isGuest)
                                TextButton.icon(
                                  onPressed: () => context.go('/today'),
                                  icon: Icon(
                                    isArabic ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                                    size: 16,
                                    color: AxisColors.textMuted,
                                  ),
                                  label: Text(
                                    isArabic ? 'العودة للضيف' : 'GUEST MODE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AxisColors.textMuted,
                                      letterSpacing: isArabic ? 0.0 : 0.8,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              const AuthLanguageSwitcher(),
                            ],
                          ),
                        ),

                        // App Brand & Logo Badge
                        const AuthHeaderBranding(isDesktop: false),
                        const SizedBox(height: 28),

                        // Tab Switcher: Sign In vs Sign Up
                        AuthModeToggle(
                          isSignUp: isSignUp,
                          onModeChanged: onModeChanged,
                          isDesktop: false,
                        ),
                        const SizedBox(height: 20),

                        // Session Expired Notice when redirected due to deprecated/expired token
                        if (AuthService().isSessionExpired) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AxisColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AxisColors.danger.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AxisColors.danger,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isArabic
                                        ? 'انتهت صلاحية جلستك. يرجى تسجيل الدخول مجدداً لاستئناف المزامنة.'
                                        : 'Your session has expired. Please log in again to resume synchronization.',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AxisColors.textHigh,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Error Banner if present
                        if (errorMessage != null) ...[
                          AuthErrorBanner(errorMessage: errorMessage!),
                          const SizedBox(height: 16),
                        ],

                        // Quick Login Card with Cached Hashed & Encrypted Credentials
                        if (!isSignUp && AuthService().hasSavedCredentials) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AxisColors.secondary.withValues(alpha: 0.35),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AxisColors.secondary.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AxisColors.secondary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_person_rounded,
                                    size: 15,
                                    color: AxisColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isArabic ? 'حساب محفوظ (مشفر)' : 'SAVED ACCOUNT READY',
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: AxisColors.secondarySoft,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        AuthService().savedEmail ?? '',
                                        style: GoogleFonts.getFont(
                                          'Geist',
                                          fontSize: 12,
                                          color: AxisColors.textHigh,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    emailCtrl.text = AuthService().savedEmail ?? '';
                                    final p = AuthService().getDecryptedPassword();
                                    if (p != null) passwordCtrl.text = p;
                                    onSubmit();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    backgroundColor: AxisColors.secondary.withValues(alpha: 0.18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    isArabic ? 'دخول سريع' : 'QUICK LOGIN',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AxisColors.secondarySoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Display Name Field (SignUp only)
                        if (isSignUp) ...[
                          AuthTextField(
                            controller: nameCtrl,
                            hint: isArabic ? 'الاسم الكامل أو الرمز' : 'Full Name or Call-Sign',
                            label: isArabic ? 'اسم المشغل' : 'OPERATOR NAME',
                            icon: Icons.person_outline_rounded,
                            validator: (val) {
                              if (isSignUp && (val == null || val.trim().isEmpty)) {
                                return isArabic
                                    ? 'يرجى إدخال اسمك أو رمز المشغل'
                                    : 'Enter your name or operator call-sign';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email Field
                        AuthTextField(
                          controller: emailCtrl,
                          hint: 'name@example.com',
                          label: isArabic ? 'البريد الإلكتروني للنظام' : 'SYSTEM EMAIL',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic ? 'البريد الإلكتروني مطلوب' : 'Email is required';
                            }
                            if (!val.contains('@') || !val.contains('.')) {
                              return isArabic ? 'يرجى إدخال بريد إلكتروني صالح' : 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        AuthTextField(
                          controller: passwordCtrl,
                          hint: '••••••••',
                          label: isArabic ? 'رمز المرور' : 'ACCESS PASSCODE',
                          icon: Icons.lock_outline_rounded,
                          obscureText: obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AxisColors.textDim,
                              size: 18,
                            ),
                            onPressed: onTogglePasswordVisibility,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return isArabic ? 'كلمة المرور مطلوبة' : 'Password is required';
                            }
                            if (val.length < 6) {
                              return isArabic
                                  ? 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل'
                                  : 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (!isSignUp) ...[
                          const SizedBox(height: 10),
                          AuthRememberMeButton(
                            value: rememberMe,
                            onChanged: onRememberMeChanged ?? (_) {},
                          ),
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 24),

                        // Submit Button
                        AuthSubmitButton(
                          isLoading: isLoading,
                          isSignUp: isSignUp,
                          isDesktop: false,
                          onSubmit: onSubmit,
                        ),
                        const SizedBox(height: 12),

                        // Offline Mode fallback entrance
                        AuthOfflineButton(
                          isLoading: isLoading,
                          isDesktop: false,
                          onContinueOffline: onContinueOffline,
                        ),
                        const SizedBox(height: 16),

                        // Isolation & PowerSync Architecture notice
                        const AuthSecurityNote(isDesktop: false),
                      ],
                    ),
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

