import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/neural_sound_service.dart';
import '../../../../domain/models/soundscape_track.dart';

/// Refined individual Soundscape card with live play/pause preview and animated wave visualizer
class SoundscapeCard extends StatelessWidget {
  const SoundscapeCard({
    super.key,
    required this.track,
    required this.isSelected,
    required this.soundService,
    required this.onSelect,
  });

  final SoundscapeTrack track;
  final bool isSelected;
  final NeuralSoundService soundService;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final color = track.color;

    return ValueListenableBuilder<String?>(
      valueListenable: soundService.currentTrackNotifier,
      builder: (context, currentTrack, _) {
        final isThisPlaying =
            soundService.isPlaying && currentTrack == track.title;

        return InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AxisColors.surfaceHigh
                  : AxisColors.surfaceLow.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : AxisColors.borderSubtle,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(track.icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),

                // Title, Category, and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              context.l10n.localizedSoundscapeTitle(track.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AxisColors.textHigh
                                    : AxisColors.textHigh
                                        .withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.l10n.localizedSoundscapeCategory(track.category),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.localizedSoundscapeSubtitle(track.subtitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AxisColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Live Equalizer Visualizer (when this track is playing)
                if (isThisPlaying) ...[
                  const AnimatedEqualizerBars(),
                  const SizedBox(width: 8),
                ],

                // Play / Pause Preview Button
                IconButton(
                  iconSize: 20,
                  tooltip: isThisPlaying
                      ? (context.isArabic ? 'إيقاف الصوت' : 'Pause sound')
                      : (context.isArabic ? 'استماع للمعاينة' : 'Listen to preview'),
                  onPressed: () => soundService.toggle(track.title),
                  icon: Icon(
                    isThisPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: isThisPlaying ? color : AxisColors.textDim,
                  ),
                ),

                // Selection checkmark
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? color : AxisColors.borderSubtle,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 13, color: Colors.black)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dynamic 4-bar equalizer visualizer micro-animation for active soundscape
class AnimatedEqualizerBars extends StatefulWidget {
  const AnimatedEqualizerBars({super.key});

  @override
  State<AnimatedEqualizerBars> createState() => _AnimatedEqualizerBarsState();
}

class _AnimatedEqualizerBarsState extends State<AnimatedEqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(6 + 8 * val),
            const SizedBox(width: 2),
            _bar(14 - 8 * val),
            const SizedBox(width: 2),
            _bar(8 + 6 * (1.0 - val)),
            const SizedBox(width: 2),
            _bar(5 + 10 * val),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 2.5,
      height: height.clamp(4.0, 16.0),
      decoration: BoxDecoration(
        color: AxisColors.secondary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

