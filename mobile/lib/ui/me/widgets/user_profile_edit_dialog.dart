import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';

/// Stateful edit-profile dialog that owns and disposes its TextEditingControllers.
class UserProfileEditDialog extends StatefulWidget {
  const UserProfileEditDialog({
    super.key,
    required this.initialName,
    required this.initialTitle,
    required this.initialColor,
    required this.onSave,
  });

  final String initialName;
  final String initialTitle;
  final String initialColor;
  final void Function(String name, String title, String color) onSave;

  @override
  State<UserProfileEditDialog> createState() => _UserProfileEditDialogState();
}

class _UserProfileEditDialogState extends State<UserProfileEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _titleCtrl;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    } catch (_) {}
    return AxisColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    const presetColors = AxisColors.presetHexes;

    return AlertDialog(
      backgroundColor: AxisColors.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AxisColors.borderPrimary),
      ),
      title: Text(
        isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile',
        style: const TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'الاسم الظاهر' : 'DISPLAY NAME',
              style: TextStyle(
                color: AxisColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: isArabic ? 0.0 : 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: false,
              style: const TextStyle(color: AxisColors.textHigh),
              decoration: InputDecoration(
                hintText: isArabic ? 'مثال: أليكس فانس' : 'e.g. Alex Vance',
                hintStyle: const TextStyle(color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'اللقب / الوصف' : 'TITLE / BIO',
              style: TextStyle(
                color: AxisColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: isArabic ? 0.0 : 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: AxisColors.textHigh),
              decoration: InputDecoration(
                hintText: isArabic
                    ? 'مثال: مهندس رئيسي، مشغل نظام'
                    : 'e.g. Lead Architect, System Operative',
                hintStyle: const TextStyle(color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic ? 'لون تمييز الصورة الرمزية' : 'AVATAR ACCENT COLOR',
              style: TextStyle(
                color: AxisColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: isArabic ? 0.0 : 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...presetColors.map((hex) {
                  final isSel = _selectedColor.toUpperCase() == hex.toUpperCase();
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = hex),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _parseHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.white : Colors.transparent,
                          width: 2.2,
                        ),
                      ),
                      child: isSel ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                    ),
                  );
                }),
                RainbowColorPickerButton(
                  selectedColor: _selectedColor,
                  size: 30,
                  borderWidth: 2,
                  onColorSelected: (col) => setState(() => _selectedColor = col),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: AxisColors.textDim)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AxisColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final newName = _nameCtrl.text.trim();
            final newTitle = _titleCtrl.text.trim();
            Navigator.pop(context);
            if (newName.isNotEmpty) {
              widget.onSave(
                newName,
                newTitle.isNotEmpty ? newTitle : 'System Operative',
                _selectedColor,
              );
            }
          },
          child: Text(
            isArabic ? 'حفظ التغييرات' : 'Save Changes',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
