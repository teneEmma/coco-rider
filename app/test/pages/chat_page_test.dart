import 'dart:convert';

import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/chat/chat_page.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> message(String id, String body, {bool fromMe = false, String at = '2026-10-01T08:00:00Z'}) =>
    {'id': id, 'fromMe': fromMe, 'body': body, 'sentAt': at, 'readAt': null};

void main() {
  setUpAll(() => initializeDateFormatting());
  tearDown(Get.reset);

  testWidgets('shows the conversation, polls for new messages and sends', (tester) async {
    final requests = <http.Request>[];
    var polls = 0;
    Get.put(CocoApi(
      baseUrl: 'https://api.test',
      authHeaders: () async => {},
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(jsonEncode(message('m3', jsonDecode(request.body)['body'], fromMe: true, at: '2026-10-01T08:02:00Z')), 201);
        }
        polls++;
        final messages = polls == 1
            ? [message('m1', 'Bonjour, je serai au carrefour.')]
            : [message('m2', 'Parfait, à demain !', at: '2026-10-01T08:01:00Z')];
        return http.Response.bytes(utf8.encode(jsonEncode({
          'bookingId': 'b1',
          'tripId': 't1',
          'with': {'id': 'u2', 'firstName': 'Paul'},
          'canWrite': true,
          'messages': messages,
        })), 200);
      }),
    ));

    await tester.pumpWidget(GetMaterialApp(
      translations: CocoInternalization(),
      locale: const Locale('fr', 'CM'),
      getPages: [GetPage(name: '/chat', page: () => const ChatPage(refreshEvery: Duration(seconds: 1)))],
      home: const Scaffold(),
    ));
    Get.toNamed('/chat', arguments: 'b1');
    await tester.pumpAndSettle();

    expect(find.text('Paul'), findsOneWidget);
    expect(find.text('Bonjour, je serai au carrefour.'), findsOneWidget);

    // The next poll only asks for messages after the last one received.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Parfait, à demain !'), findsOneWidget);
    expect(requests[1].url.queryParameters['after'], '2026-10-01T08:00:00.000Z');

    await tester.enterText(find.byType(TextField), 'Merci');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Merci'), findsOneWidget);
    expect(jsonDecode(requests.firstWhere((r) => r.method == 'POST').body), {'body': 'Merci'});

    // Leaving the page stops the polling timer.
    Get.back();
    await tester.pumpAndSettle();
  });
}
