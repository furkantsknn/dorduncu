import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'admin/admin_panel_screen.dart';
import 'l10n/app_localizations.dart';
import 'screens/account_status_screen.dart';
import 'screens/create_profile_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/legal_acceptance_screen.dart';
import 'screens/splash_screen.dart';
import 'services/digital_purchase_service.dart';
import 'services/phone_verification_session.dart';
import 'services/language_controller.dart';
import 'services/notification_push_service.dart';
import 'services/theme_controller.dart';
import 'services/user_service.dart';
import 'widgets/app_update_gate.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const bool _isDevelopment = String.fromEnvironment('DORT_ENV') == 'development';
const String _firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDevelopment &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (_isDevelopment) {
    if (_firebaseEmulatorHost.trim().isEmpty) {
      throw StateError(
        'Dört. Dev requires FIREBASE_EMULATOR_HOST; production fallback is disabled.',
      );
    }
    await FirebaseAuth.instance.useAuthEmulator(
      _firebaseEmulatorHost,
      9099,
      automaticHostMapping: false,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      _firebaseEmulatorHost,
      8080,
      automaticHostMapping: false,
    );
    FirebaseFunctions.instanceFor(region: 'europe-west1').useFunctionsEmulator(
      _firebaseEmulatorHost,
      5001,
      automaticHostMapping: false,
    );
    await FirebaseStorage.instance.useStorageEmulator(
      _firebaseEmulatorHost,
      9199,
      automaticHostMapping: false,
    );
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
  }

  // The local emulator suite does not provide an App Check emulator. Activating
  // a debug provider here would exchange its token with the live App Check API,
  // which violates the Dev build's no-production-fallback boundary. Callable
  // App Check enforcement remains enabled in production; the Functions emulator
  // handles local calls without a live App Check token.
  if (!_isDevelopment) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }

  if (_isDevelopment) {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'admin@dev.dort.invalid',
      password: 'Dort-Dev-Only-2026',
    );
  }

  await ThemeController.initialize();
  await LanguageController.initialize();
  if (!_isDevelopment) {
    await NotificationPushService.initialize(navigatorKey: appNavigatorKey);
  }

  runApp(const DorduncuApp());
}

class DorduncuApp extends StatelessWidget {
  const DorduncuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LanguageController.locale,
          builder: (context, locale, child) {
            if (!_isDevelopment) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                NotificationPushService.flushPendingNavigation();
              });
            }

            return MaterialApp(
              navigatorKey: appNavigatorKey,
              debugShowCheckedModeBanner: false,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)!.appName,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              localeResolutionCallback:
                  (Locale? deviceLocale, Iterable<Locale> supportedLocales) {
                    for (final Locale supportedLocale in supportedLocales) {
                      if (supportedLocale.languageCode == locale.languageCode) {
                        return supportedLocale;
                      }
                    }

                    return AppLocalizations.supportedLocales.first;
                  },
              themeMode: themeMode,
              theme: _lightTheme(),
              darkTheme: _darkTheme(),
              home: _isDevelopment
                  ? (const String.fromEnvironment('DORT_DEV_HOME') == 'member'
                        ? const HomeScreen(userName: 'Dört Dev Yönetici')
                        : const AdminPanelScreen())
                  : const SplashScreen(),
              builder: (context, child) {
                final Widget content = child ?? const SizedBox.shrink();
                if (_isDevelopment) {
                  return Banner(
                    message: 'DEV • EMULATOR',
                    location: BannerLocation.topEnd,
                    color: const Color(0xffB42318),
                    child: content,
                  );
                }
                return AppUpdateGate(
                  navigatorKey: appNavigatorKey,
                  child: content,
                );
              },
            );
          },
        );
      },
    );
  }

  ThemeData _lightTheme() {
    const Color seed = Color(0xffFF9800);

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xffF7F6F2),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xffF7F6F2),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xffF7F6F2),
        foregroundColor: Color(0xff111827),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xffE0DBD1)),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xffFFFCF8),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffD8D3CA)),
        ),
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
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ThemeData _darkTheme() {
    const Color seed = Color(0xffFF9800);

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xff111318),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xff0F1115),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xff0F1115),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xff181B22),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xff343A46)),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xff1C2028),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff1C2028),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff343A46)),
        ),
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
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class AuthControl extends StatelessWidget {
  const AuthControl({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? user = snapshot.data;

        return ValueListenableBuilder<bool>(
          valueListenable: PhoneVerificationGate.codeEntryOpen,
          builder: (BuildContext context, bool codeEntryOpen, Widget? child) {
            if (user == null || codeEntryOpen) {
              return const LoginScreen();
            }

            return _SignedInPlayBilling(
              child: FutureBuilder<AuthDestination>(
                future: UserService.getAuthDestination(user: user),
                builder: (context, destinationSnapshot) {
                  if (destinationSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (destinationSnapshot.hasError ||
                      !destinationSnapshot.hasData) {
                    return AccountStatusScreen(
                      title: l10n.connectionError,
                      message: l10n.checkInternetConnection,
                      icon: Icons.cloud_off_outlined,
                    );
                  }

                  return _destinationScreen(
                    destinationSnapshot.data!,
                    l10n,
                    user,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _destinationScreen(
    AuthDestination destination,
    AppLocalizations l10n,
    User user,
  ) {
    switch (destination.type) {
      case AuthDestinationType.login:
        return const LoginScreen();

      case AuthDestinationType.createProfile:
        return const CreateProfileScreen();

      case AuthDestinationType.legalAcceptanceRequired:
        return const LegalAcceptanceScreen();

      case AuthDestinationType.home:
        return HomeScreen(userName: destination.profileName);

      case AuthDestinationType.suspended:
        return AccountStatusScreen(
          title: l10n.accountSuspended,
          message: l10n.accountSuspendedDescription,
          icon: Icons.pause_circle_outline,
        );

      case AuthDestinationType.banned:
        return AccountStatusScreen(
          title: l10n.accountBanned,
          message: l10n.accountBannedDescription,
          icon: Icons.block,
        );

      case AuthDestinationType.deletionRequested:
        return AccountStatusScreen(
          title: l10n.accountDeletionPending,
          message: l10n.accountDeletionPendingDescription,
          icon: Icons.hourglass_top,
        );

      case AuthDestinationType.deleted:
        return AccountStatusScreen(
          title: l10n.accountDeleted,
          message: l10n.accountDeletedDescription,
          icon: Icons.person_off_outlined,
        );

      case AuthDestinationType.sessionExpired:
        return AccountStatusScreen(
          title: l10n.sessionEnded,
          message: l10n.sessionEndedOnAnotherDevice,
          icon: Icons.phonelink_erase_outlined,
        );
    }
  }
}

class _SignedInPlayBilling extends StatefulWidget {
  const _SignedInPlayBilling({required this.child});

  final Widget child;

  @override
  State<_SignedInPlayBilling> createState() => _SignedInPlayBillingState();
}

class _SignedInPlayBillingState extends State<_SignedInPlayBilling> {
  @override
  void initState() {
    super.initState();
    if (!_isDevelopment) {
      DigitalPurchaseService.instance.attachSession();
    }
  }

  @override
  void dispose() {
    if (!_isDevelopment) {
      DigitalPurchaseService.instance.detachSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
