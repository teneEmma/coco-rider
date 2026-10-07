import 'dart:async';

import 'package:coco_rider/services/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// A notification received from the backend (see NotificationKind in the API).
class PushEvent {
  final String? title;
  final String? body;
  final Map<String, String> data;

  const PushEvent({this.title, this.body, this.data = const {}});

  String? get tripId => data['tripId'];

  factory PushEvent.fromRemote(RemoteMessage message) => PushEvent(
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data.map((key, value) => MapEntry(key, '$value')),
      );
}

/// The push-notification provider, behind an interface so the app logic can be tested.
abstract class PushMessaging {
  /// Returns false when push notifications are not available (web, no Firebase, refused).
  Future<bool> initialize();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// Notifications received while the app is open.
  Stream<PushEvent> get onForegroundMessage;

  /// Notifications tapped while the app was in the background.
  Stream<PushEvent> get onOpened;

  /// The notification that launched the app, if any.
  Future<PushEvent?> getInitialMessage();

  Future<void> deleteToken();
}

/// Firebase Cloud Messaging on Android and iOS.
class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> initialize() async {
    // Web push needs a VAPID key and a service worker; the web build is only used for testing.
    if (kIsWeb) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      final settings = await _messaging.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('Push notifications unavailable: $e');
      return false;
    }
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushEvent> get onForegroundMessage => FirebaseMessaging.onMessage.map(PushEvent.fromRemote);

  @override
  Stream<PushEvent> get onOpened => FirebaseMessaging.onMessageOpenedApp.map(PushEvent.fromRemote);

  @override
  Future<PushEvent?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushEvent.fromRemote(message);
  }

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}
