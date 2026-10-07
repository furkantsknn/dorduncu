import 'package:flutter/material.dart';

import 'admin_access.dart';

class AdminPermissionGate extends StatelessWidget {
  const AdminPermissionGate({
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    super.key,
  });

  final AdminPermission permission;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AdminAccess.currentClaims(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot,
          ) {
            if (!snapshot.hasData) {
              return fallback;
            }

            if (!AdminAccess.hasPermission(snapshot.data, permission)) {
              return fallback;
            }

            return child;
          },
    );
  }
}

class AdminRoleGate extends StatelessWidget {
  const AdminRoleGate({
    required this.allowedRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    super.key,
  });

  final Set<String> allowedRoles;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AdminAccess.currentClaims(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot,
          ) {
            if (!snapshot.hasData) {
              return fallback;
            }

            final String role = AdminAccess.roleFromClaims(snapshot.data);

            if (!allowedRoles.contains(role)) {
              return fallback;
            }

            return child;
          },
    );
  }
}
