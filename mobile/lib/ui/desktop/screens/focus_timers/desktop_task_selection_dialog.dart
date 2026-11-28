import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/focus_session_service.dart';
import '../../../../data/task_repository.dart';
import '../../widgets/ghost_button.dart';

/// Modal dialog for choosing a deliverable to attach to the active focus session.
void showDesktopTaskSelectionDialog(BuildContext context) {
  final isAr = AppLocalizations.of(context).isArabic;

  showDialog<void>(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Material(
        color: AxisColors.canvasBase,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AxisColors.borderGlass2, width: 1),
        ),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isAr ? 'ربط مهمة بجلسة التركيز' : 'ATTACH TASK TO FOCUS SESSION',
                style: AxisFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: StreamBuilder<List<Task>>(
                  stream: TaskRepository().watchTasks(),
                  builder: (context, snapshot) {
                    final tasks = (snapshot.data ?? []).where((t) => !t.isCompleted).toList();
                    if (tasks.isEmpty) {
                      return Center(
                        child: Text(
                          isAr ? 'لا توجد مهام نشطة حالياً.' : 'No active deliverables found.',
                          style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const Divider(color: AxisColors.borderSubtle, height: 1),
                      itemBuilder: (context, idx) {
                        final t = tasks[idx];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            hoverColor: AxisColors.surfaceHigh.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            title: Text(
                              t.title,
                              style: AxisFonts.spaceGrotesk(fontSize: 13, color: AxisColors.textHigh),
                            ),
                            subtitle: t.notes != null && t.notes!.isNotEmpty
                                ? Text(
                                    t.notes!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textMuted),
                                  )
                                : null,
                            onTap: () {
                              FocusSessionService().setAttachedTask(t);
                              Navigator.of(dialogCtx).pop();
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: GhostButton(
                  label: isAr ? 'إغلاق' : 'Close',
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

