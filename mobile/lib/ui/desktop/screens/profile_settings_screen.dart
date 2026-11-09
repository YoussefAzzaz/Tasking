import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/auth_service.dart';
import '../../../data/habit_category_repository.dart';
import '../../../data/note_category_repository.dart';
import '../../../data/tag_repository.dart';
import '../../../data/user_profile_repository.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import 'profile/desktop_language_card.dart';
import 'profile/desktop_reading_card.dart';
import 'profile/desktop_mastery_badges_card.dart';
import 'profile/desktop_task_tags_card.dart';
import 'profile/desktop_note_categories_card.dart';
import 'profile/desktop_habit_categories_card.dart';
import 'profile/operator_identity_card.dart';

export 'profile/desktop_language_card.dart';
export 'profile/desktop_reading_card.dart';
export 'profile/desktop_mastery_badges_card.dart';
export 'profile/desktop_task_tags_card.dart';
export 'profile/desktop_note_categories_card.dart';
export 'profile/desktop_habit_categories_card.dart';
export 'profile/operator_identity_card.dart';

/// Profile & Settings Screen (Tab 5) — Identity, customization, note/habit categories, and telemetry.
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _callsignController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _newHabitCatController = TextEditingController();
  final _newNoteCatController = TextEditingController();
  final _newTagController = TextEditingController();
  String _selectedHabitCatColor = '#6366F1';
  String _selectedNoteCatColor = '#38BDF8';
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  final _palette = ['#6366F1', '#38BDF8', '#10B981', '#F59E0B', '#EF4444', '#EC4899', '#8B5CF6'];

  @override
  void initState() {
    super.initState();
    final profile = UserProfileRepository().profileNotifier.value;
    _nameController.text = profile.name.isNotEmpty && profile.name != 'Commander'
        ? profile.name
        : (AuthService().displayName.isNotEmpty && AuthService().displayName != 'Operative'
            ? AuthService().displayName
            : (profile.name.isNotEmpty ? profile.name : 'Commander'));
    _callsignController.text = profile.title.isNotEmpty ? profile.title : 'Specialist';
    _avatarUrlController.text = profile.avatarUrl ?? '';

    UserProfileRepository().profileNotifier.addListener(_onProfileUpdated);
    _loadInitialProfile();
  }

  void _onProfileUpdated() {
    if (!mounted) return;
    final p = UserProfileRepository().profileNotifier.value;
    setState(() {
      if (_nameController.text.isEmpty || _nameController.text == 'Commander') {
        _nameController.text = p.name;
      }
      if (_callsignController.text.isEmpty || _callsignController.text == 'Specialist') {
        _callsignController.text = p.title;
      }
      if (_avatarUrlController.text.isEmpty && p.avatarUrl != null) {
        _avatarUrlController.text = p.avatarUrl!;
      }
    });
  }

  Future<void> _loadInitialProfile() async {
    final p = await UserProfileRepository().getProfile();
    if (!mounted) return;
    setState(() {
      _nameController.text = p.name;
      _callsignController.text = p.title;
      _avatarUrlController.text = p.avatarUrl ?? '';
    });
  }

  @override
  void dispose() {
    UserProfileRepository().profileNotifier.removeListener(_onProfileUpdated);
    _nameController.dispose();
    _callsignController.dispose();
    _avatarUrlController.dispose();
    _newHabitCatController.dispose();
    _newNoteCatController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    setState(() => _isSaving = true);
    final name = _nameController.text.trim();
    final callsign = _callsignController.text.trim();
    final avatar = _avatarUrlController.text.trim();
    if (name.isNotEmpty) {
      await UserProfileRepository().saveProfile(
        name,
        callsign.isNotEmpty ? callsign : 'Specialist',
        avatarUrl: avatar.isNotEmpty ? avatar : null,
      );
    }
    if (mounted) {
      final isAr = AppLocalizations.of(context).isArabic;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'تمت مزامنة ملف المشغل بنجاح' : 'Operator profile synchronized successfully'),
        ),
      );
    }
  }

  Future<void> _pickDesktopAvatar() async {
    final isAr = AppLocalizations.of(context).isArabic;
    if (AuthService().currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr
              ? 'يرجى تسجيل الدخول لرفع صورتك الشخصية إلى التخزين السحابي.'
              : 'Please sign in to upload your avatar to cloud storage.'),
          backgroundColor: AxisColors.warning,
        ),
      );
      return;
    }

    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: isAr ? 'اختر الصورة الشخصية' : 'Select Profile Picture',
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isEmpty) return;

      setState(() => _isUploadingAvatar = true);

      final file = files.first;
      if (file.path == null) {
        throw Exception('Could not resolve selected file path');
      }
      final bytes = await File(file.path!).readAsBytes();

      final ext = file.extension?.toLowerCase() ?? 'png';
      final contentType = ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

      final newUrl = await UserProfileRepository().uploadAvatar(
        bytes,
        contentType: contentType,
      );

      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          if (newUrl != null) {
            _avatarUrlController.text = newUrl;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'تم تحديث الصورة الشخصية بنجاح!' : 'Profile picture updated successfully!'),
            backgroundColor: AxisColors.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'فشل رفع الصورة: $e' : 'Failed to upload picture: $e'),
            backgroundColor: AxisColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeDesktopAvatar() async {
    final isAr = AppLocalizations.of(context).isArabic;
    try {
      setState(() => _isUploadingAvatar = true);
      await UserProfileRepository().removeAvatar();
      if (mounted) {
        setState(() {
          _avatarUrlController.clear();
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'تمت إزالة الصورة الشخصية' : 'Profile picture removed'),
            backgroundColor: AxisColors.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _handleAddHabitCategory() async {
    final name = _newHabitCatController.text.trim();
    if (name.isEmpty) return;
    await HabitCategoryRepository().addCategory(name: name, color: _selectedHabitCatColor);
    _newHabitCatController.clear();
  }

  Future<void> _handleAddNoteCategory() async {
    final name = _newNoteCatController.text.trim();
    if (name.isEmpty) return;
    await NoteCategoryRepository().addCategory(name: name, color: _selectedNoteCatColor);
    _newNoteCatController.clear();
  }

  Future<void> _handleAddTag() async {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;
    await TagRepository().addTag(name);
    _newTagController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 7.2 Page Header
          _buildHeader(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // Main 2-Column Split
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    OperatorIdentityCard(
                      nameController: _nameController,
                      callsignController: _callsignController,
                      avatarUrlController: _avatarUrlController,
                      isUploadingAvatar: _isUploadingAvatar,
                      onPickAvatar: _pickDesktopAvatar,
                      onRemoveAvatar: _removeDesktopAvatar,
                    ),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    const DesktopLanguageCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    const DesktopReadingCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    const DesktopMasteryBadgesCard(),
                  ],
                ),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    DesktopNoteCategoriesCard(
                      newNoteCatController: _newNoteCatController,
                      selectedNoteCatColor: _selectedNoteCatColor,
                      palette: _palette,
                      onColorSelected: (hex) => setState(() => _selectedNoteCatColor = hex),
                      onAddNoteCategory: _handleAddNoteCategory,
                    ),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    DesktopHabitCategoriesCard(
                      newHabitCatController: _newHabitCatController,
                      selectedHabitCatColor: _selectedHabitCatColor,
                      palette: _palette,
                      onColorSelected: (hex) => setState(() => _selectedHabitCatColor = hex),
                      onAddHabitCategory: _handleAddHabitCategory,
                    ),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    DesktopTaskTagsCard(
                      newTagController: _newTagController,
                      onAddTag: _handleAddTag,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr ? 'الإعدادات / ملف المشغل' : 'SETTINGS / OPERATOR PROFILE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isAr ? 'الحساب والتخصيص' : 'Account & Customization',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isAr
                    ? 'إدارة بيانات المشغل، مزامنة قاعدة البيانات، وتصنيفات العناصر'
                    : 'Manage operator credentials, database synchronization, and entity labels',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AccentButton(
          label: isAr ? 'حفظ التغييرات' : 'Save Changes',
          icon: Icons.save_rounded,
          isLoading: _isSaving,
          onPressed: _handleSaveProfile,
        ),
      ],
    );
  }
}
