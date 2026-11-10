import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_model.dart';

final pushGatewayProvider = Provider<PushGateway>(
  (ref) => FirebasePushGateway(),
);

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // FCM notification+data payloads are displayed by Android/iOS while backgrounded.
}

abstract class PushGateway {
  Future<bool> initialize();
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get tokenChanges;
  Stream<AppNotification> get foreground;
  Stream<AppNotification> get opened;
  Future<AppNotification?> initial();
}

class FirebasePushGateway implements PushGateway {
  bool _available = false;
  Future<bool>? _initialization;

  @override
  Future<bool> initialize() => _initialization ??= _initialize();

  Future<bool> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      _available = true;
      return true;
    } catch (_) {
      // Missing native Firebase configuration must not prevent login or in-app realtime.
      return false;
    }
  }

  @override
  Future<String?> token() async {
    if (!_available) return null;
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
    // firebase_messaging 17 delivers the FID through onRegistered after register().
    await FirebaseMessaging.instance.register();
    return null;
  }

  @override
  Future<void> deleteToken() async {
    if (await initialize()) await FirebaseMessaging.instance.unregister();
  }

  @override
  Stream<String> get tokenChanges => FirebaseMessaging.instance.onRegistered;

  AppNotification _notification(RemoteMessage m) => AppNotification.fromJson({
    ...m.data,
    'title': m.notification?.title ?? 'Thông báo mới',
    'body': m.notification?.body ?? '',
  });

  @override
  Stream<AppNotification> get foreground => FirebaseMessaging.onMessage
      .where((m) => m.data.containsKey('notificationId'))
      .map(_notification);

  @override
  Stream<AppNotification> get opened => FirebaseMessaging.onMessageOpenedApp
      .where((m) => m.data.containsKey('notificationId'))
      .map(_notification);

  @override
  Future<AppNotification?> initial() async {
    final m = await FirebaseMessaging.instance.getInitialMessage();
    return m == null || !m.data.containsKey('notificationId')
        ? null
        : _notification(m);
  }
}
