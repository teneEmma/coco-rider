import 'dart:async';

import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

/// Passenger view: where the driver is, refreshed every few seconds, and a link for relatives.
class LiveTrackingPage extends StatefulWidget {
  final Duration refreshEvery;

  /// Off in widget tests (no network for map tiles).
  final bool showMap;

  const LiveTrackingPage({super.key, this.refreshEvery = const Duration(seconds: 10), this.showMap = true});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  final CocoApi _api = Get.find();
  final String _tripId = Get.arguments as String;
  final _map = MapController();
  TripTracking? _tracking;
  String? _error;
  Timer? _timer;
  bool _sharing = false;
  bool _mapReady = false;

  /// The map is framed once (car + destination); after that the user can pan and zoom freely.
  bool _framed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(widget.refreshEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final tracking = await _api.getTracking(_tripId);
      if (!mounted) return;
      setState(() {
        _tracking = tracking;
        _error = null;
      });
      _frameOnce();
      if (tracking.tripStatus != TripStatus.scheduled) _timer?.cancel();
    } catch (e) {
      if (mounted && _tracking == null) setState(() => _error = Formatters.error(e));
    }
  }

  void _frameOnce() {
    final tracking = _tracking;
    final position = tracking?.position;
    if (_framed || !_mapReady || tracking == null || position == null) return;
    _framed = true;
    _map.fitCamera(CameraFit.coordinates(
      coordinates: [
        LatLng(position.latitude, position.longitude),
        LatLng(tracking.destination.latitude, tracking.destination.longitude),
      ],
      padding: const EdgeInsets.all(48),
      maxZoom: 14,
    ));
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final link = await _api.shareTrip(_tripId);
      await SharePlus.instance.share(ShareParams(text: '${'tracking.shareMessage'.tr}\n${link.url}'));
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;
    return Scaffold(
      appBar: AppBar(title: Text('tracking.title'.tr)),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
            : tracking == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showMap) Expanded(child: _buildMap(tracking)),
                      _StatusCard(tracking: tracking),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share),
                          label: Text('tracking.share'.tr),
                          onPressed: _sharing || tracking.tripStatus != TripStatus.scheduled ? null : _share,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildMap(TripTracking tracking) {
    final destination = LatLng(tracking.destination.latitude, tracking.destination.longitude);
    final position = tracking.position;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: destination,
        initialZoom: 11,
        onMapReady: () {
          _mapReady = true;
          _frameOnce();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'cm.cocorider.app',
        ),
        MarkerLayer(markers: [
          Marker(point: destination, child: const Icon(Icons.location_on, size: 36, color: Colors.black87)),
          if (position != null)
            Marker(
              point: LatLng(position.latitude, position.longitude),
              width: 44,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: position.isLive ? const Color(0xFF1F7A0F) : CocoColors.keyGrey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 22),
              ),
            ),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final TripTracking tracking;

  const _StatusCard({required this.tracking});

  @override
  Widget build(BuildContext context) {
    final position = tracking.position;
    final String status;
    if (tracking.tripStatus == TripStatus.completed) {
      status = 'tracking.over'.tr;
    } else if (tracking.tripStatus == TripStatus.cancelled) {
      status = 'bookingStatus.tripCancelled'.tr;
    } else if (position == null) {
      status = 'tracking.waiting'.tr;
    } else if (position.isLive) {
      status = 'tracking.live'.tr;
    } else {
      status = 'tracking.lastSeen'.trParams({'time': Formatters.time(position.recordedAt)});
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(position?.isLive == true ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: position?.isLive == true ? const Color(0xFF1F7A0F) : null),
              const SizedBox(width: 8),
              Expanded(child: Text(status, style: Theme.of(context).textTheme.titleSmall)),
            ]),
            if (position != null && tracking.tripStatus == TripStatus.scheduled) ...[
              const SizedBox(height: 6),
              Text('tracking.distance'.trParams({
                'km': position.distanceToDestinationKm.toStringAsFixed(1),
                'city': tracking.destination.city,
              })),
            ],
          ],
        ),
      ),
    );
  }
}
