import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/gamification_engine.dart';

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
      final rows = await db.getAll('SELECT name, title FROM user_profile LIMIT 1');
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
      final rows = await db.getAll('SELECT id, name, icon, color FROM habit_categories ORDER BY name ASC');
      if (mounted) {
        setState(() {
          _habitCategories = rows;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTaskTags() async {
    try {
      final tagRows = await db.getAll('SELECT name FROM tags ORDER BY name ASC');
      final taskRows = await db.getAll('SELECT tags FROM tasks WHERE tags IS NOT NULL');

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

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.primary;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.primary;
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userName);
    final titleCtrl = TextEditingController(text: _userTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text('Edit Profile',
            style: TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DISPLAY NAME',
                style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AxisColors.textHigh),
              decoration: InputDecoration(
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AxisColors.borderSubtle)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            const Text('TITLE / ROLE',
                style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: AxisColors.textHigh),
              decoration: InputDecoration(
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AxisColors.borderSubtle)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.primary),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newTitle = titleCtrl.text.trim();
              Navigator.pop(ctx);
              if (newName.isNotEmpty) {
                try {
                  await db.execute('''
                    INSERT OR REPLACE INTO user_profile (id, name, title)
                    VALUES ('current_user', ?, ?)
                  ''', [newName, newTitle.isNotEmpty ? newTitle : 'System Operative']);
                } catch (_) {}
                setState(() {
                  _userName = newName;
                  _userTitle = newTitle.isNotEmpty ? newTitle : 'System Operative';
                });
              }
            },
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final catCtrl = TextEditingController();
    String selectedColor = '#10B981';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AxisColors.surfaceLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AxisColors.borderPrimary),
          ),
          title: const Text('New Habit Category',
              style: TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CATEGORY NAME',
                  style: TextStyle(
                      color: AxisColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: catCtrl,
                autofocus: true,
                style: const TextStyle(color: AxisColors.textHigh),
                decoration: InputDecoration(
                  hintText: 'e.g. Fitness, Meditation, Study',
                  hintStyle: const TextStyle(color: AxisColors.textDim),
                  filled: true,
                  fillColor: AxisColors.surfaceHigh,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AxisColors.borderSubtle)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              const Text('COLOR ACCENT',
                  style: TextStyle(
                      color: AxisColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  '#10B981',
                  '#38BDF8',
                  '#6366F1',
                  '#F59E0B',
                  '#EC4899',
                ].map((hex) {
                  final col = _parseHex(hex);
                  final isSel = selectedColor == hex;
                  return InkWell(
                    onTap: () => setDlgState(() => selectedColor = hex),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSel
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AxisColors.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AxisColors.success),
              onPressed: () async {
                final catName = catCtrl.text.trim();
                Navigator.pop(ctx);
                if (catName.isNotEmpty) {
                  try {
                    await db.execute('''
                      INSERT OR IGNORE INTO habit_categories (id, name, icon, color)
                      VALUES (?, ?, 'category', ?)
                    ''', ['cat_${DateTime.now().microsecondsSinceEpoch}', catName, selectedColor]);
                  } catch (_) {}
                  await _loadHabitCategories();
                }
              },
              child: const Text('Create Category', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    final tagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text('New Task Tag',
            style: TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TAG NAME',
                style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: tagCtrl,
              autofocus: true,
              style: const TextStyle(color: AxisColors.textHigh),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: const TextStyle(
                    color: AxisColors.primarySoft, fontWeight: FontWeight.bold),
                hintText: 'e.g. urgent, backend, review',
                hintStyle: const TextStyle(color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AxisColors.borderSubtle)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.primary),
            onPressed: () async {
              final tagName = tagCtrl.text.trim().replaceAll('@', '');
              Navigator.pop(ctx);
              if (tagName.isNotEmpty) {
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
            },
            child: const Text('Create Tag', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String id, String name) async {
    try {
      await db.execute('DELETE FROM habit_categories WHERE id = ? OR name = ?', [id, name]);
    } catch (_) {}
    await _loadHabitCategories();
  }

  Future<void> _deleteTag(String tagName) async {
    try {
      await db.execute('DELETE FROM tags WHERE name = ?', [tagName]);
    } catch (_) {}
    await _loadTaskTags();
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
            child: AxisCard(
              tier: GlassTier.two,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AxisColors.primary, AxisColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: AxisColors.textHigh,
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _userTitle,
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
                              'Level $_level • $_totalXp XP',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                      color: AxisColors.secondary,
                                      fontWeight: FontWeight.bold),
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
                    onPressed: _showEditProfileDialog,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Habit Categories Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HABIT CATEGORIES',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AxisColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                InkWell(
                  onTap: _showAddCategoryDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AxisColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AxisColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 14, color: AxisColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Add Category',
                          style: TextStyle(
                              color: AxisColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _habitCategories.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: const Text('No custom categories. Click "+ Add Category" to create one.',
                        style: TextStyle(color: AxisColors.textMuted, fontSize: 12)),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _habitCategories.map((cat) {
                      final name = cat['name'] as String;
                      final id = cat['id'] as String;
                      final color = _parseHex(cat['color'] as String?);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: color.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: const TextStyle(
                                  color: AxisColors.textHigh,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _deleteCategory(id, name),
                              borderRadius: BorderRadius.circular(10),
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: AxisColors.textDim),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),

          // Task Tags Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TASK TAGS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AxisColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                InkWell(
                  onTap: _showAddTagDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AxisColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 14, color: AxisColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Add Tag',
                          style: TextStyle(
                              color: AxisColors.primarySoft,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _taskTags.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: const Text('No tags defined. Tap "+ Add Tag" to create tags.',
                        style: TextStyle(color: AxisColors.textMuted, fontSize: 12)),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _taskTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AxisColors.primary.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '@$tag',
                              style: const TextStyle(
                                color: AxisColors.primarySoft,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _deleteTag(tag),
                              borderRadius: BorderRadius.circular(10),
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: AxisColors.textDim),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'MASTERY BADGES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AxisColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: const [
                _Badge(
                    icon: Icons.local_fire_department_rounded,
                    color: AxisColors.success,
                    label: 'Streak'),
                _Badge(
                    icon: Icons.edit_note_rounded,
                    color: AxisColors.primary,
                    label: 'Writer'),
                _Badge(
                    icon: Icons.task_alt_rounded,
                    color: AxisColors.success,
                    label: 'Closer'),
                _Badge(
                    icon: Icons.access_time_filled_rounded,
                    color: AxisColors.secondary,
                    label: 'Focus'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'DATA MANAGEMENT',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AxisColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
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
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AxisColors.error),
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
                              content:
                                  Text('App data and account reset successfully!'),
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
              },
              child: AxisCard(
                tier: GlassTier.two,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AxisColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_sweep_rounded,
                          color: AxisColors.error, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reset App to Clean State',
                              style: TextStyle(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Wipe all local tasks, projects, habits & XP',
                              style: TextStyle(
                                  color: AxisColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: AxisColors.textDim, size: 14),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // About Axis App Branding Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AxisCard(
              tier: GlassTier.two,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'AXIS OS',
                              style: TextStyle(
                                color: AxisColors.textHigh,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AxisColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color:
                                        AxisColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'v1.0.0',
                                style: TextStyle(
                                  color: AxisColors.primarySoft,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'The Kinetic Productivity & Flow OS',
                          style: TextStyle(
                              color: AxisColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AxisColors.textMuted)),
        ],
      ),
    );
  }
}
