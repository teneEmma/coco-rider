import 'dart:async';

import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// A GPS fix.
class GeoFix {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speedKmh;
  final DateTime time;

  const GeoFix({required this.latitude, required this.longitude, this.heading, this.speedKmh, required this.time});
}

/// The phone's GPS, behind an interface so sharing can be tested.
abstract class LocationProvider {
  /// Asks for the location permission if needed; false if refused or location is off.
  Future<bool> ensurePermission();

  Future<GeoFix> current();
}

class GeolocatorLocationProvider implements LocationProvider {
  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  @override
  Future<GeoFix> current() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
    );
    return GeoFix(
      latitude: position.latitude,
      longitude: position.longitude,
      heading: position.heading >= 0 ? position.heading : null,
      speedKmh: position.speed >= 0 ? position.speed * 3.6 : null,
      time: position.timestamp,
    );
  }
}

/// The driver shares their position every [every] while the app is open.
/// (Sharing with the screen off needs a background location permission: planned later.)
class PositionSharing extends GetxController {
  final CocoApi api;
  final LocationProvider location;
  final Duration every;

  PositionSharing({required this.api, required this.location, this.every = const Duration(seconds: 15)});

  /// The trip whose position is being shared, if any.
  final RxnString sharingTripId = RxnString();
  final Rxn<DateTime> lastSentAt = Rxn<DateTime>();
  final RxnString error = RxnString();

  Timer? _timer;
  bool _sending = false;

  bool isSharing(String tripId) => sharingTripId.value == tripId;

  /// Returns false when the location permission is refused.
  Future<bool> start(String tripId) async {
    error.value = null;
    if (!await location.ensurePermission()) {
      error.value = 'tracking.permission'.tr;
      return false;
    }
    if (sharingTripId.value != null && sharingTripId.value != tripId) await stop();

    sharingTripId.value = tripId;
    await _send();
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => _send());
    return sharingTripId.value == tripId;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final tripId = sharingTripId.value;
    sharingTripId.value = null;
    lastSentAt.value = null;
    if (tripId == null) return;
    try {
      await api.stopSharingPosition(tripId);
    } catch (e) {
      UtilityFunctions.debugPrint('Could not stop sharing: $e', leadingIcons: '📍');
    }
  }

  Future<void> _send() async {
    final tripId = sharingTripId.value;
    if (tripId == null || _sending) return;
    _sending = true;
    try {
      final fix = await location.current();
      await api.updatePosition(tripId,
          latitude: fix.latitude, longitude: fix.longitude, heading: fix.heading, speedKmh: fix.speedKmh, recordedAt: fix.time);
      lastSentAt.value = DateTime.now();
      error.value = null;
    } on ApiException catch (e) {
      error.value = Formatters.error(e);
      // Outside the sharing window (too early, or the trip is over): stop quietly.
      if (e.code == 'tracking.not_active' || e.code == 'trip.not_found') {
        _timer?.cancel();
        sharingTripId.value = null;
      }
    } catch (e) {
      // No GPS fix or no network this time: the next tick tries again.
      UtilityFunctions.debugPrint('Position not sent: $e', leadingIcons: '📍');
    } finally {
      _sending = false;
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
