import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/l10n/app_localizations.dart';
import '../../domain/models/focus_session_config.dart';
import 'widgets/focus_duration_selectors.dart';

export '../../domain/models/focus_session_config.dart';
export 'widgets/focus_duration_selectors.dart';

/// Modal bottom sheet for configuring quantum focus wave sessions.
class FocusSettingsSheet extends StatefulWidget {
  const FocusSettingsSheet({
    super.key,
    required this.initialConfig,
    required this.onConfigSaved,
  });

  final FocusSessionConfig initialConfig;
  final ValueChanged<FocusSessionConfig> onConfigSaved;

  @override
  State<FocusSettingsSheet> createState() => _FocusSettingsSheetState();
}

class _FocusSettingsSheetState extends State<FocusSettingsSheet> {
  late int _focusMin;
  late int _shortBreakMin;
  late int _longBreakMin;
  late int _cycles;
  late bool _autoStartBreaks;
  late bool _soundscapeAutoPlay;

  static const _focusPresets = [15, 25, 45, 50, 60, 90];
  static const _shortBreakPresets = [3, 5, 10];
  static const _longBreakPresets = [15, 20, 30];
  static const _cyclePresets = [2, 3, 4, 6];

  @override
  void initState() {
    super.initState();
    _focusMin = widget.initialConfig.focusMinutes;
    _shortBreakMin = widget.initialConfig.shortBreakMinutes;
    _longBreakMin = widget.initialConfig.longBreakMinutes;
    _cycles = widget.initialConfig.cyclesBeforeLongBreak;
    _autoStartBreaks = widget.initialConfig.autoStartBreaks;
    _soundscapeAutoPlay = widget.initialConfig.soundscapeAutoPlay;
  }

  void _save() {
    final updated = FocusSessionConfig(
      focusMinutes: _focusMin,
      shortBreakMinutes: _shortBreakMin,
      longBreakMinutes: _longBreakMin,
      cyclesBeforeLongBreak: _cycles,
      autoStartBreaks: _autoStartBreaks,
      soundscapeAutoPlay: _soundscapeAutoPlay,
    );

    widget.onConfigSaved(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle and Header
              Padding(
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AxisColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune_rounded,
                              color: AxisColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.isArabic
                                ? 'إعدادات الجلسة'
                                : 'SESSION CONFIGURATION',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AxisColors.textMuted, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: AxisColors.borderSubtle, height: 1),

              // Settings Options List
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Focus Work Duration
                      FocusWaveDurationSelector(
                        selectedMin: _focusMin,
                        presets: _focusPresets,
                        onSelected: (min) => setState(() => _focusMin = min),
                      ),
                      const SizedBox(height: 24),

                      // Short Break Duration
                      FocusBreakDurationSelector(
                        title: context.isArabic
                            ? 'استراحة قصيرة'
                            : 'REBOOT BREAK (SHORT)',
                        subtitle: context.isArabic
                            ? 'مدة الراحة بين موجات التركيز'
                            : 'Rest duration between quantum waves',
                        selectedMin: _shortBreakMin,
                        presets: _shortBreakPresets,
                        accentColor: AxisColors.secondary,
                        onSelected: (min) =>
                            setState(() => _shortBreakMin = min),
                      ),
                      const SizedBox(height: 24),

                      // Long Break Duration
                      FocusBreakDurationSelector(
                        title: context.isArabic
                            ? 'استراحة طويلة'
                            : 'EXTENDED RECUPERATION (LONG BREAK)',
                        subtitle: context.isArabic
                            ? 'يتم تفعيلها بعد إكمال دورات التركيز المتتالية'
                            : 'Triggered after completing consecutive focus cycles',
                        selectedMin: _longBreakMin,
                        presets: _longBreakPresets,
                        accentColor: AxisColors.tertiary,
                        onSelected: (min) =>
                            setState(() => _longBreakMin = min),
                      ),
                      const SizedBox(height: 24),

                      // Cycles interval
                      FocusCyclesIntervalSelector(
                        selectedCycles: _cycles,
                        presets: _cyclePresets,
                        onSelected: (c) => setState(() => _cycles = c),
                      ),
                      const SizedBox(height: 24),

                      // Automation Switches
                      FocusAutomationSwitchesCard(
                        autoStartBreaks: _autoStartBreaks,
                        soundscapeAutoPlay: _soundscapeAutoPlay,
                        onAutoStartBreaksChanged: (v) =>
                            setState(() => _autoStartBreaks = v),
                        onSoundscapeAutoPlayChanged: (v) =>
                            setState(() => _soundscapeAutoPlay = v),
                      ),
                      const SizedBox(height: 28),

                      // Apply Button
                      InkWell(
                        onTap: _save,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AxisColors.primary, Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AxisColors.primary.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.isArabic
                                        ? 'تطبيق الإعدادات'
                                        : 'APPLY CONFIGURATION',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                  ),
                                ],
                              ),
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
    );
  }
}
