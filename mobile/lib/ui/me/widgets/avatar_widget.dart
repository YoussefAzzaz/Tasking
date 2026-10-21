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
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AxisColors.primary;
    final hex = hexString.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
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
            placeholder: (context, url) => Container(
              color: AxisColors.surfaceHigh,
              child: Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      baseColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => _buildFallback(context),
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
