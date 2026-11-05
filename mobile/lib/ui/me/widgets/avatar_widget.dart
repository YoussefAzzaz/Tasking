import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:axis/core/theme.dart';

/// Reusable Cyber-Minimalist Avatar Widget
/// Supports:
/// 1. Cached CDN network image with shimmer loading and error fallback
/// 2. User initials / default person icon fallback with gradient styling
/// 3. Uploading state with circular progress indicator overlay
/// 4. Optional interactive edit badge indicator
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.name,
    this.avatarColor,
    this.size = 60,
    this.isUploading = false,
    this.showEditBadge = false,
    this.onTap,
    this.heroTag,
  });

  final String? avatarUrl;
  final String name;
  final String? avatarColor;
  final double size;
  final bool isUploading;
  final bool showEditBadge;
  final VoidCallback? onTap;
  final String? heroTag;

  String _getInitials(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    try {
      if (parts.length == 1) {
        final chars = parts[0].characters;
        if (chars.isEmpty) return '';
        return chars.take(2).toString().toUpperCase();
      }
      final firstChars = parts[0].characters;
      final secondChars = parts[1].characters;
      final first = firstChars.isNotEmpty ? firstChars.first : '';
      final second = secondChars.isNotEmpty ? secondChars.first : '';
      return '$first$second'.toUpperCase();
    } catch (_) {
      return '';
    }
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.trim().isEmpty) return AxisColors.primary;
    try {
      var hex = hexString.trim().replaceAll('#', '').replaceAll('0x', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length == 8) {
        final val = int.tryParse(hex, radix: 16);
        if (val != null) {
          return Color(val);
        }
      }
    } catch (_) {
      // Fallback on any parsing error
    }
    return AxisColors.primary;
  }

  Widget _buildFallback(BuildContext context) {
    final baseColor = _parseColor(avatarColor);
    final initials = _getInitials(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            baseColor,
            baseColor.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.36,
                  letterSpacing: 0.5,
                ),
              )
            : Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: size * 0.52,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final baseColor = _parseColor(avatarColor);

    Widget avatarContent;

    if (hasValidUrl) {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: baseColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: -1,
            ),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            placeholder: (context, url) => _buildFallback(context),
            errorWidget: (context, url, error) => _buildFallback(context),
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 200),
          ),
        ),
      );
    } else {
      avatarContent = _buildFallback(context);
    }

    if (heroTag != null) {
      avatarContent = Hero(
        tag: heroTag!,
        child: avatarContent,
      );
    }

    Widget contentWithUpload = Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        if (isUploading)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AxisColors.primary),
                  ),
                ),
              ),
            ),
          ),
        if (showEditBadge && !isUploading)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AxisColors.primary,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: size * 0.22,
                color: AxisColors.primarySoft,
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: isUploading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: contentWithUpload,
      );
    }

    return contentWithUpload;
  }
}
