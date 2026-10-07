import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { turkish, english, german }

class LanguageController {
  LanguageController._();

  static const String _storageKey = 'app_language';

  static final ValueNotifier<Locale> locale =
  ValueNotifier<Locale>(const Locale('tr'));

  static final ValueNotifier<AppLanguage> language =
  ValueNotifier<AppLanguage>(AppLanguage.turkish);

  static Future<void> _languageWrite = Future<void>.value();

  static Future<void> initialize() async {
    final SharedPreferencesAsync preferences = SharedPreferencesAsync();
    final String? storedValue = await preferences.getString(_storageKey);
    final AppLanguage selectedLanguage = _fromStorage(storedValue);
    final Locale selectedLocale = _toLocale(selectedLanguage);

    if (language.value != selectedLanguage) {
      language.value = selectedLanguage;
    }

    if (locale.value != selectedLocale) {
      locale.value = selectedLocale;
    }
  }

  static Future<void> setLanguage(AppLanguage selectedLanguage) async {
    if (language.value == selectedLanguage) {
      return;
    }

    final Future<void> previousWrite = _languageWrite;
    final Completer<void> completer = Completer<void>();
    _languageWrite = completer.future;

    await previousWrite;

    try {
      final SharedPreferencesAsync preferences = SharedPreferencesAsync();

      await preferences.setString(
        _storageKey,
        selectedLanguage.name,
      );

      final Locale selectedLocale = _toLocale(selectedLanguage);

      if (language.value != selectedLanguage) {
        language.value = selectedLanguage;
      }

      if (locale.value != selectedLocale) {
        locale.value = selectedLocale;
      }
    } finally {
      completer.complete();
    }
  }

  static AppLanguage _fromStorage(String? value) {
    return AppLanguage.values.firstWhere(
          (AppLanguage item) => item.name == value,
      orElse: () => AppLanguage.turkish,
    );
  }

  static Locale _toLocale(AppLanguage selectedLanguage) {
    switch (selectedLanguage) {
      case AppLanguage.turkish:
        return const Locale('tr');
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.german:
        return const Locale('de');
    }
  }
}
