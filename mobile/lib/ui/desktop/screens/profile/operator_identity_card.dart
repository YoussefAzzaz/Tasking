import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/auth_service.dart';
import '../../../../data/user_profile_repository.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Card for operator credentials: name, call-sign, station email, and cloud avatar.
class OperatorIdentityCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController callsignController;
  final TextEditingController avatarUrlController;
  final bool isUploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onRemoveAvatar;

  const OperatorIdentityCard({
    super.key,
    required this.nameController,
    required this.callsignController,
    required this.avatarUrlController,
    required this.isUploadingAvatar,
    required this.onPickAvatar,
    required this.onRemoveAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository().profileNotifier,
      builder: (context, profile, _) {
        final email = AuthService().currentUser?.email ??
            AuthService().savedEmail ??
            (isAr ? 'حساب محلي' : 'Local / Offline');

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isAr ? 'هوية المشغل' : 'OPERATOR IDENTITY',
                trailing: TelemetryChip(
                  label: isAr ? 'مُوثَّق' : 'VERIFIED',
                  dotColor: AxisColors.tertiary,
                  color: AxisColors.tertiary,
                ),
              ),
              const SizedBox(height: 12),

              // Avatar Section
              _buildFieldLabel(isAr ? 'الصورة الشخصية وصورة الهوية' : 'AVATAR PHOTO & IDENTITY PICTURE'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: AxisColors.secondary, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.secondary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                          ? Image.network(
                              profile.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.person_rounded, size: 28, color: AxisColors.textHigh),
                            )
                          : const Icon(Icons.person_rounded, size: 28, color: AxisColors.textHigh),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GhostButton(
                              label: isUploadingAvatar
                                  ? (isAr ? 'جارٍ الرفع...' : 'Uploading...')
                                  : (isAr ? 'اختيار صورة' : 'Choose Picture'),
                              icon: Icons.upload_file_rounded,
                              height: 36,
                              onPressed: isUploadingAvatar ? null : onPickAvatar,
                            ),
                            if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GhostButton(
                                label: isAr ? 'إزالة' : 'Remove',
                                icon: Icons.delete_outline_rounded,
                                height: 36,
                                color: AxisColors.error,
                                onPressed: onRemoveAvatar,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAr
                              ? 'ارفع صورة JPG أو PNG أو WebP. تتم المزامنة تلقائياً مع السحابة والهاتف.'
                              : 'Upload JPG, PNG, or WebP. Automatically synced to cloud and mobile.',
                          style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFieldLabel(isAr ? 'أو رابط صورة الهوية (URL)' : 'OR AVATAR IMAGE URL'),
              const SizedBox(height: 6),
              _buildTextInput(avatarUrlController, 'https://example.com/avatar.jpg'),
              const SizedBox(height: 14),

              // Display Name
              _buildFieldLabel(isAr ? 'اسم العرض' : 'DISPLAY NAME'),
              const SizedBox(height: 6),
              _buildTextInput(nameController, isAr ? 'أدخل اسم المشغل' : 'Enter operator name'),

              const SizedBox(height: 14),

              // Call-Sign / Tag
              _buildFieldLabel(isAr ? 'رمز النداء / المعرف' : 'CALL-SIGN / IDENTIFIER'),
              const SizedBox(height: 6),
              _buildTextInput(callsignController, isAr ? 'أدخل رمز النداء' : 'Enter callsign'),

              const SizedBox(height: 14),

              // Primary Station Email
              _buildFieldLabel(isAr ? 'البريد الإلكتروني الأساسي للمحطة' : 'PRIMARY STATION EMAIL'),
              const SizedBox(height: 6),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Text(
                  email,
                  style: AxisFonts.spaceGrotesk(fontSize: 12, color: AxisColors.textDim),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 2, left: 2),
      child: Text(
        label,
        style: AxisFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AxisColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildTextInput(TextEditingController controller, String hint) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AxisColors.borderSubtle, width: 1),
      ),
      child: TextField(
        controller: controller,
        style: AxisFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AxisFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
          filled: false,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        ),
      ),
    );
  }
}

