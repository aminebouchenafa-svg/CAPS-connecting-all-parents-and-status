import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => dark;

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.neonCyan,
          secondary: AppColors.neonMagenta,
          surface: AppColors.surfaceDark,
          error: AppColors.neonRed,
          onPrimary: AppColors.backgroundDark,
          onSecondary: AppColors.backgroundDark,
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        textTheme: GoogleFonts.nunitoTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: Colors.white.withValues(alpha: 0.9),
          displayColor: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.neonCyan,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.neonCyan,
            letterSpacing: 1.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.neonCyan.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonCyan.withValues(alpha: 0.15),
            foregroundColor: AppColors.neonCyan,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: AppColors.neonCyan.withValues(alpha: 0.5)),
            ),
            textStyle: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          indicatorColor: AppColors.neonCyan.withValues(alpha: 0.15),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: AppColors.neonCyan, size: 26);
            }
            return IconThemeData(
                color: Colors.white.withValues(alpha: 0.5), size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.nunito(
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              );
            }
            return GoogleFonts.nunito(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            );
          }),
        ),
        iconTheme: IconThemeData(color: AppColors.neonCyan),
        dividerTheme: DividerThemeData(
          color: AppColors.neonCyan.withValues(alpha: 0.1),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDark,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: AppColors.neonCyan.withValues(alpha: 0.2)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.backgroundDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.neonCyan.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.neonCyan.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.neonCyan, width: 1.5),
          ),
          labelStyle: TextStyle(
              color: AppColors.neonCyan.withValues(alpha: 0.7)),
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3)),
        ),
      );
}
