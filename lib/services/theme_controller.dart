import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { system, light, dark }

class ThemeController {
  ThemeController._();

  static const String _storageKey = 'app_theme_preference';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
  static final ValueNotifier<AppThemePreference> preference =
  ValueNotifier(AppThemePreference.system);

  static Future<void> initialize() async {
    final SharedPreferencesAsync preferences = SharedPreferencesAsync();
    final String? storedValue = await preferences.getString(_storageKey);
    final AppThemePreference selected = _fromStorage(storedValue);
    preference.value = selected;
    mode.value = _toThemeMode(selected);
  }

  static Future<void> setPreference(AppThemePreference selected) async {
    preference.value = selected;
    mode.value = _toThemeMode(selected);

    final SharedPreferencesAsync preferences = SharedPreferencesAsync();
    await preferences.setString(_storageKey, selected.name);
  }

  static AppThemePreference _fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
          (item) => item.name == value,
      orElse: () => AppThemePreference.system,
    );
  }

  static ThemeMode _toThemeMode(AppThemePreference selected) {
    switch (selected) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }
}
