import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:axis/core/theme.dart';

/// Cyber-minimalist Profile Avatar Picker Bottom Sheet
/// Allows taking a new photo, choosing from gallery, or removing current avatar.
class ProfileAvatarPickerSheet extends StatelessWidget {
  const ProfileAvatarPickerSheet({
    super.key,
    required this.hasCustomAvatar,
    required this.onSourceSelected,
    required this.onRemoveSelected,
  });

  final bool hasCustomAvatar;
  final void Function(ImageSource source) onSourceSelected;
  final VoidCallback onRemoveSelected;

  static Future<void> show({
    required BuildContext context,
    required bool hasCustomAvatar,
    required void Function(ImageSource source) onSourceSelected,
    required VoidCallback onRemoveSelected,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ProfileAvatarPickerSheet(
        hasCustomAvatar: hasCustomAvatar,
        onSourceSelected: onSourceSelected,
        onRemoveSelected: onRemoveSelected,
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AxisColors.primary,
    Color titleColor = AxisColors.textHigh,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AxisColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: AxisColors.textDim,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AxisColors.borderPrimary,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AxisColors.textDim.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      color: AxisColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'صورة الملف الشخصي' : 'Profile Picture',
                      style: TextStyle(
                        color: AxisColors.textHigh,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isArabic ? 0.0 : 0.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AxisColors.textDim, size: 20),
                      onPressed: () => Navigator.pop(context),
                      tooltip: isArabic ? 'إغلاق' : 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(color: AxisColors.borderSubtle, height: 1),
              const SizedBox(height: 8),

              // Option 1: Take Photo
              _buildOption(
                context: context,
                icon: Icons.camera_alt_rounded,
                title: isArabic ? 'التقاط صورة' : 'Take Photo',
                subtitle: isArabic
                    ? 'استخدم الكاميرا لالتقاط صورة جديدة'
                    : 'Use your camera to capture a new picture',
                onTap: () => onSourceSelected(ImageSource.camera),
              ),

              // Option 2: Choose from Gallery
              _buildOption(
                context: context,
                icon: Icons.photo_library_rounded,
                title: isArabic ? 'اختيار من المعرض' : 'Choose from Gallery',
                subtitle: isArabic
                    ? 'حدد صورة موجودة من جهازك'
                    : 'Select an existing image from your device',
                onTap: () => onSourceSelected(ImageSource.gallery),
              ),

              // Option 3: Remove Avatar (if exists)
              if (hasCustomAvatar) ...[
                const SizedBox(height: 4),
                _buildOption(
                  context: context,
                  icon: Icons.delete_outline_rounded,
                  title: isArabic ? 'إزالة الصورة' : 'Remove Photo',
                  subtitle: isArabic
                      ? 'الرجوع إلى الصورة الرمزية الافتراضية'
                      : 'Revert to default initials avatar',
                  iconColor: AxisColors.error,
                  titleColor: AxisColors.error,
                  onTap: onRemoveSelected,
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
