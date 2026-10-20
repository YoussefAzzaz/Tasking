import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/neural_sound_service.dart';

/// Neural soundscape track data
class SoundscapeTrack {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const SoundscapeTrack({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

/// Soundscape selector 2-column grid with live preview audio toggle
class SoundscapeSelectorGrid extends StatelessWidget {
  const SoundscapeSelectorGrid({
    super.key,
    required this.soundscapes,
    required this.selectedSoundscape,
    required this.soundService,
    required this.onSelectSoundscape,
  });

  final List<SoundscapeTrack> soundscapes;
  final String selectedSoundscape;
  final NeuralSoundService soundService;
  final ValueChanged<String> onSelectSoundscape;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.graphic_eq_rounded,
                    size: 18, color: AxisColors.secondary),
                SizedBox(width: 8),
                Text(
                  'Neural Soundscapes',
                  style: TextStyle(
                    color: AxisColors.textHigh,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<bool>(
              valueListenable: soundService.isPlayingNotifier,
              builder: (context, playing, _) {
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => soundService.toggle(selectedSoundscape),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: playing
                          ? AxisColors.tertiary.withValues(alpha: 0.2)
                          : AxisColors.surfaceHigh.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: playing
                            ? AxisColors.tertiary
                            : AxisColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          playing
                              ? Icons.volume_up_rounded
                              : Icons.play_arrow_rounded,
                          size: 14,
                          color: playing
                              ? AxisColors.tertiary
                              : AxisColors.textDim,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          playing ? 'PLAYING' : 'PREVIEW',
                          style: TextStyle(
                            fontSize: 10,
                            color: playing
                                ? AxisColors.tertiary
                                : AxisColors.textMuted,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: soundscapes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, i) {
            final track = soundscapes[i];
            final isSel = selectedSoundscape == track.title;
            final color = track.color;

            return InkWell(
              onTap: () => onSelectSoundscape(track.title),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSel
                      ? AxisColors.surfaceHigh
                      : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? color : AxisColors.borderSubtle,
                    width: isSel ? 1.5 : 1,
                  ),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(track.icon, size: 16, color: color),
                        ),
                        if (isSel)
                          Row(
                            children: [
                              Container(
                                width: 2,
                                height: 10,
                                color: color,
                                margin: const EdgeInsets.only(right: 2),
                              ),
                              Container(
                                width: 2,
                                height: 14,
                                color: color,
                                margin: const EdgeInsets.only(right: 2),
                              ),
                              Container(width: 2, height: 8, color: color),
                            ],
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textHigh,
                          ),
                        ),
                        Text(
                          track.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AxisColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
