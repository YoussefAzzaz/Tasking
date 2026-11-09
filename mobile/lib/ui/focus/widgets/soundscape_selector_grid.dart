import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/neural_sound_service.dart';
import '../../../../domain/models/soundscape_track.dart';
import 'soundscape_card.dart';

export '../../../../domain/models/soundscape_track.dart';
export 'soundscape_card.dart';

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
        return SoundscapeCard(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.isArabic
                              ? 'خلفيات صوتية للاسترخاء'
                              : 'Relaxing Soundscapes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AxisColors.textHigh,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          context.isArabic
                              ? 'أصوات إجرائية علاجية لتعزيز التركيز'
                              : 'Therapeutic procedural focus audio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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
                          isPlaying
                              ? (context.isArabic ? 'قيد التشغيل' : 'PLAYING')
                              : (context.isArabic ? 'معاينة' : 'PREVIEW'),
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
              Text(
                context.isArabic ? 'مستوى الصوت' : 'Volume',
                style: const TextStyle(fontSize: 11, color: AxisColors.textMuted),
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
            padding: const EdgeInsetsDirectional.only(end: 6),
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
                  cat == 'All'
                      ? (context.isArabic ? 'الكل' : 'All')
                      : context.l10n.localizedSoundscapeCategory(cat),
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
