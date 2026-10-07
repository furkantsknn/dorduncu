import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_access.dart';
import '../admin/admin_panel_screen.dart';
import 'admin_login_screen.dart';
import 'admin_mfa_enrollment_screen.dart';
import 'admin_session_guard.dart';

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  Future<_State> _load(User user) async {
    await user.reload();

    final User current = FirebaseAuth.instance.currentUser ?? user;

    final IdTokenResult token = await current.getIdTokenResult(true);

    final List<MultiFactorInfo> factors = await current.multiFactor
        .getEnrolledFactors();

    return _State(token.claims, factors.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? user = snapshot.data;

        if (user == null) {
          return const AdminLoginScreen();
        }

        return FutureBuilder<_State>(
          future: _load(user),
          builder: (BuildContext context, AsyncSnapshot<_State> state) {
            if (state.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final _State? value = state.data;

            if (value == null || !AdminAccess.canAccessPanel(value.claims)) {
              return const _Denied();
            }

            if (!value.hasMfa) {
              return const AdminMfaEnrollmentScreen();
            }

            return const AdminSessionGuard(child: AdminPanelScreen());
          },
        );
      },
    );
  }
}

class _State {
  const _State(this.claims, this.hasMfa);

  final Map<String, dynamic>? claims;
  final bool hasMfa;
}

class _Denied extends StatelessWidget {
  const _Denied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton.icon(
          onPressed: FirebaseAuth.instance.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Yetkisiz hesap - çıkış yap'),
        ),
      ),
    );
  }
}
