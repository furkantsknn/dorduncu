import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../admin/admin_access.dart';

class AdminSessionGuard extends StatefulWidget {
  const AdminSessionGuard({required this.child, super.key});

  final Widget child;

  @override
  State<AdminSessionGuard> createState() => _AdminSessionGuardState();
}

class _AdminSessionGuardState extends State<AdminSessionGuard>
    with WidgetsBindingObserver {
  static const Duration _idleTimeout = Duration(minutes: 30);
  static const Duration _claimsRefreshInterval = Duration(minutes: 5);

  Timer? _securityTimer;
  DateTime _lastActivity = DateTime.now();
  DateTime _lastClaimsRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  bool _checking = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    _securityTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkSecurity(),
    );

    unawaited(_checkSecurity(forceClaimsRefresh: true));
  }

  @override
  void dispose() {
    _securityTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkSecurity(forceClaimsRefresh: true));
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    _markActivity();
    return false;
  }

  void _markActivity() {
    if (_signingOut) {
      return;
    }

    _lastActivity = DateTime.now();
  }

  Future<void> _checkSecurity({bool forceClaimsRefresh = false}) async {
    if (_checking || _signingOut) {
      return;
    }

    _checking = true;

    try {
      final DateTime now = DateTime.now();

      if (now.difference(_lastActivity) >= _idleTimeout) {
        await _signOut();
        return;
      }

      final bool shouldRefreshClaims =
          forceClaimsRefresh ||
          now.difference(_lastClaimsRefresh) >= _claimsRefreshInterval;

      if (!shouldRefreshClaims) {
        return;
      }

      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await user.reload();

      final User? current = FirebaseAuth.instance.currentUser;

      if (current == null) {
        return;
      }

      final IdTokenResult token = await current.getIdTokenResult(true);

      final List<MultiFactorInfo> factors = await current.multiFactor
          .getEnrolledFactors();

      _lastClaimsRefresh = now;

      if (!AdminAccess.canAccessPanel(token.claims) || factors.isEmpty) {
        await _signOut();
      }
    } on FirebaseAuthException {
      // Temporary auth/network errors do not destroy an active session.
      // The next scheduled security check retries with a fresh token.
    } finally {
      _checking = false;
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) {
      return;
    }

    _signingOut = true;

    try {
      await FirebaseAuth.instance.signOut();
    } finally {
      _signingOut = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markActivity(),
      onPointerMove: (_) => _markActivity(),
      onPointerSignal: (_) => _markActivity(),
      child: widget.child,
    );
  }
}
