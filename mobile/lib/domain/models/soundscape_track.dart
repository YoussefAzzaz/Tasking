import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Relaxing Neural Soundscape track model
class SoundscapeTrack {
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;

  const SoundscapeTrack({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
  });
}

/// The 8 relaxing, research-backed ambient focus soundscapes
const kRelaxingSoundscapes = [
  SoundscapeTrack(
    title: 'Gentle Rain',
    subtitle: 'Soothing forest drizzle & soft drops',
    category: 'Nature',
    icon: Icons.water_drop_rounded,
    color: AxisColors.primary,
  ),
  SoundscapeTrack(
    title: 'Ocean Waves',
    subtitle: 'Rhythmic surf & tidal breathing flow',
    category: 'Nature',
    icon: Icons.waves_rounded,
    color: AxisColors.secondary,
  ),
  SoundscapeTrack(
    title: 'Campfire Glow',
    subtitle: 'Warm crackling embers & low hearth',
    category: 'Cozy',
    icon: Icons.local_fire_department_rounded,
    color: AxisColors.warning,
  ),
  SoundscapeTrack(
    title: 'Deep Space',
    subtitle: 'Velvet cosmic harmonic pad drone',
    category: 'Ambient',
    icon: Icons.dark_mode_rounded,
    color: AxisColors.tertiary,
  ),
  SoundscapeTrack(
    title: 'Zen Garden',
    subtitle: 'Singing bowl resonance & calm breeze',
    category: 'Zen',
    icon: Icons.spa_rounded,
    color: AxisColors.success,
  ),
  SoundscapeTrack(
    title: 'Night Crickets',
    subtitle: 'Tranquil meadow nocturnal air',
    category: 'Nature',
    icon: Icons.nights_stay_rounded,
    color: Color(0xFF818CF8),
  ),
  SoundscapeTrack(
    title: 'Alpha Wave 10Hz',
    subtitle: 'Subconscious calm focus entrainment',
    category: 'Zen',
    icon: Icons.psychology_rounded,
    color: Color(0xFFF472B6),
  ),
  SoundscapeTrack(
    title: 'Brown Noise',
    subtitle: 'Deep warm sound veil & tinnitus mask',
    category: 'Ambient',
    icon: Icons.graphic_eq_rounded,
    color: AxisColors.primarySoft,
  ),
];

