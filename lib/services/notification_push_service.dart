import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/event_chat_screen.dart';
import '../screens/event_detail_screen.dart';
import '../screens/notification_center_screen.dart';
import 'language_controller.dart';
import 'notification_service.dart';

class NotificationPushService {
  NotificationPushService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static GlobalKey<NavigatorState>? _navigatorKey;
  static RemoteMessage? _pendingNavigationMessage;
  static bool _initialized = false;
  static bool _navigationBusy = false;
  static bool _homeReady = false;
  static String _visibleChatEventId = '';
  static final Set<String> _handledForegroundIds = <String>{};

  static void setVisibleChat(String? eventId) {
    _visibleChatEventId = eventId?.trim() ?? '';
  }

  /// Splash `pushReplacement` ile üstteki rotayı değiştirir; bildirim rotası
  /// ancak gerçek kabuk (`HomeScreen`) açıldıktan sonra itilir.
  static void markHomeReady() {
    _homeReady = true;
    ensurePermissionAndRegister();
    flushPendingNavigation();
  }

  static void markHomeClosed() {
    _homeReady = false;
  }

  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized) {
      _navigatorKey = navigatorKey;
      return;
    }

    _initialized = true;
    _navigatorKey = navigatorKey;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
      } catch (error) {
        debugPrint('APNs foreground presentation options failed: $error');
      }
    }

    _messaging.onTokenRefresh.listen(
      (String token) async {
        final User? user = _auth.currentUser;

        if (user == null) {
          return;
        }

        await _registerToken(token);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh failed: $error');
      },
    );

    _auth.authStateChanges().listen(
      (User? user) async {
        if (user == null) {
          try {
            await _messaging.deleteToken();
          } catch (error) {
            debugPrint('FCM token cleanup failed: $error');
          }
          return;
        }

        await flushPendingNavigation();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM auth listener failed: $error');
      },
    );

    FirebaseMessaging.onMessage.listen(
      _showForegroundMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM foreground listener failed: $error');
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) async {
        _pendingNavigationMessage = message;
        await flushPendingNavigation();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM open listener failed: $error');
      },
    );

    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _pendingNavigationMessage = initialMessage;
    }
  }

  static Future<void> flushPendingNavigation() async {
    if (_navigationBusy) {
      return;
    }

    final RemoteMessage? message = _pendingNavigationMessage;
    final NavigatorState? navigator = _navigatorKey?.currentState;

    if (message == null ||
        navigator == null ||
        !_homeReady ||
        _auth.currentUser == null) {
      return;
    }

    _navigationBusy = true;

    try {
      final bool opened = await _openMessage(
        navigator: navigator,
        message: message,
      );

      if (opened) {
        _pendingNavigationMessage = null;
      }
    } catch (error) {
      debugPrint('FCM navigation failed: $error');
    } finally {
      _navigationBusy = false;
    }
  }

  /// Uygulama açıkken Android sistem bildirimi göstermez. Sessiz bir uygulama
  /// içi uyarı gösterilir; ses ve titreşim yalnız sistem kanalındadır.
  static void _showForegroundMessage(RemoteMessage message) {
    final BuildContext? context = _navigatorKey?.currentContext;
    if (!_homeReady || context == null || _auth.currentUser == null) {
      return;
    }
    final String notificationId = _text(message.data['notificationId']);
    if (notificationId.isNotEmpty &&
        !_handledForegroundIds.add(notificationId)) {
      return;
    }
    final String route = _text(message.data['route']).toLowerCase();
    final String eventId = _text(message.data['eventId']);
    if ((route == 'event_chat' || route == 'eventchat') &&
        eventId.isNotEmpty &&
        eventId == _visibleChatEventId) {
      return;
    }
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final String title = _text(message.notification?.title);
    final String body = _text(message.notification?.body);
    if (messenger == null || (title.isEmpty && body.isEmpty)) {
      return;
    }
    final String open = switch (LanguageController.language.value) {
      AppLanguage.turkish => 'Aç',
      AppLanguage.english => 'Open',
      AppLanguage.german => 'Öffnen',
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            title.isEmpty || body.isEmpty ? '$title$body' : '$title\n$body',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: open,
            onPressed: () {
              _pendingNavigationMessage = message;
              flushPendingNavigation();
            },
          ),
        ),
      );
  }

  static Future<bool> ensurePermissionAndRegister() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    try {
      NotificationSettings settings = await _messaging
          .getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
        );
      }

      final bool authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!authorized) {
        return false;
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final String? apnsToken = await _waitForApnsToken();
        if (apnsToken == null || apnsToken.trim().isEmpty) {
          // APNs token may arrive asynchronously after launch; onTokenRefresh
          // will register the FCM token as soon as APNs completes.
          return false;
        }
      }

      final String? token = await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        return false;
      }

      await _registerToken(token);

      return true;
    } catch (error) {
      debugPrint('FCM registration failed: $error');
      return false;
    }
  }

  static Future<void> unregisterCurrentToken() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null || apnsToken.trim().isEmpty) {
          return;
        }
      }

      final String? token = await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        return;
      }

      final HttpsCallable callable = _functions.httpsCallable(
        'unregisterNotificationDevice',
      );

      await callable.call<void>(<String, dynamic>{'token': token});

      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('FCM unregister failed: $error');
    }
  }

  static Future<bool> _openMessage({
    required NavigatorState navigator,
    required RemoteMessage message,
  }) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);

    final String route = _text(data['route']).toLowerCase();
    final String eventId = _text(data['eventId']);
    final String notificationId = _text(data['notificationId']);

    if (eventId.isEmpty) {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const NotificationCenterScreen(),
        ),
      );
      return true;
    }

    if (route == 'event_chat' || route == 'eventchat') {
      final DocumentSnapshot<Map<String, dynamic>> eventSnapshot =
          await _firestore.collection('events').doc(eventId).get();

      final Map<String, dynamic>? eventData = eventSnapshot.data();

      if (!eventSnapshot.exists || eventData == null) {
        return false;
      }

      final String suppliedTitle = _text(data['eventTitle']);
      final String eventTitle = suppliedTitle.isNotEmpty
          ? suppliedTitle
          : _eventTitle(eventData);

      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              EventChatScreen(eventId: eventId, eventTitle: eventTitle),
        ),
      );

      await _markNotificationRead(notificationId);
      return true;
    }

    final DocumentSnapshot<Map<String, dynamic>> eventSnapshot =
        await _firestore.collection('events').doc(eventId).get();

    final Map<String, dynamic>? eventData = eventSnapshot.data();

    if (!eventSnapshot.exists || eventData == null) {
      return false;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            EventDetailScreen(eventId: eventId, initialData: eventData),
      ),
    );

    await _markNotificationRead(notificationId);
    return true;
  }

  static Future<void> _markNotificationRead(String notificationId) async {
    if (notificationId.isEmpty) {
      return;
    }

    try {
      await NotificationService.markRead(notificationId: notificationId);
    } catch (error) {
      debugPrint('Notification read update failed: $error');
    }
  }

  static String _eventTitle(Map<String, dynamic> data) {
    final List<dynamic> candidates = <dynamic>[
      data['oyun'],
      data['title'],
      data['eventTitle'],
    ];

    for (final dynamic candidate in candidates) {
      final String value = _text(candidate);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'Etkinlik';
  }

  static String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static Future<String?> _waitForApnsToken() async {
    for (int attempt = 0; attempt < 4; attempt++) {
      final String? apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.trim().isNotEmpty) {
        return apnsToken;
      }
      if (attempt < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return null;
  }

  static Future<void> _registerToken(String token) async {
    final String normalizedToken = token.trim();

    if (normalizedToken.isEmpty || _auth.currentUser == null) {
      return;
    }

    final HttpsCallable callable = _functions.httpsCallable(
      'registerNotificationDevice',
    );

    await callable.call<void>(<String, dynamic>{
      'token': normalizedToken,
      'platform': defaultTargetPlatform.name,
    });
  }
}
