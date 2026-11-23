import 'package:flutter/material.dart';

import 'admin_auth_gate.dart';

class DorduncuAdminWebApp extends StatelessWidget {
  const DorduncuAdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dört. Yönetim',
      theme: _adminTheme(Brightness.light),
      darkTheme: _adminTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const AdminAuthGate(),
    );
  }

  ThemeData _adminTheme(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final Color background = dark
        ? const Color(0xff0F1115)
        : const Color(0xffF3F1EC);
    final Color surface = dark
        ? const Color(0xff1C2028)
        : const Color(0xffFFFCF8);
    final Color line = dark ? const Color(0xff343A46) : const Color(0xffE0DBD1);
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xffFF9800),
      brightness: brightness,
      surface: surface,
    );
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: line),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: line),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
