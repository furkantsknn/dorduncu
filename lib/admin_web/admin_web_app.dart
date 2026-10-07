import 'package:flutter/material.dart';

import 'admin_auth_gate.dart';

class DorduncuAdminWebApp extends StatelessWidget {
  const DorduncuAdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dört. Yönetim',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffFF9800),
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}
