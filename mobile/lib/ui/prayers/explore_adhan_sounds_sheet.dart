import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/prayers/adhan_sound_service.dart';

/// Interactive modal allowing users to explore famous Islamic Adhans,
/// preview them in real-time, select their preferred Adhan, or upload custom device sounds.
class ExploreAdhanSoundsSheet extends StatefulWidget {
  final bool isDesktop;

  const ExploreAdhanSoundsSheet({
    super.key,
    this.isDesktop = false,
  });

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExploreAdhanSoundsSheet(),
    );
  }

  static Future<void> showAsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: const ExploreAdhanSoundsSheet(isDesktop: true),
        ),
      ),
    );
  }

  @override
  State<ExploreAdhanSoundsSheet> createState() => _ExploreAdhanSoundsSheetState();
}

class _ExploreAdhanSoundsSheetState extends State<ExploreAdhanSoundsSheet> {
  final _soundService = AdhanSoundService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isUploading = false;

  @override
  void dispose() {
    _soundService.stopPreview();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCustomUpload() async {
    HapticFeedback.lightImpact();
    setState(() => _isUploading = true);
    final customSound = await _soundService.pickAndSetCustomSound();
    if (mounted) {
      setState(() => _isUploading = false);
      if (customSound != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AxisColors.surfaceLow,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AxisColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selected custom sound: ${customSound.name}',
                    style: const TextStyle(color: AxisColors.textHigh, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final famousList = AdhanSoundService.kFamousAdhans.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.nameAr.contains(q) ||
          s.muadhin.toLowerCase().contains(q) ||
          s.muadhinAr.contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.descriptionAr.contains(q);
    }).toList();

    final content = Container(
      decoration: BoxDecoration(
        color: const Color(0xF50D1524),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.isDesktop ? 20 : 28),
          bottom: widget.isDesktop ? const Radius.circular(20) : Radius.zero,
        ),
        border: Border.all(color: AxisColors.borderActive.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Handle or Window Header
          if (!widget.isDesktop) ...[
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AxisColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],

          // Title Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Color(0xFF38BDF8), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'أصوات ومؤذنو الأذان' : 'ADHAN SOUNDS & MU’ADHINS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: AxisColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'اختر من أشهر الأذانات أو ارفع صوتك المفضل'
                            : 'Choose from world-renowned Adhans or upload custom audio',
                        style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // Search Bar & Custom Upload Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Custom Upload Banner
                InkWell(
                  onTap: _isUploading ? null : _handleCustomUpload,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AxisColors.primary.withValues(alpha: 0.22),
                          const Color(0xFF38BDF8).withValues(alpha: 0.12),
                          AxisColors.surfaceLowest,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AxisColors.primarySoft.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AxisColors.primary.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: _isUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft),
                                )
                              : const Icon(Icons.upload_file_rounded, color: AxisColors.primarySoft, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic ? 'رفع صوت أذان من الهاتف' : 'Upload Custom Sound from Phone',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isArabic
                                    ? 'استخدم أي ملف MP3 أو M4A أو WAV كصوت للأذان'
                                    : 'Pick any audio file from device storage (.mp3, .m4a, .wav)',
                                style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AxisColors.primarySoft),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Search Input
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 13, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AxisColors.textDim),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: AxisColors.textDim),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      hintText: isArabic
                          ? 'ابحث باسم الحرم، المؤذن أو القارئ...'
                          : 'Search by mosque, mu’adhin or reciter...',
                      hintStyle: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Scrollable List of Adhan Options
          Flexible(
            child: ValueListenableBuilder<AdhanSoundOption>(
              valueListenable: _soundService.selectedSoundNotifier,
              builder: (context, activeSound, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: _soundService.previewingNotifier,
                  builder: (context, previewingId, _) {
                    return ValueListenableBuilder<String?>(
                      valueListenable: _soundService.downloadingNotifier,
                      builder: (context, downloadingId, _) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Show Custom Sound if Active
                            if (activeSound.isCustom) ...[
                              _buildSoundCard(
                                sound: activeSound,
                                isActive: true,
                                isPlaying: previewingId == activeSound.id,
                                isDownloading: downloadingId == activeSound.id,
                                isArabic: isArabic,
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Famous Adhans
                            ...famousList.map((sound) {
                              final isActive = activeSound.id == sound.id;
                              final isPlaying = previewingId == sound.id;
                              final isDownloading = downloadingId == sound.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildSoundCard(
                                  sound: sound,
                                  isActive: isActive,
                                  isPlaying: isPlaying,
                                  isDownloading: isDownloading,
                                  isArabic: isArabic,
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    if (widget.isDesktop) {
      return content;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        top: MediaQuery.of(context).padding.top + 40,
      ),
      child: content,
    );
  }

  Widget _buildSoundCard({
    required AdhanSoundOption sound,
    required bool isActive,
    required bool isPlaying,
    required bool isDownloading,
    required bool isArabic,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? AxisColors.primary.withValues(alpha: 0.12)
            : AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AxisColors.primarySoft.withValues(alpha: 0.8)
              : AxisColors.borderSubtle,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDownloading
              ? null
              : () async {
                  HapticFeedback.selectionClick();
                  await _soundService.selectSound(sound);
                },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Play / Preview Button
                InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await _soundService.togglePreview(sound);
                  },
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPlaying
                          ? AxisColors.warning.withValues(alpha: 0.2)
                          : AxisColors.surfaceLow,
                      border: Border.all(
                        color: isPlaying
                            ? AxisColors.warning
                            : AxisColors.borderSubtle,
                      ),
                    ),
                    child: Icon(
                      isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 22,
                      color: isPlaying ? AxisColors.warning : AxisColors.primarySoft,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Sound Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isArabic ? sound.nameAr : sound.name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isActive ? AxisColors.primarySoft : AxisColors.textHigh,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sound.isBundled) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isArabic ? 'مضمن' : 'OFFLINE',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic ? sound.muadhinAr : sound.muadhin,
                        style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.secondarySoft),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isArabic ? sound.descriptionAr : sound.description,
                        style: GoogleFonts.getFont('Geist', fontSize: 10.5, color: AxisColors.textDim),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Active Checkmark, Download Spinner, or Select Action
                if (isDownloading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft),
                  )
                else if (isActive)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AxisColors.primary,
                    ),
                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                  )
                else
                  Text(
                    isArabic ? 'اختيار' : 'SELECT',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AxisColors.textDim,
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

