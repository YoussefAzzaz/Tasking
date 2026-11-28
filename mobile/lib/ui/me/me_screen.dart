import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/ui/me/widgets/user_profile_card.dart';
import 'package:axis/ui/me/widgets/habit_categories_section.dart';
import 'package:axis/ui/me/widgets/note_categories_section.dart';
import 'package:axis/ui/me/widgets/task_tags_section.dart';
import 'package:axis/ui/me/widgets/me_sections.dart';
import 'package:axis/ui/me/widgets/me_account_section.dart';
import 'package:axis/ui/me/widgets/me_language_section.dart';
import 'package:axis/ui/me/widgets/me_avatar_service.dart';
import 'package:axis/ui/me/widgets/me_adhan_settings_card.dart';
import 'package:axis/ui/me/widgets/me_update_section.dart';
import 'package:axis/core/l10n/app_localizations.dart';

export 'package:axis/ui/me/widgets/user_profile_card.dart';
export 'package:axis/ui/me/widgets/habit_categories_section.dart';
export 'package:axis/ui/me/widgets/note_categories_section.dart';
export 'package:axis/ui/me/widgets/task_tags_section.dart';
export 'package:axis/ui/me/widgets/me_sections.dart';
export 'package:axis/ui/me/mastery_badges_screen.dart';
export 'package:axis/ui/me/widgets/avatar_widget.dart';
export 'package:axis/ui/me/widgets/profile_avatar_picker.dart';
export 'package:axis/ui/me/widgets/image_crop_dialog.dart';
export 'package:axis/ui/me/widgets/me_account_section.dart';
export 'package:axis/ui/me/widgets/me_language_section.dart';
export 'package:axis/ui/me/widgets/me_avatar_service.dart';
export 'package:axis/ui/me/widgets/me_adhan_settings_card.dart';

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
    MeAvatarService.openAvatarPicker(
      context: context,
      hasCustomAvatar: _avatarUrl != null && _avatarUrl!.isNotEmpty,
      onLoadingChanged: (uploading) {
        if (mounted) setState(() => _isUploadingAvatar = uploading);
      },
      onAvatarUpdated: (newUrl) {
        if (mounted) setState(() => _avatarUrl = newUrl);
      },
    );
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
          // Root cause: arrow_back_ios_new_rounded auto-mirrors in RTL; manual ternary caused double-flip.
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AxisColors.textHigh,
            size: 19,
          ),
          tooltip: l10n.isArabic ? 'رجوع' : 'Back',
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
          style: AxisFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: l10n.isArabic ? 0.0 : 2.0,
            color: AxisColors.textHigh,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Tooltip(
              message: isGuest
                  ? (l10n.isArabic ? 'تسجيل الدخول' : 'Sign In')
                  : (l10n.isArabic ? 'تسجيل الخروج' : 'Sign Out'),
              child: InkWell(
                key: const ValueKey('me_top_sign_out_button'),
                onTap: isGuest
                    ? () => context.go('/auth')
                    : () => showMeConfirmSignOutDialog(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isGuest ? AxisColors.primary : AxisColors.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isGuest ? AxisColors.primary : AxisColors.error)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGuest ? Icons.login_rounded : Icons.logout_rounded,
                        color: isGuest ? AxisColors.primarySoft : AxisColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isGuest
                            ? (l10n.isArabic ? 'دخول' : 'Sign In')
                            : (l10n.isArabic ? 'خروج' : 'Sign Out'),
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isGuest ? AxisColors.primarySoft : AxisColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

              const SizedBox(height: 16),

              // Connected Cloud Account / Guest check card placed directly under Profile
              if (isGuest) ...[
                MeGuestBanner(
                  onExitGuest: () => showMeConfirmExitGuestModeDialog(context),
                ),
              ] else ...[
                MeCloudAccountCard(auth: auth),
              ],

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

              // Adhan & Prayer Notification Configuration Card
              const MeAdhanSettingsCard(),

              const SizedBox(height: 24),

              // App Language Selector
              const MeLanguageSection(),

              const SizedBox(height: 24),

              // System Version & Updates Section
              const MeUpdateSection(),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
