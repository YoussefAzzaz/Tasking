import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// User Profile cockpit card with user avatar, title, level, total XP,
/// friend code copy action, level progress bar, and profile editing dialog.
class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.userName,
    required this.userTitle,
    required this.level,
    required this.totalXp,
    required this.onSaveProfile,
    this.friendCode,
    this.avatarUrl,
    this.avatarColor,
    this.isUploadingAvatar = false,
    this.onAvatarTap,
  });

  final String userName;
  final String userTitle;
  final int level;
  final int totalXp;
  final String? friendCode;
  final dynamic onSaveProfile;
  final String? avatarUrl;
  final String? avatarColor;
  final bool isUploadingAvatar;
  final VoidCallback? onAvatarTap;

  void _triggerSave(String name, String title, String? color) {
    if (onSaveProfile is void Function(String, String, String?)) {
      (onSaveProfile as void Function(String, String, String?))(name, title, color);
    } else if (onSaveProfile is void Function(String, String)) {
      (onSaveProfile as void Function(String, String))(name, title);
    } else if (onSaveProfile is Function) {
      try {
        (onSaveProfile as dynamic)(name, title, color);
      } catch (_) {
        (onSaveProfile as dynamic)(name, title);
      }
    }
  }

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.primary;
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.primary;
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: userName);
    final titleCtrl = TextEditingController(text: userTitle);
    String selectedColor = avatarColor ?? '#6366F1';

    const presetColors = [
      '#6366F1', // Electric Indigo
      '#38BDF8', // Atmospheric Cyan
      '#10B981', // Emerald
      '#F59E0B', // Amber
      '#EC4899', // Pink
      '#A855F7', // Purple
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISPLAY NAME',
                  style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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
                    letterSpacing: 0.5,
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
                const SizedBox(height: 14),
                const Text(
                  'AVATAR ACCENT COLOR',
                  style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...presetColors.map((hex) {
                      final isSel = selectedColor.toUpperCase() == hex.toUpperCase();
                      final col = _parseHex(hex);
                      return InkWell(
                        onTap: () => setDlgState(() => selectedColor = hex),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.2,
                            ),
                          ),
                          child: isSel
                              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }),
                    RainbowColorPickerButton(
                      selectedColor: selectedColor,
                      size: 30,
                      borderWidth: 2,
                      onColorSelected: (col) => setDlgState(() => selectedColor = col),
                    ),
                  ],
                ),
              ],
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newTitle = titleCtrl.text.trim();
                Navigator.pop(ctx);
                if (newName.isNotEmpty) {
                  _triggerSave(
                    newName,
                    newTitle.isNotEmpty ? newTitle : 'System Operative',
                    selectedColor,
                  );
                }
              },
              child: const Text('Save Changes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLevelXp = GamificationEngine.xpToReachLevel(level);
    final nextLevelXp = GamificationEngine.xpToReachLevel(level + 1);
    final xpDiff = nextLevelXp - currentLevelXp;
    final xpProgress = xpDiff > 0 ? ((totalXp - currentLevelXp) / xpDiff).clamp(0.0, 1.0) : 1.0;
    final remainingXp = (nextLevelXp - totalXp).clamp(0, xpDiff);

    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarWidget(
                avatarUrl: avatarUrl,
                name: userName,
                avatarColor: avatarColor,
                size: 64,
                isUploading: isUploadingAvatar,
                showEditBadge: true,
                onTap: onAvatarTap,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded,
                              color: AxisColors.primarySoft, size: 22),
                          tooltip: 'Edit Profile',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditProfileDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userTitle,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AxisColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (friendCode != null && friendCode!.trim().isNotEmpty) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: friendCode!.trim()));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Friend Code "${friendCode!.trim()}" copied to clipboard!'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: AxisColors.surfaceHigh,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_rounded, size: 12, color: AxisColors.secondarySoft),
                                const SizedBox(width: 4),
                                Text(
                                  'CODE: ${friendCode!.trim()}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.secondarySoft,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy_rounded, size: 11, color: AxisColors.textDim),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: AxisColors.borderSubtle, height: 1),
          const SizedBox(height: 12),

          // Gamification Level and XP Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AxisColors.secondary, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Level $level • $totalXp XP',
                        style: const TextStyle(
                          color: AxisColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$remainingXp XP to LVL ${level + 1}',
                  style: const TextStyle(
                    color: AxisColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Sleek animated XP Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: AxisColors.surfaceLowest,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: xpProgress.clamp(0.02, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AxisColors.primary, AxisColors.secondary],
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
