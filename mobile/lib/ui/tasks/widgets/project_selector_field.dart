import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';

/// Autocomplete/searchable Project selector field with dynamic dropdown
class ProjectSelectorField extends StatelessWidget {
  const ProjectSelectorField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.selectedProject,
    required this.existingProjects,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onSelectProject,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? selectedProject;
  final List<Project> existingProjects;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final ValueChanged<String?> onSelectProject;
  final VoidCallback onClear;

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.primary;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.primary;
    }
  }

  List<Widget> _buildDropdownItems(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final List<Widget> items = [];

    // Inbox / Default (No Project)
    final isInboxSelected = selectedProject == null ||
        selectedProject!.isEmpty ||
        selectedProject!.toLowerCase() == 'inbox';
    items.add(
      DropdownOption(
        icon: Icons.inbox_rounded,
        iconColor: AxisColors.textDim,
        title: context.isArabic ? 'صندوق الوارد (بدون مشروع)' : 'Inbox (No Project)',
        isSelected: isInboxSelected,
        onTap: () {
          onSelectProject(null);
          onOpenChanged(false);
          focusNode.unfocus();
        },
      ),
    );

    // Filtered projects (excluding legacy defaults)
    final availableProjects = existingProjects.where((p) {
      final idLower = p.id.toLowerCase();
      return idLower != 'work' && idLower != 'personal' && idLower != 'growth';
    }).toList();

    final exactMatch = availableProjects.any(
      (p) => p.name.toLowerCase() == query,
    );
    final isInbox = query.isEmpty || query == 'inbox';

    final filtered = (isInbox || exactMatch)
        ? availableProjects
        : availableProjects
            .where((p) => p.name.toLowerCase().contains(query))
            .toList();

    if (filtered.isEmpty && query.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            context.isArabic
                ? 'لا توجد مشاريع مخصصة بعد. اكتب أعلاه للإنشاء.'
                : 'No custom projects yet. Type above to create one.',
            style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
        ),
      );
    }

    for (final proj in filtered) {
      final isSelected = selectedProject != null &&
          selectedProject!.toLowerCase() == proj.name.toLowerCase();
      final color = _parseHex(proj.color);
      items.add(
        DropdownOption(
          colorDot: color,
          title: proj.name,
          isSelected: isSelected,
          onTap: () {
            onSelectProject(proj.name);
            onOpenChanged(false);
            focusNode.unfocus();
          },
        ),
      );
    }

    // Quick-create new project if typed name doesn't match an existing project
    if (query.isNotEmpty && !exactMatch && query != 'inbox') {
      final rawTyped = controller.text.trim();
      items.add(
        DropdownOption(
          icon: Icons.add_rounded,
          iconColor: AxisColors.secondary,
          title: context.isArabic ? 'إنشاء مشروع "$rawTyped"' : 'Create project "$rawTyped"',
          isAction: true,
          onTap: () {
            onSelectProject(rawTyped);
            onOpenChanged(false);
            focusNode.unfocus();
          },
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: context.isArabic ? 'المشروع' : 'PROJECT'),
        Container(
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOpen ? AxisColors.secondary : AxisColors.borderSubtle,
              width: isOpen ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AxisColors.textHigh,
                ),
            cursorColor: AxisColors.secondary,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).isArabic ? 'اختر أو اكتب اسم المشروع...' : 'Select or write project name...',
              hintStyle:
                  const TextStyle(color: AxisColors.textDim, fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.folder_open_rounded,
                  size: 18, color: AxisColors.secondary),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: AxisColors.textDim),
                      onPressed: onClear,
                    ),
                  IconButton(
                    icon: Icon(
                      isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AxisColors.textDim,
                      size: 20,
                    ),
                    onPressed: () => onOpenChanged(!isOpen),
                  ),
                ],
              ),
            ),
            onTap: () => onOpenChanged(true),
            onChanged: (text) {
              onSelectProject(text.isNotEmpty ? text : null);
              if (!isOpen) onOpenChanged(true);
            },
          ),
        ),
        if (isOpen) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AxisColors.secondary.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: _buildDropdownItems(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
