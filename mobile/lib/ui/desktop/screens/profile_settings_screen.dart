import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_service.dart';
import '../../../data/auth_service.dart';
import '../../../data/habit_category_repository.dart';
import '../../../data/note_category_repository.dart';
import '../../../data/reading_preferences_service.dart';
import '../../../data/tag_repository.dart';
import '../../../data/user_profile_repository.dart';
import '../../../data/mastery_badge_repository.dart';
import '../../me/mastery_badges_screen.dart';
import '../../common/cyber_color_picker.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/ghost_button.dart';
import '../widgets/section_header.dart';
import '../widgets/telemetry_chip.dart';

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
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operator profile synchronized successfully')),
      );
    }
  }

  Future<void> _pickDesktopAvatar() async {
    if (AuthService().currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to upload your avatar to cloud storage.'),
          backgroundColor: AxisColors.warning,
        ),
      );
      return;
    }

    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select Profile Picture',
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
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: AxisColors.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload picture: $e'),
            backgroundColor: AxisColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeDesktopAvatar() async {
    try {
      setState(() => _isUploadingAvatar = true);
      await UserProfileRepository().removeAvatar();
      if (mounted) {
        setState(() {
          _avatarUrlController.clear();
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

  void _openMasteryBadgesModal() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Container(
          width: 960,
          height: 720,
          decoration: BoxDecoration(
            color: AxisColors.canvasBase,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AxisColors.borderGlass2, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AxisColors.borderSubtle)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: AxisColors.secondary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'MASTER OPERATOR TROPHY ROOM & BADGES',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AxisColors.textHigh,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: MasteryBadgesScreen(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                    _buildOperatorIdentityCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildLanguagePreferencesCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildReadingPreferencesCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildMasteryBadgesCard(),
                  ],
                ),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildNoteCategoriesCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildHabitCategoriesCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildTaskTagsCard(),
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
                'SETTINGS / OPERATOR PROFILE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Account & Customization',
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
                'Manage operator credentials, database synchronization, and entity labels',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AccentButton(
          label: 'Save Changes',
          icon: Icons.save_rounded,
          isLoading: _isSaving,
          onPressed: _handleSaveProfile,
        ),
      ],
    );
  }

  Widget _buildOperatorIdentityCard() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository().profileNotifier,
      builder: (context, profile, _) {
        final email = AuthService().currentUser?.email ?? 'station.local@axis.node';

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'OPERATOR IDENTITY',
                trailing: TelemetryChip(
                  label: 'VERIFIED',
                  dotColor: AxisColors.tertiary,
                  color: AxisColors.tertiary,
                ),
              ),
              const SizedBox(height: 12),

              // Avatar Section
              _buildFieldLabel('AVATAR PHOTO & IDENTITY PICTURE'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: AxisColors.secondary, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.secondary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                          ? Image.network(
                              profile.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.person_rounded, size: 28, color: AxisColors.textHigh),
                            )
                          : const Icon(Icons.person_rounded, size: 28, color: AxisColors.textHigh),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GhostButton(
                              label: _isUploadingAvatar ? 'Uploading...' : 'Choose Picture',
                              icon: Icons.upload_file_rounded,
                              height: 36,
                              onPressed: _isUploadingAvatar ? null : _pickDesktopAvatar,
                            ),
                            if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GhostButton(
                                label: 'Remove',
                                icon: Icons.delete_outline_rounded,
                                height: 36,
                                color: AxisColors.error,
                                onPressed: _removeDesktopAvatar,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Upload JPG, PNG, or WebP. Automatically synced to cloud and mobile.',
                          style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFieldLabel('OR AVATAR IMAGE URL'),
              const SizedBox(height: 6),
              _buildTextInput(_avatarUrlController, 'https://example.com/avatar.jpg'),
              const SizedBox(height: 14),

              // Display Name
              _buildFieldLabel('DISPLAY NAME'),
              const SizedBox(height: 6),
              _buildTextInput(_nameController, 'Enter operator name'),

              const SizedBox(height: 14),

              // Call-Sign / Tag
              _buildFieldLabel('CALL-SIGN / IDENTIFIER'),
              const SizedBox(height: 6),
              _buildTextInput(_callsignController, 'Enter callsign'),

              const SizedBox(height: 14),

              // Primary Station Email
              _buildFieldLabel('PRIMARY STATION EMAIL'),
              const SizedBox(height: 6),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Text(
                  email,
                  style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AxisColors.textDim),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguagePreferencesCard() {
    final l10n = AppLocalizations.of(context);
    final localeService = LocaleService();

    return ValueListenableBuilder<Locale>(
      valueListenable: localeService.localeNotifier,
      builder: (context, currentLocale, _) {
        final isArabic = currentLocale.languageCode == 'ar';
        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: l10n.language.toUpperCase(),
                subtitle: l10n.selectLanguage,
                trailing: TelemetryChip(
                  label: isArabic ? 'العربية (RTL)' : 'ENGLISH (LTR)',
                  color: AxisColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => localeService.setLocale(const Locale('en')),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: !isArabic
                              ? AxisColors.primary.withValues(alpha: 0.18)
                              : AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: !isArabic ? AxisColors.primary : AxisColors.borderSubtle,
                            width: !isArabic ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isArabic) ...[
                              const Icon(Icons.check_circle_rounded, color: AxisColors.primarySoft, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                'English (US)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: !isArabic ? FontWeight.w700 : FontWeight.w500,
                                  color: !isArabic ? AxisColors.textHigh : AxisColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => localeService.setLocale(const Locale('ar')),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isArabic
                              ? AxisColors.primary.withValues(alpha: 0.18)
                              : AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isArabic ? AxisColors.primary : AxisColors.borderSubtle,
                            width: isArabic ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isArabic) ...[
                              const Icon(Icons.check_circle_rounded, color: AxisColors.primarySoft, size: 16),
                              const SizedBox(width: 6),
                            ],
                            const Flexible(
                              child: Text(
                                'العربية (Arabic)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadingPreferencesCard() {
    final readingPref = ReadingPreferencesService();

    return ValueListenableBuilder<double>(
      valueListenable: readingPref.fontScaleNotifier,
      builder: (context, scale, _) {
        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'READING PREFERENCES',
                subtitle: 'Scale reading text for task context, notes, and journals',
                trailing: TelemetryChip(
                  label: readingPref.formattedPercentage,
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GhostButton(
                        label: 'A-',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: readingPref.canDecrease ? readingPref.decreaseScale : null,
                      ),
                      const SizedBox(width: 6),
                      GhostButton(
                        label: 'Reset',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed: readingPref.resetScale,
                      ),
                      const SizedBox(width: 6),
                      GhostButton(
                        label: 'A+',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: readingPref.canIncrease ? readingPref.increaseScale : null,
                      ),
                    ],
                  ),
                  Text(
                    'Step ${readingPref.currentStepIndex + 1} of ${ReadingPreferencesService.scaleSteps.length}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live preview sample
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREVIEW SAMPLE',
                      style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700, color: AxisColors.textDim),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deep focus and architecture clarity come from uninterrupted execution.',
                      style: GoogleFonts.getFont(
                        'Geist',
                        fontSize: 13 * scale,
                        height: 1.5,
                        color: AxisColors.textHigh,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMasteryBadgesCard() {
    return FutureBuilder<List<MasteryBadgeData>>(
      future: MasteryBadgeRepository().getMasteryBadges(),
      builder: (context, snapshot) {
        final badges = snapshot.data ?? [];
        final unlocked = badges.where((b) => b.isUnlocked).length;
        final total = badges.isNotEmpty ? badges.length : 50;

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'OPERATOR MASTERY BADGES',
                subtitle: '50 tiered operational milestones across routines and deliverables',
                trailing: TelemetryChip(
                  label: '$unlocked / $total UNLOCKED',
                  dotColor: AxisColors.warning,
                  color: AxisColors.warning,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.military_tech_rounded, size: 24, color: AxisColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TROPHY SHOWROOM',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AxisColors.textHigh,
                                  ),
                                ),
                                Text(
                                  'Explore tier badges for habits, deep focus, prayer consistency & tasks',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AccentButton(
                    label: 'Open Badges ↗',
                    height: 38,
                    onPressed: _openMasteryBadgesModal,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildNoteCategoriesCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Note Categories',
            subtitle: 'Classify research, engineering notes, and journals',
          ),
          const SizedBox(height: 10),

          // Add note category form
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AxisColors.borderSubtle, width: 1),
                  ),
                  child: TextField(
                    controller: _newNoteCatController,
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: 'New note category...',
                      hintStyle: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Color pickers
              ..._palette.take(5).map((hex) {
                final isSelected = _selectedNoteCatColor == hex;
                final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => setState(() => _selectedNoteCatColor = hex),
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              RainbowColorPickerButton(
                selectedColor: _selectedNoteCatColor,
                size: 24,
                onColorSelected: (newHex) => setState(() => _selectedNoteCatColor = newHex),
              ),
              const SizedBox(width: 8),
              AccentButton(
                label: '+ Add',
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: _handleAddNoteCategory,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Note categories list (scrollable widget constrained to prevent page expansion)
          StreamBuilder<List<NoteCategory>>(
            stream: NoteCategoryRepository().watchCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              if (categories.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'No custom note categories created yet',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    Color catColor = AxisColors.secondary;
                    try {
                      catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
                    } catch (_) {}

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AxisColors.borderSubtle, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                cat.name,
                                style: GoogleFonts.getFont(
                                  'Geist',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            color: AxisColors.textDim,
                            onPressed: () => NoteCategoryRepository().deleteCategory(cat.id, name: cat.name),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCategoriesCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Habit Categories',
            subtitle: 'Organize routines into clustered life domains',
          ),
          const SizedBox(height: 10),

          // Add category form
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AxisColors.borderSubtle, width: 1),
                  ),
                  child: TextField(
                    controller: _newHabitCatController,
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: 'New habit category title...',
                      hintStyle: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Color pickers
              ..._palette.take(5).map((hex) {
                final isSelected = _selectedHabitCatColor == hex;
                final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => setState(() => _selectedHabitCatColor = hex),
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              RainbowColorPickerButton(
                selectedColor: _selectedHabitCatColor,
                size: 24,
                onColorSelected: (newHex) => setState(() => _selectedHabitCatColor = newHex),
              ),
              const SizedBox(width: 8),
              AccentButton(
                label: '+ Add',
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: _handleAddHabitCategory,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category list (scrollable widget constrained to prevent page expansion)
          StreamBuilder<List<HabitCategory>>(
            stream: HabitCategoryRepository().watchCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              if (categories.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'No custom categories created yet',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    Color catColor = AxisColors.secondary;
                    try {
                      catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
                    } catch (_) {}

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AxisColors.borderSubtle, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                cat.name,
                                style: GoogleFonts.getFont(
                                  'Geist',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            color: AxisColors.textDim,
                            onPressed: () => HabitCategoryRepository().deleteCategory(cat.id, name: cat.name),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTagsCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Task Tags & Labels',
            subtitle: 'Global tagging taxonomy applied across deliverables',
          ),
          const SizedBox(height: 10),

          // Add tag form
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AxisColors.borderSubtle, width: 1),
                  ),
                  child: TextField(
                    controller: _newTagController,
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: '#NEW-IDENTIFIER...',
                      hintStyle: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AccentButton(
                label: '+ Create Tag',
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: _handleAddTag,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tags chips flow
          StreamBuilder<List<String>>(
            stream: TagRepository().watchTags(),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? [];
              if (tags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'No tags defined. Add one above.',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AxisColors.borderSubtle, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$t',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AxisColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => TagRepository().deleteTag(t),
                          child: const Icon(Icons.close_rounded, size: 13, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AxisColors.textMuted,
      ),
    );
  }

  Widget _buildTextInput(TextEditingController controller, String hint) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AxisColors.borderSubtle, width: 1),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
          filled: false,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

}
