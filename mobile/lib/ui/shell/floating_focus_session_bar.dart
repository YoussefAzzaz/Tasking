import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/bloc/blocs.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/task_repository.dart' show Task;

/// Floating persistent indicator shown under the top app header whenever a focus session is active.
class FloatingFocusSessionBar extends StatelessWidget {
  const FloatingFocusSessionBar({super.key, this.onTap});
  final VoidCallback? onTap;

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    try {
      context.push('/focus');
    } catch (_) {
      try {
        GoRouter.of(context).push('/focus');
      } catch (_) {
        // Fallback or testing environment
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    FocusSessionCubit? cubit;
    try {
      cubit = context.watch<FocusSessionCubit>();
    } catch (_) {
      cubit = null;
    }

    if (cubit != null) {
      final state = cubit.state;
      if (!state.isRunning) {
        return const SizedBox.shrink();
      }
      return _buildBar(context, state.timeFormatted, state.attachedTask,
          isBreak: state.isBreak);
    }

    final sessionService = FocusSessionService();
    return ListenableBuilder(
      listenable: Listenable.merge([
        sessionService.isRunningNotifier,
        sessionService.remainingSecondsNotifier,
        sessionService.isBreakNotifier,
      ]),
      builder: (context, _) {
        final isRunning = sessionService.isRunning;
        if (!isRunning) {
          return const SizedBox.shrink();
        }

        final remaining = sessionService.remainingSeconds;
        final minutes = remaining ~/ 60;
        final seconds = remaining % 60;
        final timeDisplay =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        final attachedTask = sessionService.attachedTask;

        return _buildBar(context, timeDisplay, attachedTask,
            isBreak: sessionService.isBreak);
      },
    );
  }

  Widget _buildBar(BuildContext context, String timeDisplay, Task? attachedTask,
      {bool isBreak = false}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AxisColors.primary.withValues(alpha: 0.22),
                  AxisColors.secondary.withValues(alpha: 0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AxisColors.secondary.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.secondary.withValues(alpha: 0.14),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing amber/cyan live dot indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBreak ? AxisColors.warning : AxisColors.secondary,
                    boxShadow: [
                      BoxShadow(
                        color: (isBreak
                                ? AxisColors.warning
                                : AxisColors.secondary)
                            .withValues(alpha: 0.8),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Title and time
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        isBreak
                            ? (context.isArabic ? 'استراحة إعادة الشحن' : 'REBOOT BREAK')
                            : (context.isArabic ? 'التركيز نشط' : 'FOCUS ACTIVE'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color:
                              isBreak ? AxisColors.warning : AxisColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.textHigh,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (attachedTask != null) ...[
                        const SizedBox(width: 8),
                        const Text(
                          '•',
                          style: TextStyle(color: AxisColors.textDim, fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            attachedTask.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AxisColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Return pill button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AxisColors.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AxisColors.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.isArabic ? 'متابعة' : 'RESUME',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.secondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        context.isArabic
                            ? Icons.arrow_back_rounded
                            : Icons.arrow_forward_rounded,
                        size: 12,
                        color: AxisColors.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
