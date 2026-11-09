import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/ui/me/widgets/profile_avatar_picker.dart';
import 'package:axis/ui/me/widgets/image_crop_dialog.dart';

/// Encapsulates avatar picking, image cropping, and cloud/local persistence.
class MeAvatarService {
  /// Opens the avatar action sheet (Camera, Gallery, Remove).
  static void openAvatarPicker({
    required BuildContext context,
    required bool hasCustomAvatar,
    required Function(bool isUploading) onLoadingChanged,
    required Function(String? newUrl) onAvatarUpdated,
  }) {
    ProfileAvatarPickerSheet.show(
      context: context,
      hasCustomAvatar: hasCustomAvatar,
      onSourceSelected: (source) => pickAndUploadAvatar(
        context: context,
        source: source,
        onLoadingChanged: onLoadingChanged,
        onAvatarUpdated: onAvatarUpdated,
      ),
      onRemoveSelected: () => removeAvatar(
        context: context,
        onLoadingChanged: onLoadingChanged,
        onAvatarUpdated: onAvatarUpdated,
      ),
    );
  }

  /// Launches picker, shows image cropping dialog, and uploads avatar.
  static Future<void> pickAndUploadAvatar({
    required BuildContext context,
    required ImageSource source,
    required Function(bool isUploading) onLoadingChanged,
    required Function(String? newUrl) onAvatarUpdated,
  }) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (image == null) return;

      final rawBytes = await image.readAsBytes();
      if (!context.mounted) return;

      final croppedBytes = await ImageCropDialog.show(
        context,
        imageBytes: rawBytes,
      );

      if (croppedBytes == null) return;

      onLoadingChanged(true);

      final newUrl = await UserProfileRepository().uploadAvatar(
        croppedBytes,
        contentType: 'image/png',
      );

      if (context.mounted) {
        onAvatarUpdated(newUrl);
        onLoadingChanged(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: AxisColors.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        onLoadingChanged(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: AxisColors.error,
          ),
        );
      }
    }
  }

  /// Removes current user avatar and resets to procedural color identicon.
  static Future<void> removeAvatar({
    required BuildContext context,
    required Function(bool isUploading) onLoadingChanged,
    required Function(String? newUrl) onAvatarUpdated,
  }) async {
    try {
      onLoadingChanged(true);
      await UserProfileRepository().removeAvatar();

      if (context.mounted) {
        onAvatarUpdated(null);
        onLoadingChanged(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: AxisColors.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        onLoadingChanged(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove picture: $e'),
            backgroundColor: AxisColors.error,
          ),
        );
      }
    }
  }
}

