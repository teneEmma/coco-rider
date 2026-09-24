import 'dart:convert';
import 'dart:typed_data';

import 'package:coco_rider/services/api/models.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// An error returned by the API. [code] is stable (e.g. "booking.cancellation_window_closed")
/// and is translated by the app; [message] is an English fallback.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  ApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Parameters of a trip search. Either a city or coordinates can be given for each end.
class TripSearch {
  final DateTime date;
  final String? fromCity;
  final String? toCity;
  final int seats;

  const TripSearch({required this.date, this.fromCity, this.toCity, this.seats = 1});
}

/// Client of the Coco Rider API.
class CocoApi {
  final String baseUrl;
  final Future<Map<String, String>> Function() _authHeaders;
  final http.Client _http;

  CocoApi({
    required this.baseUrl,
    required Future<Map<String, String>> Function() authHeaders,
    http.Client? httpClient,
  })  : _authHeaders = authHeaders,
        _http = httpClient ?? http.Client();

  // ---------- Profile ----------

  /// Returns null when the profile has not been created yet (right after sign-up).
  Future<Profile?> getProfile() async {
    try {
      return Profile.fromJson(await _send('GET', '/v1/me'));
    } on ApiException catch (e) {
      if (e.code == 'profile.not_found') return null;
      rethrow;
    }
  }

  Future<Profile> saveProfile({
    required String firstName,
    required String lastName,
    required Gender gender,
    required Language language,
  }) async =>
      Profile.fromJson(await _send('PUT', '/v1/me', {
        'firstName': firstName,
        'lastName': lastName,
        'gender': apiName(gender),
        'language': apiName(language),
      }));

  // ---------- Documents ----------

  Future<List<UserDocument>> getDocuments() async =>
      _list(await _send('GET', '/v1/me/documents'), UserDocument.fromJson);

  /// Uploads a photo and runs the automatic checks. Only JPEG and PNG are accepted.
  Future<UserDocument> uploadDocument({
    required DocumentType type,
    required Uint8List bytes,
    required String contentType,
    DateTime? expiresOn,
  }) async {
    final slot = UploadSlot.fromJson(await _send('POST', '/v1/me/documents', {
      'type': apiName(type),
      'contentType': contentType,
    }));

    final upload = await _http.put(
      slot.uploadUrl,
      headers: {'Content-Type': slot.contentType},
      body: bytes,
    );
    if (upload.statusCode >= 300) {
      throw ApiException(upload.statusCode, 'document.upload_failed', 'The photo could not be uploaded.');
    }

    return UserDocument.fromJson(await _send(
      'POST',
      '/v1/me/documents/${slot.documentId}/submit',
      {'expiresOn': expiresOn == null ? null : DateFormat('yyyy-MM-dd').format(expiresOn)},
    ));
  }

  // ---------- Vehicles ----------

  Future<List<Vehicle>> getVehicles() async =>
      _list(await _send('GET', '/v1/me/vehicles'), Vehicle.fromJson);

  Future<Vehicle> addVehicle({
    required String make,
    required String model,
    required String color,
    required String plateNumber,
    required int passengerSeats,
  }) async =>
      Vehicle.fromJson(await _send('POST', '/v1/me/vehicles', {
        'make': make,
        'model': model,
        'color': color,
        'plateNumber': plateNumber,
        'passengerSeats': passengerSeats,
      }));

  // ---------- Trips ----------

  Future<List<Trip>> searchTrips(TripSearch search) async {
    final query = <String, String>{
      'date': DateFormat('yyyy-MM-dd').format(search.date),
      'seats': '${search.seats}',
      if (search.fromCity != null && search.fromCity!.isNotEmpty) 'fromCity': search.fromCity!,
      if (search.toCity != null && search.toCity!.isNotEmpty) 'toCity': search.toCity!,
    };
    return _list(await _send('GET', '/v1/trips/search', null, query), Trip.fromJson);
  }

  Future<TripDetails> getTrip(String id) async =>
      TripDetails.fromJson(await _send('GET', '/v1/trips/$id'));

  Future<Trip> publishTrip({
    required String vehicleId,
    required TripKind kind,
    required Place origin,
    required Place destination,
    required DateTime departureAt,
    required int seats,
    required int pricePerSeatXaf,
    required bool womenOnly,
    required bool luggageAllowed,
    required bool smokingAllowed,
    required bool instantBooking,
    String? notes,
  }) async =>
      Trip.fromJson(await _send('POST', '/v1/trips', {
        'vehicleId': vehicleId,
        'kind': apiName(kind),
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'departureAt': departureAt.toUtc().toIso8601String(),
        'seats': seats,
        'pricePerSeatXaf': pricePerSeatXaf,
        'womenOnly': womenOnly,
        'luggageAllowed': luggageAllowed,
        'smokingAllowed': smokingAllowed,
        'instantBooking': instantBooking,
        'notes': notes,
      }));

  Future<List<Trip>> getMyTrips({bool past = false}) async =>
      _list(await _send('GET', '/v1/me/trips', null, {'past': '$past'}), Trip.fromJson);

  Future<void> cancelTrip(String id) => _send('POST', '/v1/trips/$id/cancel');

  Future<void> completeTrip(String id) => _send('POST', '/v1/trips/$id/complete');

  // ---------- Bookings ----------

  Future<Booking> book(String tripId, {required int seats, required PaymentMethod paymentMethod}) async =>
      Booking.fromJson(await _send('POST', '/v1/trips/$tripId/bookings', {
        'seats': seats,
        'paymentMethod': apiName(paymentMethod),
      }));

  Future<List<Booking>> getMyBookings() async =>
      _list(await _send('GET', '/v1/me/bookings'), Booking.fromJson);

  Future<void> cancelBooking(String id) => _send('POST', '/v1/bookings/$id/cancel');

  Future<void> acceptBooking(String id) => _send('POST', '/v1/bookings/$id/accept');

  Future<void> rejectBooking(String id) => _send('POST', '/v1/bookings/$id/reject');

  Future<void> reportNoShow(String id) => _send('POST', '/v1/bookings/$id/no-show');

  Future<void> review(String bookingId, {required int rating, String? comment}) =>
      _send('POST', '/v1/bookings/$bookingId/reviews', {'rating': rating, 'comment': comment});

  // ---------- Chat ----------

  /// Messages of a booking's conversation; with [after], only the newer ones (used for polling).
  Future<Conversation> getConversation(String bookingId, {DateTime? after}) async =>
      Conversation.fromJson(await _send('GET', '/v1/bookings/$bookingId/messages', null,
          after == null ? null : {'after': after.toUtc().toIso8601String()}));

  Future<ChatMessage> sendMessage(String bookingId, String body) async =>
      ChatMessage.fromJson(await _send('POST', '/v1/bookings/$bookingId/messages', {'body': body}));

  Future<List<ConversationSummary>> getConversations() async =>
      _list(await _send('GET', '/v1/me/conversations'), ConversationSummary.fromJson);

  // ---------- Push notifications ----------

  /// [platform] is "Android", "Ios" or "Web".
  Future<void> registerDevice(String token, String platform) =>
      _send('PUT', '/v1/me/devices', {'token': token, 'platform': platform});

  Future<void> unregisterDevice(String token) =>
      _send('DELETE', '/v1/me/devices/${Uri.encodeComponent(token)}');

  // ---------- Plumbing ----------

  static List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) parse) =>
      (json as List).map((item) => parse(item as Map<String, dynamic>)).toList();

  Future<dynamic> _send(String method, String path, [Object? body, Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll(await _authHeaders())
      ..headers['Accept'] = 'application/json';
    if (body != null || method == 'POST' || method == 'PUT') {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body ?? {});
    }

    final response = await http.Response.fromStream(await _http.send(request));
    final json = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 400) {
      final problem = json is Map<String, dynamic> ? json : const <String, dynamic>{};
      throw ApiException(
        response.statusCode,
        problem['code'] as String? ?? 'http.${response.statusCode}',
        problem['detail'] as String? ?? response.reasonPhrase ?? 'Error',
      );
    }
    return json;
  }
}
