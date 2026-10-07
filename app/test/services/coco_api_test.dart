import 'dart:convert';

import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers.dart';

void main() {
  late List<http.Request> requests;

  CocoApi apiReturning(http.Response Function(http.Request) handler) {
    requests = [];
    return CocoApi(
      baseUrl: 'https://api.test',
      authHeaders: () async => {'Authorization': 'Bearer token'},
      httpClient: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

  test('searches trips by city and parses them', () async {
    final api = apiReturning((_) => json([tripJson()]));

    final trips = await api.searchTrips(TripSearch(date: DateTime(2026, 10, 3), fromCity: 'Douala', toCity: 'Yaoundé', seats: 2));

    expect(requests.single.url.path, '/v1/trips/search');
    expect(requests.single.url.queryParameters, {'date': '2026-10-03', 'seats': '2', 'fromCity': 'Douala', 'toCity': 'Yaoundé'});
    expect(requests.single.headers['Authorization'], 'Bearer token');
    expect(trips.single.destination.city, 'Yaoundé');
    expect(trips.single.driver.rating, 4.7);
    expect(trips.single.vehicle, 'Toyota Corolla Grise');
  });

  test('date and seats are optional filters', () async {
    final api = apiReturning((_) => json([]));

    await api.searchTrips(const TripSearch(toCity: 'Kribi'));

    expect(requests.single.url.queryParameters, {'toCity': 'Kribi'});
  });

  test('sends enums in the API spelling', () async {
    final api = apiReturning((_) => json({
          'id': 'b1',
          'status': 'Confirmed',
          'seats': 2,
          'paymentMethod': 'MtnMobileMoney',
          'totalPriceXaf': 10000,
          'trip': tripJson(),
          'driverPhone': '+237677000002',
          'createdAt': '2026-10-01T08:00:00Z',
        }, 201));

    final booking = await api.book('trip-1', seats: 2, paymentMethod: PaymentMethod.mtnMobileMoney);

    expect(jsonDecode(requests.single.body), {'seats': 2, 'paymentMethod': 'MtnMobileMoney'});
    expect(booking.status, BookingStatus.confirmed);
    expect(booking.driverPhone, '+237677000002');
  });

  test('returns the stable error code', () async {
    final api = apiReturning((_) => json({
          'status': 409,
          'code': 'booking.cancellation_window_closed',
          'detail': 'Bookings cannot be cancelled less than 24 hours before departure.',
        }, 409));

    expect(
      () => api.cancelBooking('b1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'booking.cancellation_window_closed')),
    );
  });

  test('a missing profile means the user must create it', () async {
    final api = apiReturning((_) => json({'code': 'profile.not_found', 'detail': 'Create your profile first.'}, 404));

    expect(await api.getProfile(), isNull);
  });

  test('uploads the photo to the pre-signed URL, then submits it', () async {
    final api = apiReturning((request) {
      if (request.url.host == 's3.test') return http.Response('', 200);
      if (request.url.path.endsWith('/submit')) {
        return json({'id': 'd1', 'type': 'DriverLicence', 'status': 'Accepted', 'expiresOn': '2028-01-31', 'reviewNote': null});
      }
      return json({'documentId': 'd1', 'uploadUrl': 'https://s3.test/key', 'contentType': 'image/jpeg', 'uploadUrlExpiresAt': '2026-10-01T08:10:00Z'});
    });

    final document = await api.uploadDocument(
      type: DocumentType.driverLicence,
      bytes: utf8.encode('jpeg'),
      contentType: 'image/jpeg',
      expiresOn: DateTime(2028, 1, 31),
    );

    expect(requests.map((r) => '${r.method} ${r.url.host}${r.url.path}'), [
      'POST api.test/v1/me/documents',
      'PUT s3.test/key',
      'POST api.test/v1/me/documents/d1/submit',
    ]);
    expect(jsonDecode(requests[0].body), {'type': 'DriverLicence', 'contentType': 'image/jpeg'});
    expect(requests[1].headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(requests[2].body), {'expiresOn': '2028-01-31'});
    expect(document.status, DocumentStatus.accepted);
  });
}
