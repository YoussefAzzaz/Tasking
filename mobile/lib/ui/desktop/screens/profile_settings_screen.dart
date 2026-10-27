import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../data/auth_service.dart';
import '../../../data/habit_category_repository.dart';
import '../../../data/tag_repository.dart';
import '../../../data/user_profile_repository.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_pressable.dart';
import '../widgets/ghost_button.dart';
import '../widgets/section_header.dart';
import '../widgets/telemetry_chip.dart';

/// Profile & Settings Screen (Tab 5) — Identity, customization, habit categories, and tags.
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _callsignController = TextEditingController(text: 'KAI // OPERATOR');
  final _newCategoryController = TextEditingController();
  final _newTagController = TextEditingController();
  String _selectedCatColor = '#6366F1';
  bool _isSaving = false;

  final _palette = ['#6366F1', '#38BDF8', '#10B981', '#F59E0B', '#EF4444'];

  @override
  void initState() {
    super.initState();
    final profile = UserProfileRepository().profileNotifier.value;
    _nameController.text = profile.name.isNotEmpty ? profile.name : 'Commander';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _callsignController.dispose();
    _newCategoryController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    setState(() => _isSaving = true);
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await UserProfileRepository().saveProfile(name, 'Specialist');
    }
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operator profile synchronized successfully')),
      );
    }
  }

  Future<void> _handleAddCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    await HabitCategoryRepository().addCategory(name: name, color: _selectedCatColor);
    _newCategoryController.clear();
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
                    _buildOperatorIdentityCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildStationSecurityCard(),
                  ],
                ),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GhostButton(
              label: '⏻ Log Out',
              color: AxisColors.priorityHigh,
              borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
              onPressed: () => AuthService().signOut(),
            ),
            const SizedBox(width: 10),
            AccentButton(
              label: '💾 Save Changes',
              isLoading: _isSaving,
              onPressed: _handleSaveProfile,
            ),
          ],
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

  Widget _buildStationSecurityCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'STATION SECURITY & RUNTIME',
            trailing: TelemetryChip(
              label: 'ENCRYPTED',
              icon: Icons.lock_outline_rounded,
              color: AxisColors.tertiary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: Column(
              children: [
                _buildInfoRow('Local Engine', 'SQLite + PowerSync 2.4.0'),
                const Divider(height: 16, color: AxisColors.borderSubtle),
                _buildInfoRow('Client Build', 'Axis Desktop v2.4.0 (Windows Native)'),
                const Divider(height: 16, color: AxisColors.borderSubtle),
                _buildInfoRow('Security Vault', 'Local SQLite database encrypted with standard keys'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GhostButton(
            label: 'Sign Out Station Session',
            icon: Icons.logout_rounded,
            isFullWidth: true,
            color: AxisColors.priorityHigh,
            borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
            onPressed: () => AuthService().signOut(),
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
                    controller: _newCategoryController,
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: 'New category title...',
                      hintStyle: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Color pickers
              ..._palette.map((hex) {
                final isSelected = _selectedCatColor == hex;
                final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                return DesktopPressable(
                  selected: isSelected,
                  label: 'Color $hex',
                  onActivate: () => setState(() => _selectedCatColor = hex),
                  builder: (context, visuals) {
                    return Container(
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
                        boxShadow: desktopFocusRing(visuals.focused),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(width: 8),
              AccentButton(
                label: '+ Add',
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: _handleAddCategory,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category list
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

              return Column(
                children: categories.map((cat) {
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
                              decoration: const BoxDecoration(
                                color: AxisColors.secondary,
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
                          tooltip: 'Delete category',
                          onPressed: () async {
                            final confirmed = await ConfirmDialog.show(
                              context,
                              title: 'Delete category?',
                              message:
                                  '"${cat.name}" will be removed. Habits in this category will be unlinked, but the habits themselves are not deleted.',
                            );
                            if (!confirmed) return;
                            await HabitCategoryRepository().deleteCategory(cat.id, name: cat.name);
                          },
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
                      border: InputBorder.none,
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
                        DesktopPressable(
                          label: 'Remove tag #$t',
                          tooltip: 'Remove tag #$t',
                          onActivate: () async {
                            final confirmed = await ConfirmDialog.show(
                              context,
                              title: 'Remove tag?',
                              message:
                                  '#$t will be removed from every task that uses it. This cannot be undone.',
                            );
                            if (!confirmed) return;
                            await TagRepository().deleteTag(t);
                          },
                          builder: (context, visuals) {
                            final active = visuals.hovered || visuals.pressed;
                            return Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: active ? AxisColors.textHigh : AxisColors.textDim,
                              ),
                            );
                          },
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
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textHigh),
          ),
        ),
      ],
    );
  }
}
