import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand palette — inspired by Himalayan mountains, saffron, pine
  static const Color primary = Color(0xFF6B3FA0); // Deep mountain purple
  static const Color primaryDark = Color(0xFF4A2B70);
  static const Color primaryLight = Color(0xFF9B6FD0);
  static const Color accent = Color(0xFFE8A020); // Saffron/turmeric gold
  static const Color accentLight = Color(0xFFF5C55A);

  // Backgrounds
  static const Color backgroundDark = Color(0xFF0D0D14);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color cardDark = Color(0xFF232338);
  static const Color elevatedDark = Color(0xFF2C2C45);

  static const Color backgroundLight = Color(0xFFF7F5FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFEFEBF8);

  // Text
  static const Color textPrimaryDark = Color(0xFFF0EBF8);
  static const Color textSecondaryDark = Color(0xFFAA9CC4);
  static const Color textDisabledDark = Color(0xFF5C5480);

  static const Color textPrimaryLight = Color(0xFF1A1030);
  static const Color textSecondaryLight = Color(0xFF5A4880);
  static const Color textDisabledLight = Color(0xFFAA99CC);

  // System
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFB300);
  static const Color info = Color(0xFF1E88E5);

  // Player
  static const Color playerGradientStart = Color(0xFF2A1850);
  static const Color playerGradientEnd = Color(0xFF0D0D14);

  // Dividers
  static const Color dividerDark = Color(0xFF2E2B45);
  static const Color dividerLight = Color(0xFFE0D8F0);

  // Shimmer
  static const Color shimmerBase = Color(0xFF2C2C45);
  static const Color shimmerHighlight = Color(0xFF3D3D60);

  // Download states
  static const Color downloadProgress = Color(0xFF6B3FA0);
  static const Color downloadComplete = Color(0xFF43A047);

  // Region tag colors
  static const Map<String, Color> regionColors = {
    'Garhwali': Color(0xFF2E7D32),
    'Kumaoni': Color(0xFF1565C0),
    'Jaunsari': Color(0xFF6A1B9A),
    'Himachali': Color(0xFFC62828),
    'Kinnauri': Color(0xFF00695C),
    'Sirmauri': Color(0xFF4E342E),
  };
}
