import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/neural_sound_service.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Desktop card for ambient soundscape audio entrainment and volume control.
class DesktopSoundscapesCard extends StatelessWidget {
  const DesktopSoundscapesCard({super.key});

  Widget _buildSoundChip(String trackId, String displayName, IconData icon, String? currentTrack, bool isPlaying) {
    final isSelected = currentTrack == trackId && isPlaying;
    return InkWell(
      onTap: () => NeuralSoundService().toggle(trackId),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AxisColors.secondary.withValues(alpha: 0.15) : AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AxisColors.secondary : AxisColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.pause_circle_rounded : icon,
              size: 14,
              color: isSelected ? AxisColors.secondary : AxisColors.textDim,
            ),
            const SizedBox(width: 6),
            Text(
              displayName,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AxisColors.secondary : AxisColors.textHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isAr ? 'أصوات الخلفية المحيطة' : 'AMBIENT SOUNDSCAPES',
            subtitle: isAr
                ? 'مؤثرات صوتية هادئة لتعزيز التركيز والانغماس الذهني'
                : 'Neural audio entrainment for deep concentration',
            trailing: ValueListenableBuilder<bool>(
              valueListenable: NeuralSoundService().isPlayingNotifier,
              builder: (context, isPlaying, _) {
                return TelemetryChip(
                  label: isPlaying
                      ? (isAr ? 'الصوت نشط' : 'AUDIO ACTIVE')
                      : (isAr ? 'في وضع الاستعداد' : 'STANDBY'),
                  color: isPlaying ? AxisColors.tertiary : AxisColors.textDim,
                  dotColor: isPlaying ? AxisColors.tertiary : AxisColors.textDim,
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Volume Slider Row
          ValueListenableBuilder<double>(
            valueListenable: NeuralSoundService().volumeNotifier,
            builder: (context, volume, _) {
              return Row(
                children: [
                  Icon(
                    volume > 0.5
                        ? Icons.volume_up_rounded
                        : (volume > 0 ? Icons.volume_down_rounded : Icons.volume_mute_rounded),
                    size: 16,
                    color: AxisColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: AxisColors.secondary,
                        inactiveTrackColor: AxisColors.surfaceHighest,
                        thumbColor: AxisColors.secondary,
                      ),
                      child: Slider(
                        value: volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) => NeuralSoundService().setVolume(val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(volume * 100).toInt()}%',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textMuted),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Soundscapes Chips Wrap
          ValueListenableBuilder<String?>(
            valueListenable: NeuralSoundService().currentTrackNotifier,
            builder: (context, currentTrack, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: NeuralSoundService().isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSoundChip(
                        'Gentle Rain',
                        isAr ? 'مطر هادئ' : 'Gentle Rain',
                        Icons.water_drop_rounded,
                        currentTrack,
                        isPlaying,
                      ),
                      _buildSoundChip(
                        'Ocean Waves',
                        isAr ? 'أمواج المحيط' : 'Ocean Waves',
                        Icons.waves_rounded,
                        currentTrack,
                        isPlaying,
                      ),
                      _buildSoundChip(
                        'Campfire Glow',
                        isAr ? 'دفء الموقد' : 'Campfire Glow',
                        Icons.local_fire_department_rounded,
                        currentTrack,
                        isPlaying,
                      ),
                      _buildSoundChip(
                        'Deep Space',
                        isAr ? 'الفضاء العميق' : 'Deep Space',
                        Icons.dark_mode_rounded,
                        currentTrack,
                        isPlaying,
                      ),
                      _buildSoundChip(
                        'Zen Garden',
                        isAr ? 'حديقة الزن' : 'Zen Garden',
                        Icons.spa_rounded,
                        currentTrack,
                        isPlaying,
                      ),
                      _buildSoundChip(
                        'White Noise',
                        isAr ? 'ضوضاء بيضاء' : 'White Noise',
                        Icons.graphic_eq_rounded,
                        currentTrack,
                        isPlaying,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

