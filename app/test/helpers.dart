import 'dart:convert';

/// A syntactically valid (unsigned) JWT with the given claims.
String fakeJwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.signature';
}

Map<String, dynamic> tripJson({String id = 'trip-1', int seatsAvailable = 2}) => {
      'id': id,
      'kind': 'Intercity',
      'status': 'Scheduled',
      'origin': {'city': 'Douala', 'landmark': 'Carrefour Ndokoti', 'latitude': 4.05, 'longitude': 9.77},
      'destination': {'city': 'Yaoundé', 'landmark': 'Total Mvan', 'latitude': 3.85, 'longitude': 11.5},
      'departureAt': '2026-10-03T06:30:00+00:00',
      'seatsTotal': 3,
      'seatsAvailable': seatsAvailable,
      'pricePerSeatXaf': 5000,
      'womenOnly': false,
      'luggageAllowed': true,
      'smokingAllowed': false,
      'instantBooking': true,
      'notes': null,
      'driver': {'id': 'driver-1', 'firstName': 'Paul', 'rating': 4.7, 'reviewCount': 12},
      'vehicle': {'make': 'Toyota', 'model': 'Corolla', 'color': 'Grise'},
    };
