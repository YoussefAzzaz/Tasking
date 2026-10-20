import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

class FocusSessionConfig {
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int cyclesBeforeLongBreak;
  final bool autoStartBreaks;
  final bool soundscapeAutoPlay;

  const FocusSessionConfig({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.cyclesBeforeLongBreak = 4,
    this.autoStartBreaks = true,
    this.soundscapeAutoPlay = true,
  });

  FocusSessionConfig copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? cyclesBeforeLongBreak,
    bool? autoStartBreaks,
    bool? soundscapeAutoPlay,
  }) {
    return FocusSessionConfig(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      cyclesBeforeLongBreak:
          cyclesBeforeLongBreak ?? this.cyclesBeforeLongBreak,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      soundscapeAutoPlay: soundscapeAutoPlay ?? this.soundscapeAutoPlay,
    );
  }
}

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                          Text(
                            'SESSION CONFIGURATION',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                          ),
                        ],
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
                    _SectionHeader(
                      title: 'FOCUS WAVE DURATION',
                      subtitle: 'Quantum duration per uninterrupted session',
                      currentVal: '$_focusMin min',
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _focusPresets.map((min) {
                          final isSel = _focusMin == min;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${min}m'),
                              selected: isSel,
                              onSelected: (_) => setState(() => _focusMin = min),
                              selectedColor: AxisColors.primary.withValues(alpha: 0.25),
                              backgroundColor: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                              side: BorderSide(
                                color: isSel ? AxisColors.primary : AxisColors.borderSubtle,
                              ),
                              labelStyle: TextStyle(
                                color: isSel ? AxisColors.primarySoft : AxisColors.textDim,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Short Break Duration
                    _SectionHeader(
                      title: 'REBOOT BREAK (SHORT)',
                      subtitle: 'Rest duration between quantum waves',
                      currentVal: '$_shortBreakMin min',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _shortBreakPresets.map((min) {
                        final isSel = _shortBreakMin == min;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _shortBreakMin = min),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AxisColors.secondary.withValues(alpha: 0.2)
                                      : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? AxisColors.secondary : AxisColors.borderSubtle,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${min}m',
                                    style: TextStyle(
                                      color: isSel ? AxisColors.secondary : AxisColors.textDim,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Long Break Duration
                    _SectionHeader(
                      title: 'EXTENDED RECUPERATION (LONG BREAK)',
                      subtitle: 'Triggered after completing consecutive focus cycles',
                      currentVal: '$_longBreakMin min',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _longBreakPresets.map((min) {
                        final isSel = _longBreakMin == min;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _longBreakMin = min),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AxisColors.tertiary.withValues(alpha: 0.2)
                                      : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? AxisColors.tertiary : AxisColors.borderSubtle,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${min}m',
                                    style: TextStyle(
                                      color: isSel ? AxisColors.tertiary : AxisColors.textDim,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Cycles interval
                    _SectionHeader(
                      title: 'LONG BREAK INTERVAL',
                      subtitle: 'Completed cycles before extended rest',
                      currentVal: 'Every $_cycles Cycles',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [2, 3, 4, 6].map((c) {
                        final isSel = _cycles == c;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _cycles = c),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AxisColors.warning.withValues(alpha: 0.2)
                                      : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? AxisColors.warning : AxisColors.borderSubtle,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$c Cycles',
                                    style: TextStyle(
                                      color: isSel ? AxisColors.warning : AxisColors.textDim,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Automation Switches
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Auto-Start Breaks',
                                      style: TextStyle(
                                          color: AxisColors.textHigh,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text('Begin countdown automatically',
                                      style: TextStyle(
                                          color: AxisColors.textMuted, fontSize: 11)),
                                ],
                              ),
                              Switch(
                                value: _autoStartBreaks,
                                activeThumbColor: AxisColors.primary,
                                onChanged: (v) =>
                                    setState(() => _autoStartBreaks = v),
                              ),
                            ],
                          ),
                          const Divider(color: AxisColors.borderSubtle, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Neural Hums Auto-Play',
                                      style: TextStyle(
                                          color: AxisColors.textHigh,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text('Play soundscape when session starts',
                                      style: TextStyle(
                                          color: AxisColors.textMuted, fontSize: 11)),
                                ],
                              ),
                              Switch(
                                value: _soundscapeAutoPlay,
                                activeThumbColor: AxisColors.secondary,
                                onChanged: (v) =>
                                    setState(() => _soundscapeAutoPlay = v),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'APPLY CONFIGURATION',
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.currentVal,
  });

  final String title;
  final String subtitle;
  final String currentVal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: AxisColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AxisColors.borderSubtle),
          ),
          child: Text(
            currentVal,
            style: const TextStyle(
              color: AxisColors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
