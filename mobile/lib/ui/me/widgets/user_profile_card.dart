import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// User Profile cockpit card with user avatar, title, level, total XP, and profile editing dialog
class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.userName,
    required this.userTitle,
    required this.level,
    required this.totalXp,
    required this.onSaveProfile,
    this.avatarUrl,
    this.avatarColor,
    this.isUploadingAvatar = false,
    this.onAvatarTap,
  });

  final String userName;
  final String userTitle;
  final int level;
  final int totalXp;
  final void Function(String name, String title) onSaveProfile;
  final String? avatarUrl;
  final String? avatarColor;
  final bool isUploadingAvatar;
  final VoidCallback? onAvatarTap;

  void _showEditProfileDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: userName);
    final titleCtrl = TextEditingController(text: userTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AxisColors.textHigh,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DISPLAY NAME',
              style: TextStyle(
                color: AxisColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              autofocus: false,
              style: const TextStyle(color: AxisColors.textHigh),
              decoration: InputDecoration(
                hintText: 'e.g. Alex Vance',
                hintStyle: const TextStyle(color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'TITLE / BIO',
              style: TextStyle(
                color: AxisColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: AxisColors.textHigh),
              decoration: InputDecoration(
                hintText: 'e.g. Lead Architect, System Operative',
                hintStyle: const TextStyle(color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AxisColors.primary,
            ),
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newTitle = titleCtrl.text.trim();
              Navigator.pop(ctx);
              if (newName.isNotEmpty) {
                onSaveProfile(
                  newName,
                  newTitle.isNotEmpty ? newTitle : 'System Operative',
                );
              }
            },
            child: const Text('Save Changes',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AvatarWidget(
            avatarUrl: avatarUrl,
            name: userName,
            avatarColor: avatarColor,
            size: 60,
            isUploading: isUploadingAvatar,
            showEditBadge: true,
            onTap: onAvatarTap,
            heroTag: 'user_profile_avatar',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AxisColors.textHigh,
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  userTitle,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AxisColors.textMuted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AxisColors.secondary, size: 15),
                    const SizedBox(width: 3),
                    Text(
                      'Level $level • $totalXp XP',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AxisColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded,
                color: AxisColors.primarySoft, size: 22),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileDialog(context),
          ),
        ],
      ),
    );
  }
}
