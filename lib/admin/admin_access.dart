import 'package:firebase_auth/firebase_auth.dart';

enum AdminPermission {
  usersRead,
  usersModerate,
  verificationReview,
  supportManage,
  financeManage,
  eventsModerate,
  contentManage,
  notificationsManage,
  settingsManage,
  auditRead,
  reportsRead,
  rolesManage,
}

class AdminAccess {
  const AdminAccess._();

  static const Set<String> panelRoles = <String>{
    'moderator',
    'verification_officer',
    'support_officer',
    'finance_officer',
    'content_manager',
    'analyst',
    'admin',
    'super_admin',
  };

  static const Map<String, Set<AdminPermission>> _permissions =
      <String, Set<AdminPermission>>{
        'super_admin': <AdminPermission>{...AdminPermission.values},
        // Legacy role stays operational during the A7 migration.
        // Role assignment remains exclusive to super_admin.
        'admin': <AdminPermission>{
          AdminPermission.usersRead,
          AdminPermission.usersModerate,
          AdminPermission.verificationReview,
          AdminPermission.supportManage,
          AdminPermission.financeManage,
          AdminPermission.eventsModerate,
          AdminPermission.contentManage,
          AdminPermission.notificationsManage,
          AdminPermission.settingsManage,
          AdminPermission.auditRead,
          AdminPermission.reportsRead,
        },
        'moderator': <AdminPermission>{
          AdminPermission.usersRead,
          AdminPermission.usersModerate,
          AdminPermission.eventsModerate,
          AdminPermission.reportsRead,
        },
        'verification_officer': <AdminPermission>{
          AdminPermission.usersRead,
          AdminPermission.verificationReview,
        },
        'support_officer': <AdminPermission>{
          AdminPermission.usersRead,
          AdminPermission.supportManage,
        },
        'finance_officer': <AdminPermission>{
          AdminPermission.usersRead,
          AdminPermission.financeManage,
          AdminPermission.reportsRead,
        },
        'content_manager': <AdminPermission>{
          AdminPermission.contentManage,
          AdminPermission.notificationsManage,
        },
        'analyst': <AdminPermission>{AdminPermission.reportsRead},
      };

  static String roleFromClaims(Map<String, dynamic>? claims) {
    if (claims == null) {
      return 'user';
    }

    final String role = claims['role']?.toString().toLowerCase() ?? '';

    if (role == 'user' || panelRoles.contains(role)) {
      return role;
    }

    if (claims['admin'] == true) {
      return 'admin';
    }

    if (claims['moderator'] == true) {
      return 'moderator';
    }

    return 'user';
  }

  static bool canAccessPanel(Map<String, dynamic>? claims) {
    return panelRoles.contains(roleFromClaims(claims));
  }

  /// In-app Admin Paneli menu. Reads only the Auth custom claim role.
  static bool showsAppAdminMenu(Map<String, dynamic>? claims) {
    final String role = claims?['role']?.toString().toLowerCase() ?? '';
    return role == 'admin' || role == 'super_admin';
  }

  static bool hasPermission(
    Map<String, dynamic>? claims,
    AdminPermission permission,
  ) {
    final String role = roleFromClaims(claims);
    return _permissions[role]?.contains(permission) ?? false;
  }

  static Future<Map<String, dynamic>?> currentClaims({
    bool forceRefresh = false,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final IdTokenResult token = await user.getIdTokenResult(forceRefresh);
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) return null;

    return token.claims;
  }
}
