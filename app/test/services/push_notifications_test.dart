import 'dart:async';
import 'dart:convert';

import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/notifications/push_messaging.dart';
import 'package:coco_rider/services/notifications/push_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeMessaging implements PushMessaging {
  bool available = true;
  bool deleted = false;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushEvent>.broadcast();
  final opened = StreamController<PushEvent>.broadcast();
  PushEvent? initial;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<String?> getToken() async => 'token-1';

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushEvent> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushEvent> get onOpened => opened.stream;

  @override
  Future<PushEvent?> getInitialMessage() async => initial;

  @override
  Future<void> deleteToken() async => deleted = true;
}

void main() {
  late List<String> calls;
  late FakeMessaging messaging;
  late List<PushEvent> shown;
  late List<PushEvent> openedEvents;

  PushNotifications create() {
    calls = [];
    shown = [];
    openedEvents = [];
    final api = CocoApi(
      baseUrl: 'https://api.test',
      authHeaders: () async => {},
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path} ${request.body}');
        return http.Response('', 204);
      }),
    );
    return PushNotifications(messaging: messaging, api: api, onForeground: shown.add, onOpen: openedEvents.add);
  }

  setUp(() => messaging = FakeMessaging());

  test('registers the token after sign-in and when it changes', () async {
    final push = create();

    await push.start();
    await push.start(); // Idempotent.
    messaging.refresh.add('token-2');
    await Future<void>.delayed(Duration.zero);

    expect(calls, [
      'PUT /v1/me/devices ${jsonEncode({'token': 'token-1', 'platform': 'Android'})}',
      'PUT /v1/me/devices ${jsonEncode({'token': 'token-2', 'platform': 'Android'})}',
    ]);
  });

  test('routes foreground and tapped notifications', () async {
    messaging.initial = const PushEvent(data: {'tripId': 'trip-0'});
    final push = create();
    await push.start();

    messaging.foreground.add(const PushEvent(title: 'Nouvelle demande', data: {'tripId': 'trip-1'}));
    messaging.opened.add(const PushEvent(data: {'tripId': 'trip-2'}));
    await Future<void>.delayed(Duration.zero);

    expect(shown.single.title, 'Nouvelle demande');
    expect(openedEvents.map((e) => e.tripId), ['trip-0', 'trip-2']);
  });

  test('unregisters the phone on sign-out', () async {
    final push = create();
    await push.start();

    await push.stop();

    expect(calls.last, startsWith('DELETE /v1/me/devices/token-1'));
    expect(messaging.deleted, isTrue);
  });

  test('does nothing when notifications are unavailable or refused', () async {
    messaging.available = false;
    final push = create();

    await push.start();
    await push.stop();

    expect(calls, isEmpty);
  });
}
