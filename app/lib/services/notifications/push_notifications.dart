import 'dart:async';

import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/notifications/push_messaging.dart';
import 'package:flutter/foundation.dart';

/// Connects the phone to the backend's notifications: registers the token after sign-in,
/// keeps it up to date, and routes notifications to the UI.
class PushNotifications {
  final PushMessaging messaging;
  final CocoApi api;

  /// Shows a notification received while the app is open (e.g. a snackbar).
  final void Function(PushEvent event) onForeground;

  /// Opens the screen a tapped notification is about.
  final void Function(PushEvent event) onOpen;

  PushNotifications({
    required this.messaging,
    required this.api,
    required this.onForeground,
    required this.onOpen,
  });

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _token;
  bool _started = false;

  /// Called once the user is signed in and has a profile. Safe to call several times.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      if (!await messaging.initialize()) return;

      _token = await messaging.getToken();
      if (_token != null) await api.registerDevice(_token!, _platform);

      _subscriptions
        ..add(messaging.onTokenRefresh.listen((token) async {
          _token = token;
          await _safely(() => api.registerDevice(token, _platform));
        }))
        ..add(messaging.onForegroundMessage.listen(onForeground))
        ..add(messaging.onOpened.listen(onOpen));

      final initial = await messaging.getInitialMessage();
      if (initial != null) onOpen(initial);
    } catch (e) {
      UtilityFunctions.debugPrint('Push notifications not started: $e', leadingIcons: '🔕');
    }
  }

  /// Called before sign-out so this phone stops receiving the account's notifications.
  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final token = _token;
    _token = null;
    _started = false;
    if (token != null) {
      await _safely(() => api.unregisterDevice(token));
      await _safely(messaging.deleteToken);
    }
  }

  static String get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'Ios',
        _ => kIsWeb ? 'Web' : 'Android',
      };

  static Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      UtilityFunctions.debugPrint('Push notification call failed: $e', leadingIcons: '🔕');
    }
  }
}
