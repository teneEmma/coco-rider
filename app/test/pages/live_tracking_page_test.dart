import 'dart:convert';

import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/tracking/live_tracking_page.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> tracking({Map<String, dynamic>? position}) => {
      'tripId': 't1',
      'tripStatus': 'Scheduled',
      'destination': {'city': 'Yaoundé', 'landmark': 'Total Mvan', 'latitude': 3.85, 'longitude': 11.5},
      'position': position,
    };

void main() {
  setUpAll(() => initializeDateFormatting());
  tearDown(Get.reset);

  testWidgets('shows when the driver starts sharing and how far they are', (tester) async {
    var calls = 0;
    Get.put(CocoApi(
      baseUrl: 'https://api.test',
      authHeaders: () async => {},
      httpClient: MockClient((request) async {
        calls++;
        final body = calls == 1
            ? tracking()
            : tracking(position: {
                'latitude': 3.8,
                'longitude': 10.13,
                'heading': 90,
                'speedKmh': 72,
                'recordedAt': '2026-10-05T06:00:00Z',
                'isLive': true,
                'distanceToDestinationKm': 152.4,
              });
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    ));

    await tester.pumpWidget(GetMaterialApp(
      translations: CocoInternalization(),
      locale: const Locale('fr', 'CM'),
      getPages: [
        GetPage(name: '/tracking', page: () => const LiveTrackingPage(refreshEvery: Duration(seconds: 1), showMap: false)),
      ],
      home: const Scaffold(),
    ));
    Get.toNamed('/tracking', arguments: 't1');
    await tester.pumpAndSettle();

    expect(find.text("Le conducteur n'a pas encore commencé à partager sa position."), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Position en direct'), findsOneWidget);
    expect(find.text("À 152.4 km de Yaoundé (à vol d'oiseau)"), findsOneWidget);
    expect(find.text('Partager avec un proche'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();
  });
}
