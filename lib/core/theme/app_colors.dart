import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary - Aviation Blue
  static const Color primary = Color(0xFF1A5276);
  static const Color primaryLight = Color(0xFF2E86C1);
  static const Color primaryDark = Color(0xFF0E2F44);

  // Accent - Warm gold for family warmth
  static const Color accent = Color(0xFFF39C12);
  static const Color accentLight = Color(0xFFF5B041);

  // Status colors
  static const Color statusEnVol = Color(0xFF2196F3);
  static const Color statusEscale = Color(0xFFFF9800);
  static const Color statusRepos = Color(0xFF4CAF50);
  static const Color statusRetour = Color(0xFF9C27B0);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Semantic
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);
}
