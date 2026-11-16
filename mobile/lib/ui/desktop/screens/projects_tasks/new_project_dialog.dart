import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/project_repository.dart';
import '../../../../domain/id_generator.dart';
import '../../../common/cyber_color_picker.dart';
import '../../widgets/accent_button.dart';

/// Modal dialog for creating a new project with color customization.
class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const NewProjectDialog(),
    );
  }

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  late final TextEditingController _nameController;
  String _selectedColor = '#6366F1';
  static const List<String> _presetColors = [
    '#6366F1',
    '#0EA5E9',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#EC4899',
    '#8B5CF6',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AxisColors.canvasBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AxisColors.borderGlass2, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isArabic ? 'إنشاء مشروع جديد' : 'Create New Project',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AxisColors.textHigh,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
              decoration: InputDecoration(
                hintText: isArabic ? 'مثال: مركز التحكم v2' : 'e.g. Axis Command Center v2',
                hintStyle: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceLowest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'لون المشروع' : 'PROJECT COLOR',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AxisColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ..._presetColors.map((hex) {
                  final isSel = _selectedColor.toLowerCase() == hex.toLowerCase();
                  final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
                if (!_presetColors.any((c) => c.toLowerCase() == _selectedColor.toLowerCase()))
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    decoration: BoxDecoration(
                      color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                RainbowColorPickerButton(
                  selectedColor: _selectedColor,
                  size: 26,
                  onColorSelected: (newHex) {
                    setState(() => _selectedColor = newHex);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    isArabic ? 'إلغاء' : 'Cancel',
                    style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                AccentButton(
                  label: isArabic ? 'إنشاء المشروع' : 'Create Project',
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (name.isNotEmpty) {
                      final proj = Project(
                        id: IdGenerator.generateDeterministicId('proj_${DateTime.now().microsecondsSinceEpoch}'),
                        name: name,
                        color: _selectedColor,
                      );
                      await ProjectRepository().addProject(proj);
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

