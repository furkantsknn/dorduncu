import 'package:flutter/material.dart';

import '../admin/admin_access.dart';
import '../admin/admin_panel_screen.dart';

/// Shows the in-app Admin Paneli entry from Auth custom claims only.
///
/// The separate admin web sign-in (email, password, SMS MFA) is unchanged.
class AppAdminMenuEntry extends StatefulWidget {
  const AppAdminMenuEntry({required this.builder, super.key});

  final Widget Function(BuildContext context, VoidCallback openAdminPanel)
  builder;

  static String label(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
      case 'en':
        return 'Admin Panel';
      case 'de':
        return 'Admin-Bereich';
      default:
        return 'Admin Paneli';
    }
  }

  @override
  State<AppAdminMenuEntry> createState() => _AppAdminMenuEntryState();
}

class _AppAdminMenuEntryState extends State<AppAdminMenuEntry> {
  late final Future<Map<String, dynamic>?> _claims = _loadClaims();

  Future<Map<String, dynamic>?> _loadClaims() async {
    try {
      return await AdminAccess.currentClaims(forceRefresh: true);
    } catch (_) {
      return AdminAccess.currentClaims();
    }
  }

  void _openAdminPanel() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdminPanelScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _claims,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }

            if (!AdminAccess.showsAppAdminMenu(snapshot.data)) {
              return const SizedBox.shrink();
            }

            return widget.builder(context, _openAdminPanel);
          },
    );
  }
}
