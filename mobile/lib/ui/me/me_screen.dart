import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/ui/common/sync_status_modal.dart';
import 'package:axis/ui/me/widgets/user_profile_card.dart';
import 'package:axis/ui/me/widgets/habit_categories_section.dart';
import 'package:axis/ui/me/widgets/note_categories_section.dart';
import 'package:axis/ui/me/widgets/task_tags_section.dart';
import 'package:axis/ui/me/widgets/me_sections.dart';
import 'package:axis/ui/me/widgets/profile_avatar_picker.dart';
import 'package:axis/ui/me/widgets/image_crop_dialog.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/l10n/locale_service.dart';

export 'package:axis/ui/me/widgets/user_profile_card.dart';
export 'package:axis/ui/me/widgets/habit_categories_section.dart';
export 'package:axis/ui/me/widgets/note_categories_section.dart';
export 'package:axis/ui/me/widgets/task_tags_section.dart';
export 'package:axis/ui/me/widgets/me_sections.dart';
export 'package:axis/ui/me/mastery_badges_screen.dart';
export 'package:axis/ui/me/widgets/avatar_widget.dart';
export 'package:axis/ui/me/widgets/profile_avatar_picker.dart';
export 'package:axis/ui/me/widgets/image_crop_dialog.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  int _totalXp = 0;
  int _level = 1;
  String _userName = 'Cyber Kinetic';
  String _userTitle = 'System Operative';
  String? _avatarUrl;
  String? _avatarColor;
  String? _friendCode;
  bool _isUploadingAvatar = false;

  List<Map<String, dynamic>> _habitCategories = [];
  List<Map<String, dynamic>> _noteCategories = [];
  List<String> _taskTags = [];
  StreamSubscription<List<HabitCategory>>? _categoriesSub;
  StreamSubscription<List<NoteCategory>>? _noteCategoriesSub;
  StreamSubscription<List<String>>? _tagsSub;
  StreamSubscription<UserStats>? _statsSub;

  @override
  void initState() {
    super.initState();
    UserProfileRepository().profileNotifier.addListener(_onProfileNotifierChanged);
    _onProfileNotifierChanged();
    _loadAllUserData();

    _categoriesSub = HabitCategoryRepository().watchCategories().listen((cats) {
      if (mounted) {
        setState(() {
          _habitCategories = cats
              .map((c) => {
                    'id': c.id,
                    'name': c.name,
                    'icon': c.icon,
                    'color': c.color,
                  })
              .toList();
        });
      }
    });

    _noteCategoriesSub = NoteCategoryRepository().watchCategories().listen((cats) {
      if (mounted) {
        setState(() {
          _noteCategories = cats
              .map((c) => {
                    'id': c.id,
                    'name': c.name,
                    'icon': c.icon,
                    'color': c.color,
                  })
              .toList();
        });
      }
    });

    _tagsSub = TagRepository().watchTags().listen((tags) {
      if (mounted) {
        setState(() {
          _taskTags = tags;
        });
      }
    });

    _statsSub = StatsRepository().watchStats().listen((stats) {
      if (mounted) {
        setState(() {
          _totalXp = stats.totalXp;
          _level = stats.level;
        });
      }
    });
  }

  @override
  void dispose() {
    UserProfileRepository().profileNotifier.removeListener(_onProfileNotifierChanged);
    _categoriesSub?.cancel();
    _noteCategoriesSub?.cancel();
    _tagsSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  void _onProfileNotifierChanged() {
    final profile = UserProfileRepository().profileNotifier.value;
    final auth = AuthService();
    if (mounted) {
      setState(() {
        _userName = profile.name.isNotEmpty && profile.name != 'Commander'
            ? profile.name
            : (auth.displayName.isNotEmpty && auth.displayName != 'Operative'
                ? auth.displayName
                : profile.name);
        _userTitle = profile.title.isNotEmpty ? profile.title : 'Specialist';
        _avatarUrl = profile.avatarUrl;
        _avatarColor = profile.avatarColor;
        _friendCode = profile.friendCode;
        if (profile.totalXp > 0) _totalXp = profile.totalXp;
        if (profile.level > 0) _level = profile.level;
      });
    }
  }

  Future<void> _loadAllUserData() async {
    await Future.wait([
      _loadUserStats(),
      _loadProfile(),
      _loadHabitCategories(),
      _loadTaskTags(),
    ]);
  }

  Future<void> _loadUserStats() async {
    try {
      final stats = await StatsRepository().getUserStats();
      if (mounted) {
        setState(() {
          _totalXp = stats.totalXp;
          _level = stats.level;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserProfileRepository().getProfile();
      final auth = AuthService();
      if (mounted) {
        setState(() {
          _userName = profile.name.isNotEmpty && profile.name != 'Commander'
              ? profile.name
              : (auth.displayName.isNotEmpty && auth.displayName != 'Operative'
                  ? auth.displayName
                  : profile.name);
          _userTitle = profile.title.isNotEmpty ? profile.title : 'Specialist';
          _avatarUrl = profile.avatarUrl;
          _avatarColor = profile.avatarColor;
          _friendCode = profile.friendCode;
          if (profile.totalXp > 0) _totalXp = profile.totalXp;
          if (profile.level > 0) _level = profile.level;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHabitCategories() async {
    try {
      final cats = await HabitCategoryRepository().getCategories(forceRefresh: true);
      if (mounted) {
        setState(() {
          _habitCategories = cats
              .map((c) => {
                    'id': c.id,
                    'name': c.name,
                    'icon': c.icon,
                    'color': c.color,
                  })
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTaskTags() async {
    try {
      final tags = await TagRepository().getTags();
      if (mounted) {
        setState(() {
          _taskTags = tags;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveProfile(String newName, String newTitle, String? newColor) async {
    setState(() {
      _userName = newName;
      _userTitle = newTitle;
      if (newColor != null) _avatarColor = newColor;
    });
    await UserProfileRepository().saveProfile(newName, newTitle, avatarColor: newColor);
  }

  void _openAvatarPicker() {
    ProfileAvatarPickerSheet.show(
      context: context,
      hasCustomAvatar: _avatarUrl != null && _avatarUrl!.isNotEmpty,
      onSourceSelected: _pickAndUploadAvatar,
      onRemoveSelected: _removeAvatar,
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
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
      if (!mounted) return;

      // Open Crop & Reframe interactive dialog
      final croppedBytes = await ImageCropDialog.show(
        context,
        imageBytes: rawBytes,
      );

      if (croppedBytes == null) {
        // User cancelled cropping
        return;
      }

      setState(() {
        _isUploadingAvatar = true;
      });

      final newUrl = await UserProfileRepository().uploadAvatar(
        croppedBytes,
        contentType: 'image/png',
      );

      if (mounted) {
        setState(() {
          _avatarUrl = newUrl;
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: AxisColors.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: AxisColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    try {
      setState(() {
        _isUploadingAvatar = true;
      });

      await UserProfileRepository().removeAvatar();

      if (mounted) {
        setState(() {
          _avatarUrl = null;
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: AxisColors.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove picture: $e'),
            backgroundColor: AxisColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addCategory(String catName, String selectedColor) async {
    await HabitCategoryRepository().addCategory(
      name: catName,
      color: selectedColor,
    );
    await _loadHabitCategories();
  }

  Future<void> _deleteCategory(String id, String name) async {
    await HabitCategoryRepository().deleteCategory(id, name: name);
    await _loadHabitCategories();
  }

  Future<void> _addNoteCategory(String catName, String selectedColor, String selectedIcon) async {
    await NoteCategoryRepository().addCategory(
      name: catName,
      color: selectedColor,
      icon: selectedIcon,
    );
  }

  Future<void> _deleteNoteCategory(String id, String name) async {
    await NoteCategoryRepository().deleteCategory(id, name: name);
  }

  Future<void> _addTag(String tagName) async {
    await TagRepository().addTag(tagName);
    await _loadTaskTags();
  }

  Future<void> _deleteTag(String tagName) async {
    await TagRepository().deleteTag(tagName);
    await _loadTaskTags();
  }

  void _confirmSignOut() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text(
          'Sign Out?',
          style: TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out? Your cloud data remains securely saved and will sync automatically upon your next sign-in.',
          style: TextStyle(color: AxisColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AxisColors.textDim),
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
              if (!mounted) return;
              context.go('/auth');
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmExitGuestMode() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text(
          'Exit Guest Mode?',
          style: TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will clear your local guest session and return you to the sign-in screen where you can log into your Supabase account.',
          style: TextStyle(color: AxisColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AxisColors.textDim),
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
              if (!mounted) return;
              context.go('/auth');
            },
            child: const Text(
              'Exit to Login',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestModeBanner() {
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
                const Expanded(
                  child: Text(
                    'LOCAL GUEST MODE ACTIVE',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your tasks, habits, and notes are currently stored only on this device. Sign in with your Supabase account to instantly synchronize with Desktop and cloud storage.',
              style: TextStyle(
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
                      label: const Text(
                        'SIGN IN TO SYNC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
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
                    onPressed: _confirmExitGuestMode,
                    child: const Text(
                      'EXIT GUEST',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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

  Widget _buildAccountCloudCard(AuthService auth) {
    final email = auth.currentUser?.email ?? 'Cloud Synced Account';
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
                  const Text(
                    'CONNECTED CLOUD ACCOUNT',
                    style: TextStyle(
                      color: AxisColors.tertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Diagnostics',
                        style: TextStyle(
                          color: AxisColors.primarySoft,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AxisColors.primarySoft),
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

  Widget _buildLanguageSection() {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService().localeNotifier,
      builder: (context, currentLocale, _) {
        final isArabic = currentLocale.languageCode == 'ar';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AxisColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: AxisColors.primarySoft,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.language,
                            style: const TextStyle(
                              color: AxisColors.textHigh,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic ? 'اللغة الحالية: العربية' : 'Current: English',
                            style: const TextStyle(
                              color: AxisColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildLanguageOptionButton(
                        title: 'English',
                        isSelected: !isArabic,
                        onTap: () => LocaleService().setLocale(const Locale('en')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildLanguageOptionButton(
                        title: 'العربية',
                        isSelected: isArabic,
                        onTap: () => LocaleService().setLocale(const Locale('ar')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOptionButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(
            color: isSelected
                ? AxisColors.primary.withValues(alpha: 0.2)
                : AxisColors.surfaceLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AxisColors.primary : AxisColors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check_circle_rounded, color: AxisColors.primarySoft, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AxisColors.textHigh : AxisColors.textMuted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionActionButton(bool isGuest) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isGuest ? () => context.go('/auth') : _confirmSignOut,
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
                  isGuest ? 'Sign In / Connect Cloud Account' : 'Sign Out',
                  style: TextStyle(
                    color: isGuest ? AxisColors.primary : AxisColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = AuthService();
    final isGuest = auth.isGuest;

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      appBar: AppBar(
        backgroundColor: AxisColors.canvasBase.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AxisColors.textHigh,
            size: 19,
          ),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/today');
            }
          },
        ),
        title: Text(
          l10n.me.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: AxisColors.textHigh,
          ),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: NetworkService().isOnlineNotifier,
            builder: (context, isOnline, _) {
              return IconButton(
                icon: Icon(
                  isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: isOnline ? AxisColors.tertiary : AxisColors.warning,
                  size: 20,
                ),
                tooltip: 'Sync Status',
                onPressed: () => SyncStatusModal.show(context),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AxisColors.borderSubtle, height: 1),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isGuest) ...[
                _buildGuestModeBanner(),
                const SizedBox(height: 16),
              ] else ...[
                _buildAccountCloudCard(auth),
                const SizedBox(height: 16),
              ],

              // User Profile Card with Edit Action & Avatar Picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: UserProfileCard(
                  userName: _userName,
                  userTitle: _userTitle,
                  level: _level,
                  totalXp: _totalXp,
                  friendCode: _friendCode,
                  avatarUrl: _avatarUrl,
                  avatarColor: _avatarColor,
                  isUploadingAvatar: _isUploadingAvatar,
                  onAvatarTap: _openAvatarPicker,
                  onSaveProfile: _saveProfile,
                ),
              ),

              const SizedBox(height: 24),

              // Dynamic Mastery Badges Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: MasteryBadgesSection(),
              ),

              const SizedBox(height: 24),

              // Habit Categories Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HabitCategoriesSection(
                  categories: _habitCategories,
                  onAddCategory: _addCategory,
                  onDeleteCategory: _deleteCategory,
                ),
              ),

              const SizedBox(height: 24),

              // Note Categories Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: NoteCategoriesSection(
                  categories: _noteCategories,
                  onAddCategory: _addNoteCategory,
                  onDeleteCategory: _deleteNoteCategory,
                ),
              ),

              const SizedBox(height: 24),

              // Task Tags Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TaskTagsSection(
                  taskTags: _taskTags,
                  onAddTag: _addTag,
                  onDeleteTag: _deleteTag,
                ),
              ),

              const SizedBox(height: 24),

              // App Language Selector
              _buildLanguageSection(),

              const SizedBox(height: 32),

              // Streamlined, Premium Cyber Sign Out or Sign In Button at Bottom
              _buildSessionActionButton(isGuest),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
