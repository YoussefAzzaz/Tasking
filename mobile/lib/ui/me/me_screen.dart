import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/gamification_engine.dart';
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
    await _loadUserStats();
    await _loadProfile();
    await _loadHabitCategories();
    await _loadTaskTags();
  }

  Future<void> _loadUserStats() async {
    try {
      final logRows = await db.getAll('SELECT xp_earned FROM logs');
      final focusRows = await db.getAll(
          'SELECT xp_earned FROM focus_sessions WHERE completed = 1');

      int total = 0;
      for (final r in logRows) {
        total += (r['xp_earned'] as num?)?.toInt() ?? 0;
      }
      for (final r in focusRows) {
        total += (r['xp_earned'] as num?)?.toInt() ?? 0;
      }

      final lvl = GamificationEngine.calculateLevel(total);
      if (mounted) {
        setState(() {
          _totalXp = total;
          _level = lvl;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final rows =
          await db.getAll('SELECT name, title FROM user_profile LIMIT 1');
      if (rows.isNotEmpty) {
        final r = rows.first;
        if (mounted) {
          setState(() {
            _userName = (r['name'] as String?) ?? _userName;
            _userTitle = (r['title'] as String?) ?? _userTitle;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadHabitCategories() async {
    try {
      final rows = await db.getAll(
          'SELECT id, name, icon, color FROM habit_categories ORDER BY name ASC');
      if (mounted) {
        setState(() {
          _habitCategories = rows;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTaskTags() async {
    try {
      final tagRows =
          await db.getAll('SELECT name FROM tags ORDER BY name ASC');
      final taskRows =
          await db.getAll('SELECT tags FROM tasks WHERE tags IS NOT NULL');

      final tagSet = <String>{};
      for (final r in tagRows) {
        final name = (r['name'] as String?)?.trim().replaceAll('@', '');
        if (name != null && name.isNotEmpty) tagSet.add(name);
      }
      for (final r in taskRows) {
        final tagsStr = r['tags'] as String?;
        if (tagsStr != null && tagsStr.isNotEmpty) {
          for (final t in tagsStr.split(',')) {
            final clean = t.trim().replaceAll('@', '');
            if (clean.isNotEmpty) tagSet.add(clean);
          }
        }
      }

      final list = tagSet.toList()..sort();
      if (mounted) {
        setState(() {
          _taskTags = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveProfile(String newName, String newTitle) async {
    try {
      await db.execute('''
        INSERT OR REPLACE INTO user_profile (id, name, title)
        VALUES ('singleton_profile', ?, ?)
      ''', [newName, newTitle]);
    } catch (_) {}
    setState(() {
      _userName = newName;
      _userTitle = newTitle;
    });
  }

  Future<void> _addCategory(String catName, String selectedColor) async {
    try {
      await db.execute('''
        INSERT OR IGNORE INTO habit_categories (id, name, icon, color)
        VALUES (?, ?, 'category', ?)
      ''', [
        'cat_${DateTime.now().microsecondsSinceEpoch}',
        catName,
        selectedColor
      ]);
    } catch (_) {}
    await _loadHabitCategories();
  }

  Future<void> _deleteCategory(String id, String name) async {
    try {
      await db.execute(
          'DELETE FROM habit_categories WHERE id = ? OR name = ?', [id, name]);
    } catch (_) {}
    await _loadHabitCategories();
  }

  Future<void> _addTag(String tagName) async {
    try {
      await db.execute('''
        INSERT OR IGNORE INTO tags (id, name, color, created_at)
        VALUES (?, ?, '#6366F1', ?)
      ''', [
        'tag_${DateTime.now().microsecondsSinceEpoch}',
        tagName,
        DateTime.now().toUtc().toIso8601String(),
      ]);
    } catch (_) {}
    await _loadTaskTags();
  }

  Future<void> _deleteTag(String tagName) async {
    try {
      await db.execute('DELETE FROM tags WHERE name = ?', [tagName]);
    } catch (_) {}
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
