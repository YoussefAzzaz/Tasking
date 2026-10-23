import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/neural_sound_service.dart';

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

/// Redesigned practical, aesthetic Neural Soundscape selector
/// Features category filters, individual play/pause previews, animated equalizer bars,
/// active selection indicators, and master ambient volume slider.
class SoundscapeSelectorGrid extends StatefulWidget {
  const SoundscapeSelectorGrid({
    super.key,
    this.soundscapes = kRelaxingSoundscapes,
    required this.selectedSoundscape,
    required this.soundService,
    required this.onSelectSoundscape,
    this.isCompactSheet = false,
  });

  final List<SoundscapeTrack> soundscapes;
  final String selectedSoundscape;
  final NeuralSoundService soundService;
  final ValueChanged<String> onSelectSoundscape;
  final bool isCompactSheet;

  /// Quick helper to open soundscape selector as a modal bottom sheet
  static Future<void> showSoundscapeSheet({
    required BuildContext context,
    required String selectedSoundscape,
    required NeuralSoundService soundService,
    required ValueChanged<String> onSelectSoundscape,
    List<SoundscapeTrack> soundscapes = kRelaxingSoundscapes,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.82,
        decoration: BoxDecoration(
          color: const Color(0xF50C1626),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AxisColors.borderGlass2,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            Expanded(
              child: SoundscapeSelectorGrid(
                soundscapes: soundscapes,
                selectedSoundscape: selectedSoundscape,
                soundService: soundService,
                onSelectSoundscape: onSelectSoundscape,
                isCompactSheet: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<SoundscapeSelectorGrid> createState() => _SoundscapeSelectorGridState();
}

class _SoundscapeSelectorGridState extends State<SoundscapeSelectorGrid> {
  String _selectedCategory = 'All';
  late String _selectedSoundscape;

  @override
  void initState() {
    super.initState();
    _selectedSoundscape = widget.selectedSoundscape;
  }

  @override
  void didUpdateWidget(covariant SoundscapeSelectorGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSoundscape != widget.selectedSoundscape) {
      _selectedSoundscape = widget.selectedSoundscape;
    }
  }

  void _onTrackSelected(String title) {
    setState(() {
      _selectedSoundscape = title;
    });
    widget.onSelectSoundscape(title);
  }

  List<String> get _categories {
    final cats = {'All'};
    for (final s in widget.soundscapes) {
      cats.add(s.category);
    }
    return cats.toList();
  }

  List<SoundscapeTrack> get _filteredTracks {
    if (_selectedCategory == 'All') return widget.soundscapes;
    return widget.soundscapes
        .where((t) => t.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _filteredTracks;

    final tracksList = ListView.separated(
      shrinkWrap: !widget.isCompactSheet,
      physics: widget.isCompactSheet
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final track = tracks[i];
        final isSelected = _selectedSoundscape == track.title;
        return _SoundscapeCard(
          track: track,
          isSelected: isSelected,
          soundService: widget.soundService,
          onSelect: () => _onTrackSelected(track.title),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.isCompactSheet ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // Header with Live Status & Volume Quick Bar
        _buildHeader(context),
        const SizedBox(height: 12),

        // Category Filter Chips
        _buildCategoryChips(),
        const SizedBox(height: 14),

        // Track Cards List
        if (widget.isCompactSheet)
          Expanded(child: tracksList)
        else
          tracksList,
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AxisColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.spa_rounded,
                        size: 16, color: AxisColors.secondary),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Relaxing Soundscapes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AxisColors.textHigh,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Therapeutic procedural focus audio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AxisColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Global Play/Stop indicator
            ValueListenableBuilder<bool>(
              valueListenable: widget.soundService.isPlayingNotifier,
              builder: (context, isPlaying, _) {
                return InkWell(
                  onTap: () =>
                      widget.soundService.toggle(_selectedSoundscape),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? AxisColors.secondary.withValues(alpha: 0.18)
                          : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPlaying
                            ? AxisColors.secondary
                            : AxisColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPlaying
                              ? Icons.volume_up_rounded
                              : Icons.play_arrow_rounded,
                          size: 14,
                          color: isPlaying
                              ? AxisColors.secondary
                              : AxisColors.textDim,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPlaying ? 'PLAYING' : 'PREVIEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isPlaying
                                ? AxisColors.secondary
                                : AxisColors.textMuted,
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
        const SizedBox(height: 10),

        // Master Volume Bar
        _buildVolumeSlider(),
      ],
    );
  }

  Widget _buildVolumeSlider() {
    return ValueListenableBuilder<double>(
      valueListenable: widget.soundService.volumeNotifier,
      builder: (context, volume, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AxisColors.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                volume == 0
                    ? Icons.volume_off_rounded
                    : (volume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded),
                size: 16,
                color: AxisColors.textMuted,
              ),
              const SizedBox(width: 8),
              const Text(
                'Volume',
                style: TextStyle(fontSize: 11, color: AxisColors.textMuted),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: AxisColors.secondary,
                    inactiveTrackColor: AxisColors.borderSubtle,
                    thumbColor: AxisColors.secondary,
                  ),
                  child: Slider(
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) => widget.soundService.setVolume(v),
                  ),
                ),
              ),
              Text(
                '${(volume * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AxisColors.textHigh,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSel = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = cat),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSel
                      ? AxisColors.secondary.withValues(alpha: 0.2)
                      : AxisColors.surfaceLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSel ? AxisColors.secondary : AxisColors.borderSubtle,
                    width: isSel ? 1.2 : 1,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? AxisColors.secondary : AxisColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Refined individual Soundscape card with live play/pause preview and animated wave visualizer
class _SoundscapeCard extends StatelessWidget {
  const _SoundscapeCard({
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
        final isThisPlaying = soundService.isPlaying && currentTrack == track.title;

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
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AxisColors.textHigh
                                    : AxisColors.textHigh.withValues(alpha: 0.9),
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
                              track.category,
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
                        track.subtitle,
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
                  const _AnimatedEqualizerBars(),
                  const SizedBox(width: 8),
                ],

                // Play / Pause Preview Button
                IconButton(
                  iconSize: 20,
                  tooltip: isThisPlaying ? 'Pause sound' : 'Listen to preview',
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
class _AnimatedEqualizerBars extends StatefulWidget {
  const _AnimatedEqualizerBars();

  @override
  State<_AnimatedEqualizerBars> createState() => _AnimatedEqualizerBarsState();
}

class _AnimatedEqualizerBarsState extends State<_AnimatedEqualizerBars>
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
