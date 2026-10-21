import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/powersync_db.dart' show resetAllData;
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/ui/me/widgets/user_profile_card.dart';
import 'package:axis/ui/me/widgets/habit_categories_section.dart';
import 'package:axis/ui/me/widgets/task_tags_section.dart';
import 'package:axis/ui/me/widgets/me_sections.dart';

export 'package:axis/ui/me/widgets/user_profile_card.dart';
export 'package:axis/ui/me/widgets/habit_categories_section.dart';
export 'package:axis/ui/me/widgets/task_tags_section.dart';
export 'package:axis/ui/me/widgets/me_sections.dart';

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

  List<Map<String, dynamic>> _habitCategories = [];
  List<String> _taskTags = [];

  @override
  void initState() {
    super.initState();
    _loadAllUserData();
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
      final auth = AuthService();
      if (auth.hasActiveSession) {
        final name = auth.displayName;
        final email = auth.userEmail ?? '';
        if (mounted) {
          setState(() {
            _userName = name;
            _userTitle = email;
          });
        }
      } else {
        final profile = await UserProfileRepository().getProfile();
        if (mounted) {
          setState(() {
            _userName = profile.name;
            _userTitle = profile.title;
          });
        }
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

  void _confirmResetData() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text('Reset All App Data?',
            style: TextStyle(color: AxisColors.textHigh)),
        content: const Text(
          'This will delete all tasks, projects, notes, habits, focus sessions, and logs so you can start with a completely fresh user account.',
          style: TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await resetAllData();
              if (!mounted) return;
              setState(() {
                _totalXp = 0;
                _level = 1;
                _userName = 'Cyber Kinetic';
                _userTitle = 'System Operative';
              });
              await _loadAllUserData();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('App data and account reset successfully!'),
                  backgroundColor: AxisColors.success,
                ),
              );
            },
            child: const Text('Reset App',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text('Sign Out of Account?',
            style: TextStyle(color: AxisColors.textHigh)),
        content: const Text(
          'Signing out will disconnect sync and clear local offline data from this device. All your tasks, habits, and notes remain securely saved in your Supabase account and will re-sync upon sign in.',
          style: TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService().signOut();
              } catch (_) {}
              if (!mounted) return;
              context.go('/auth');
            },
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.white)),
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

          // User Profile Card with Edit Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UserProfileCard(
              userName: _userName,
              userTitle: _userTitle,
              level: _level,
              totalXp: _totalXp,
              onSaveProfile: _saveProfile,
            ),
          ),

          const SizedBox(height: 12),

          // Authenticated Cloud Account Badge & Sign Out Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AxisColors.tertiary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: AxisColors.tertiary, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthService().userEmail ?? 'Local Offline Mode',
                          style: const TextStyle(
                            color: AxisColors.textHigh,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (AuthService().currentUserId != null && AuthService().currentUserId!.isNotEmpty)
                              ? 'ID: ${AuthService().currentUserId!.substring(0, AuthService().currentUserId!.length >= 8 ? 8 : AuthService().currentUserId!.length)}... • PowerSync Multi-Tenant'
                              : 'Connect Supabase Auth to sync',
                          style: const TextStyle(
                            color: AxisColors.textDim,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _confirmSignOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AxisColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AxisColors.error.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout_rounded, color: AxisColors.error, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              color: AxisColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

          // Mastery Badges Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: MasteryBadgesSection(),
          ),

          const SizedBox(height: 24),

          // Data Management Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DataManagementSection(
              onResetData: _confirmResetData,
            ),
          ),

          const SizedBox(height: 12),

          // About Axis App Branding Card
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AxisBrandingCard(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
