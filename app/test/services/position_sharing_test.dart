import 'dart:convert';

import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/tracking/position_sharing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeLocation implements LocationProvider {
  bool allowed = true;
  int fixes = 0;

  @override
  Future<bool> ensurePermission() async => allowed;

  /// The car moves east along the Douala–Yaoundé road, one step per fix.
  @override
  Future<GeoFix> current() async => GeoFix(
      latitude: 3.81, longitude: 10.13 + 0.01 * fixes++, speedKmh: 72, time: DateTime.utc(2026, 10, 5, 6, 0));
}

void main() {
  late List<http.Request> requests;
  late FakeLocation location;
  http.Response Function(http.Request) respond = (_) => http.Response('', 204);

  setUpAll(() {
    Get.addTranslations(CocoInternalization().keys);
    Get.locale = const Locale('fr', 'CM');
  });

  PositionSharing create() {
    requests = [];
    location = FakeLocation();
    return PositionSharing(
      api: CocoApi(
        baseUrl: 'https://api.test',
        authHeaders: () async => {},
        httpClient: MockClient((r) async {
          requests.add(r);
          return respond(r);
        }),
      ),
      location: location,
      every: const Duration(milliseconds: 20),
    );
  }

  setUp(() => respond = (_) => http.Response('', 204));

  test('sends the position right away and then periodically, until stopped', () async {
    final sharing = create();

    expect(await sharing.start('trip-1'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await sharing.stop();

    final puts = requests.where((r) => r.method == 'PUT').toList();
    expect(puts.length, greaterThanOrEqualTo(3));
    expect(puts.first.url.path, '/v1/trips/trip-1/position');
    expect(jsonDecode(puts.first.body), {
      'latitude': 3.81,
      'longitude': 10.13,
      'heading': null,
      'speedKmh': 72.0,
      'recordedAt': '2026-10-05T06:00:00.000Z',
    });
    expect(requests.last.method, 'DELETE');
    expect(sharing.sharingTripId.value, isNull);

    final count = requests.length;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(requests.length, count, reason: 'no more positions after stop');
  });

  test('does not start without the location permission', () async {
    final sharing = create();
    location.allowed = false;

    expect(await sharing.start('trip-1'), isFalse);
    expect(sharing.error.value, "Autorisez l'accès à la position pour la partager.");
    expect(requests, isEmpty);
  });

  test('stops when the server says sharing is not possible anymore', () async {
    final sharing = create();
    respond = (_) => http.Response(jsonEncode({'code': 'tracking.not_active', 'detail': 'Too early'}), 409);

    expect(await sharing.start('trip-1'), isFalse);
    expect(sharing.sharingTripId.value, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(requests.length, 1);
  });
}
