import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options_admin.dart';
import 'admin_web_app.dart';

const String _siteKey = String.fromEnvironment(
  'ADMIN_RECAPTCHA_ENTERPRISE_SITE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }

  if (_siteKey.isEmpty) {
    throw StateError('ADMIN_RECAPTCHA_ENTERPRISE_SITE_KEY tanımlı değil.');
  }

  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaEnterpriseProvider(_siteKey),
  );

  runApp(const DorduncuAdminWebApp());
}
