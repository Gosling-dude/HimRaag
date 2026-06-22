import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Branded network image with a shimmer loading state and a graceful,
/// on-brand fallback (gradient + initials) instead of a bare grey icon.
///
/// Use [AppArtwork] for square covers (songs/albums) and [AppAvatar] for
/// circular artist images. Centralising this guarantees consistent thumbnails
/// with proper loading/error handling on every screen.
class AppArtwork extends StatelessWidget {
  const AppArtwork({
    super.key,
    required this.url,
    required this.size,
    this.label = '',
    this.radius = 12,
  });

  final String url;
  final double size;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: _NetworkImageBody(
        url: url,
        width: size,
        height: size,
        label: label,
        circle: false,
        radius: radius,
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.url,
    required this.size,
    this.label = '',
  });

  final String url;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: _NetworkImageBody(
        url: url,
        width: size,
        height: size,
        label: label,
        circle: true,
        radius: size / 2,
      ),
    );
  }
}

class _NetworkImageBody extends StatelessWidget {
  const _NetworkImageBody({
    required this.url,
    required this.width,
    required this.height,
    required this.label,
    required this.circle,
    required this.radius,
  });

  final String url;
  final double width;
  final double height;
  final String label;
  final bool circle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return _Fallback(label: label, width: width, height: height, circle: circle);
    }
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      memCacheWidth: (width * dpr).round(),
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(width: width, height: height, color: AppColors.shimmerBase),
      ),
      errorWidget: (_, __, ___) =>
          _Fallback(label: label, width: width, height: height, circle: circle),
    );
  }
}

/// On-brand fallback: a deterministic gradient with the label's initials.
class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.label,
    required this.width,
    required this.height,
    required this.circle,
  });

  final String label;
  final double width;
  final double height;
  final bool circle;

  static const List<List<Color>> _gradients = [
    [Color(0xFF6B3FA0), Color(0xFF3A1E66)],
    [Color(0xFF1565C0), Color(0xFF0D2A55)],
    [Color(0xFF2E7D32), Color(0xFF14401C)],
    [Color(0xFFC2185B), Color(0xFF5A0E2E)],
    [Color(0xFF00695C), Color(0xFF023A33)],
    [Color(0xFFE8A020), Color(0xFF8A5A0E)],
  ];

  String get _initials {
    final words =
        label.replaceAll(RegExp('[^A-Za-z0-9 ]'), ' ').trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '♪';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final g = _gradients[label.hashCode.abs() % _gradients.length];
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: g,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: label.trim().isEmpty
          ? Icon(circle ? Icons.person_rounded : Icons.music_note_rounded,
              color: Colors.white70, size: width * 0.4)
          : Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: width * 0.34,
                letterSpacing: 1,
              ),
            ),
    );
  }
}
