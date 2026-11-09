import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/ui/desktop/shell/desktop_titlebar.dart';
import 'package:axis/ui/auth/widgets/auth_ambient_glows.dart';
import 'package:axis/ui/auth/widgets/auth_form_components.dart';
import 'package:axis/ui/auth/widgets/auth_text_field.dart';
import 'package:axis/ui/auth/widgets/auth_language_switcher.dart';

/// Full desktop presentation for the Axis Authentication screen.
class DesktopAuthView extends StatelessWidget {
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

  const DesktopAuthView({
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
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Desktop Titlebar with full window management pinned to max right
          const DesktopTitlebar(onOpenOmnibar: null),

          // Main desktop terminal center
          Expanded(
            child: Stack(
              children: [
                // Cyber Ambient Glow Orbs
                const AuthAmbientGlows(isDesktop: true),

                // Center Card
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: FadeTransition(
                      opacity: fadeAnim,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AxisColors.borderGlass2,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.7),
                                blurRadius: 36,
                                offset: const Offset(0, 14),
                              ),
                              BoxShadow(
                                color: AxisColors.primary.withValues(alpha: 0.08),
                                blurRadius: 40,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Header Bar: Guest Return + Language Switcher
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
                                            size: 14,
                                            color: AxisColors.textMuted,
                                          ),
                                          label: Text(
                                            isArabic ? 'العودة إلى وضع الضيف' : 'RETURN TO GUEST MODE',
                                            style: GoogleFonts.spaceGrotesk(
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

                                // Station Logo & Branding
                                const AuthHeaderBranding(isDesktop: true),
                                const SizedBox(height: 24),

                                // Tab Switcher: Sign In vs Sign Up
                                AuthModeToggle(
                                  isSignUp: isSignUp,
                                  onModeChanged: onModeChanged,
                                  isDesktop: true,
                                ),
                                const SizedBox(height: 20),

                                // Error Banner if present
                                if (errorMessage != null) ...[
                                  AuthErrorBanner(errorMessage: errorMessage!),
                                  const SizedBox(height: 16),
                                ],

                                // Display Name Field (SignUp only)
                                if (isSignUp) ...[
                                  AuthTextField(
                                    controller: nameCtrl,
                                    hint: isArabic ? 'الاسم الكامل أو الرمز' : 'Full Name or Call-Sign',
                                    label: isArabic ? 'اسم المشغل' : 'OPERATOR CALL-SIGN',
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
                                  hint: 'operator@axis.station',
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
                                const SizedBox(height: 22),

                                // Submit Button
                                AuthSubmitButton(
                                  isLoading: isLoading,
                                  isSignUp: isSignUp,
                                  isDesktop: true,
                                  onSubmit: onSubmit,
                                ),
                                const SizedBox(height: 12),

                                // Offline Mode Entrance
                                AuthOfflineButton(
                                  isLoading: isLoading,
                                  isDesktop: true,
                                  onContinueOffline: onContinueOffline,
                                ),
                                const SizedBox(height: 16),

                                // Security Note
                                const AuthSecurityNote(isDesktop: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

