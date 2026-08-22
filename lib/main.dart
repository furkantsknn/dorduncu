import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/account_status_screen.dart';
import 'screens/create_profile_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/language_controller.dart';
import 'services/theme_controller.dart';
import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  await ThemeController.initialize();
  await LanguageController.initialize();

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
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              onGenerateTitle: (context) =>
              AppLocalizations.of(context)!.appName,
              locale: locale,
              localizationsDelegates:
              AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              localeResolutionCallback: (
                  Locale? deviceLocale,
                  Iterable<Locale> supportedLocales,
                  ) {
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
              home: const SplashScreen(),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
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
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final User? user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<AuthDestination>(
          future: UserService.getAuthDestination(user: user),
          builder: (context, destinationSnapshot) {
            if (destinationSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
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
            );
          },
        );
      },
    );
  }

  Widget _destinationScreen(
      AuthDestination destination,
      AppLocalizations l10n,
      ) {
    switch (destination.type) {
      case AuthDestinationType.login:
        return const LoginScreen();

      case AuthDestinationType.createProfile:
        return const CreateProfileScreen();

      case AuthDestinationType.home:
        return HomeScreen(
          userName: destination.profileName,
        );

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