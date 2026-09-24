import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/trips/trip_card.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  Future<void> pump(WidgetTester tester, Locale locale) => tester.pumpWidget(GetMaterialApp(
        translations: CocoInternalization(),
        locale: locale,
        home: Scaffold(body: TripCard(trip: Trip.fromJson(tripJson(seatsAvailable: 1)))),
      ));

  testWidgets('shows the trip in Cameroon time, in French', (tester) async {
    await pump(tester, const Locale('fr', 'CM'));

    // 06:30 UTC is 07:30 in Cameroon.
    expect(find.textContaining('07:30'), findsOneWidget);
    expect(find.text('5\u00A0000\u00A0FCFA'), findsOneWidget);
    expect(find.text('Douala · Carrefour Ndokoti'), findsOneWidget);
    expect(find.text('1 place(s) restante(s)'), findsOneWidget);
    expect(find.text('4.7 (12)'), findsOneWidget);
  });

  testWidgets('switches to English', (tester) async {
    await pump(tester, const Locale('en', 'CM'));

    expect(find.text('1 seat(s) left'), findsOneWidget);
  });
}
