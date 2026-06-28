import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier()
      : super(
          StorageService.getThemeMode() == 'dark'
              ? ThemeMode.dark
              : ThemeMode.light,
        );

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    StorageService.saveThemeMode(state == ThemeMode.dark ? 'dark' : 'light');
  }

  void setMode(ThemeMode mode) {
    state = mode;
    StorageService.saveThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeModeProvider) == ThemeMode.dark;
});
