import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';

class CreateProjectSheet extends StatefulWidget {
  const CreateProjectSheet({super.key, required this.onProjectCreated});
  final VoidCallback onProjectCreated;

  @override
  State<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<CreateProjectSheet> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  String _selectedColor = '#6366F1';
  bool _saving = false;
  String? _errorText;

  static const _palette = [
    {'name': 'Indigo', 'hex': '#6366F1', 'color': AxisColors.primary},
    {'name': 'Cyan', 'hex': '#0EA5E9', 'color': AxisColors.secondary},
    {'name': 'Emerald', 'hex': '#10B981', 'color': AxisColors.success},
    {'name': 'Amber', 'hex': '#F59E0B', 'color': AxisColors.warning},
    {'name': 'Rose', 'hex': '#EC4899', 'color': Color(0xFFEC4899)},
    {'name': 'Purple', 'hex': '#8B5CF6', 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Color _parseHex(String hex) {
    final clean = hex.replaceAll('#', '').replaceAll('0x', '').trim();
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    return AxisColors.primary;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = context.isArabic ? 'لا يمكن أن يكون اسم المشروع فارغاً' : 'Project name cannot be empty');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final project = Project(
      id: IdGenerator.generateDeterministicId(
          'proj_${DateTime.now().microsecondsSinceEpoch}_$name'),
      name: name,
      color: _selectedColor,
    );

    await ProjectRepository().addProject(project);

    if (mounted) {
      Navigator.pop(context);
      widget.onProjectCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return FocusScope(
      autofocus: false,
      child: ModalSheetScaffold(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: const Color(0xF50D1524),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle & Header (tap to close automatically)
                ModalSheetTopBar(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AxisColors.borderGlass2,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _parseHex(_selectedColor).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.folder_special_rounded,
                                        color: _parseHex(_selectedColor), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.isArabic ? 'إنشاء مشروع جديد' : 'CREATE NEW PROJECT',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AxisColors.textHigh,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AxisColors.textMuted, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: AxisColors.borderSubtle, height: 1),

                // Scrollable Form fields
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.isArabic ? 'اسم المشروع *' : 'PROJECT NAME *',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AutoDirectionScope(
                          controller: _nameController,
                          child: TextField(
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            autofocus: false,
                            style: const TextStyle(
                              color: AxisColors.textHigh,
                              fontWeight: FontWeight.w500,
                            ),
                            cursorColor: _parseHex(_selectedColor),
                            decoration: InputDecoration(
                              hintText: context.isArabic ? 'مثال: إعادة تصميم تطبيق الجوال، أهداف الربع الرابع' : 'e.g., Mobile App Redesign, Q4 Goals',
                              hintStyle: const TextStyle(color: AxisColors.textDim),
                              errorText: _errorText,
                              filled: true,
                              fillColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AxisColors.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _parseHex(_selectedColor),
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Color Picker Palette
                        Text(
                          context.isArabic ? 'لون السمة' : 'THEME COLOR',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              ..._palette.map((item) {
                                final hex = item['hex'] as String;
                                final color = item['color'] as Color;
                                final isSelected = _selectedColor.toUpperCase() == hex.toUpperCase();

                                return Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 12),
                                  child: InkWell(
                                    onTap: () => setState(() => _selectedColor = hex),
                                    borderRadius: BorderRadius.circular(20),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: isSelected ? 0.35 : 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? color : AxisColors.borderSubtle,
                                          width: isSelected ? 2.5 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.4),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: isSelected
                                          ? Icon(Icons.check_rounded, color: color, size: 20)
                                          : null,
                                    ),
                                  ),
                                );
                              }),
                              // If user picked a custom color not in presets, display it as selected
                              if (!_palette.any((p) => (p['hex'] as String).toUpperCase() == _selectedColor.toUpperCase())) ...[
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: _parseHex(_selectedColor).withValues(alpha: 0.35),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _parseHex(_selectedColor),
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _parseHex(_selectedColor).withValues(alpha: 0.4),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.check_rounded, color: _parseHex(_selectedColor), size: 20),
                                  ),
                                ),
                              ],
                              // Rainbow custom color picker button
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 8),
                                child: RainbowColorPickerButton(
                                  selectedColor: _selectedColor,
                                  size: 42,
                                  onColorSelected: (newHex) {
                                    setState(() => _selectedColor = newHex);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Create Action Button
                        InkWell(
                          onTap: _saving ? null : _save,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _parseHex(_selectedColor),
                                  _parseHex(_selectedColor).withValues(alpha: 0.75),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _parseHex(_selectedColor).withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Center(
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_rounded,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          context.isArabic ? 'إنشاء مشروع' : 'CREATE PROJECT',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
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
      ),
    ),
  );
}
}
