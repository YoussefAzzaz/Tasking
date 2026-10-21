import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/ui/me/widgets/user_profile_card.dart';
import 'package:axis/ui/me/widgets/habit_categories_section.dart';
import 'package:axis/ui/me/widgets/task_tags_section.dart';
import 'package:axis/ui/me/widgets/me_sections.dart';
import 'package:axis/ui/me/widgets/profile_avatar_picker.dart';
import 'package:axis/ui/me/widgets/image_crop_dialog.dart';

export 'package:axis/ui/me/widgets/user_profile_card.dart';
export 'package:axis/ui/me/widgets/habit_categories_section.dart';
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
  bool _isUploadingAvatar = false;

  List<Map<String, dynamic>> _habitCategories = [];
  List<String> _taskTags = [];
  StreamSubscription<List<HabitCategory>>? _categoriesSub;
  StreamSubscription<List<String>>? _tagsSub;

  @override
  void initState() {
    super.initState();
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
    _tagsSub = TagRepository().watchTags().listen((tags) {
      if (mounted) {
        setState(() {
          _taskTags = tags;
        });
      }
    });
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _tagsSub?.cancel();
    super.dispose();
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
          if (auth.hasActiveSession && auth.displayName.isNotEmpty) {
            _userName = auth.displayName;
            _userTitle = auth.userEmail ?? profile.title;
          } else {
            _userName = profile.name;
            _userTitle = profile.title;
          }
          _avatarUrl = profile.avatarUrl;
          _avatarColor = profile.avatarColor;
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

  Future<void> _saveProfile(String newName, String newTitle) async {
    setState(() {
      _userName = newName;
      _userTitle = newTitle;
    });
    await UserProfileRepository().saveProfile(newName, newTitle);
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
          style: TextStyle(color: AxisColors.textHigh),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // User Profile Card with Edit Action & Avatar Picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UserProfileCard(
              userName: _userName,
              userTitle: _userTitle,
              level: _level,
              totalXp: _totalXp,
              avatarUrl: _avatarUrl,
              avatarColor: _avatarColor,
              isUploadingAvatar: _isUploadingAvatar,
              onAvatarTap: _openAvatarPicker,
              onSaveProfile: _saveProfile,
            ),
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

          // Dynamic Mastery Badges Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: MasteryBadgesSection(),
          ),

          const SizedBox(height: 32),

          // Streamlined, Premium Cyber-Crimson Sign Out Button at Bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _confirmSignOut,
                splashColor: AxisColors.error.withValues(alpha: 0.2),
                highlightColor: AxisColors.error.withValues(alpha: 0.1),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AxisColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AxisColors.error.withValues(alpha: 0.28),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AxisColors.error.withValues(alpha: 0.06),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: AxisColors.error,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          color: AxisColors.error,
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
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
