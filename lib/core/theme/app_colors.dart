import 'package:flutter/material.dart';

abstract final class AppColors {
  // Background - Deep dark
  static const Color backgroundDark = Color(0xFF0A0E1A);
  static const Color surfaceDark = Color(0xFF121828);
  static const Color cardDark = Color(0xFF1A2235);

  // Keep light for compatibility but we won't use them
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Primary - Neon cyan
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryLight = Color(0xFF6EFFFF);
  static const Color primaryDark = Color(0xFF0097A7);

  // Accent - Neon magenta/pink
  static const Color accent = Color(0xFFFF00E5);
  static const Color accentLight = Color(0xFFFF66EE);

  // Neon palette
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonMagenta = Color(0xFFFF00E5);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonOrange = Color(0xFFFF6B35);
  static const Color neonYellow = Color(0xFFFFE500);
  static const Color neonPurple = Color(0xFFBB86FC);
  static const Color neonBlue = Color(0xFF3D5AFE);
  static const Color neonRed = Color(0xFFFF1744);

  // Status colors - neon versions
  static const Color statusEnVol = Color(0xFF00E5FF);
  static const Color statusEscale = Color(0xFFFF6B35);
  static const Color statusRepos = Color(0xFF00FF88);
  static const Color statusRetour = Color(0xFFBB86FC);

  // Semantic
  static const Color success = Color(0xFF00FF88);
  static const Color warning = Color(0xFFFFE500);
  static const Color error = Color(0xFFFF1744);
  static const Color info = Color(0xFF00E5FF);
}
