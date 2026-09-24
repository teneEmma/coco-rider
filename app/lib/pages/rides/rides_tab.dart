import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/pages/rides/booking_status_chip.dart';
import 'package:coco_rider/pages/trips/trip_card.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Coco trajets": the passenger's bookings and the driver's trips.
class RidesTab extends StatefulWidget {
  const RidesTab({super.key});

  @override
  State<RidesTab> createState() => _RidesTabState();
}

class _RidesTabState extends State<RidesTab> {
  bool _asDriver = false;
  int _version = 0;

  void _reload() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    final CocoApi api = Get.find();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text('rides.asPassenger'.tr), icon: const Icon(Icons.event_seat)),
                  ButtonSegment(value: true, label: Text('rides.asDriver'.tr), icon: const Icon(Icons.directions_car)),
                ],
                selected: {_asDriver},
                onSelectionChanged: (s) => setState(() => _asDriver = s.first),
              ),
              const SizedBox(height: 12),
              if (_asDriver)
                AsyncView<List<Trip>>(
                  key: ValueKey('trips$_version'),
                  load: () async => [...await api.getMyTrips(), ...await api.getMyTrips(past: true)],
                  builder: (context, trips, _) => trips.isEmpty
                      ? Text('rides.none'.tr, textAlign: TextAlign.center)
                      : Column(children: [
                          for (final trip in trips)
                            TripCard(
                              trip: trip,
                              onTap: () async {
                                await Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: trip.id);
                                _reload();
                              },
                            ),
                        ]),
                )
              else
                AsyncView<List<Booking>>(
                  key: ValueKey('bookings$_version'),
                  load: api.getMyBookings,
                  builder: (context, bookings, _) => bookings.isEmpty
                      ? Text('rides.none'.tr, textAlign: TextAlign.center)
                      : Column(children: [
                          for (final booking in bookings) _BookingTile(booking: booking, onChanged: _reload),
                        ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback onChanged;

  const _BookingTile({required this.booking, required this.onChanged});

  Future<void> _cancel() async {
    try {
      await Get.find<CocoApi>().cancelBooking(booking.id);
      onChanged();
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TripCard(
      trip: booking.trip,
      onTap: () => Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: booking.trip.id),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          if (booking.isActive || booking.status == BookingStatus.completed)
            IconButton(
              tooltip: 'chat.open'.tr,
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Get.toNamed(CocoRoutes.keyChatPage, arguments: booking.id),
            ),
          if (booking.driverPhone != null)
            IconButton(
              tooltip: 'booking.driverPhone'.tr,
              icon: const Icon(Icons.phone),
              onPressed: () => Get.dialog(AlertDialog(
                title: Text('booking.driverPhone'.tr),
                content: SelectableText(booking.driverPhone!),
              )),
            ),
          if (booking.isActive && booking.trip.departureAt.isAfter(DateTime.now()))
            TextButton(onPressed: _cancel, child: Text('booking.cancel'.tr)),
          if (booking.status == BookingStatus.completed)
            TextButton(onPressed: () => showReviewDialog(booking.id), child: Text('booking.review'.tr)),
          BookingStatusChip(status: booking.status),
        ],
      ),
    );
  }
}

/// Asks for 1–5 stars and an optional comment, then sends the review.
Future<void> showReviewDialog(String bookingId) async {
  var rating = 5;
  final comment = TextEditingController();

  final send = await Get.dialog<bool>(StatefulBuilder(
    builder: (context, setState) => AlertDialog(
      title: Text('review.title'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i',
                  onPressed: () => setState(() => rating = i),
                  icon: Icon(i <= rating ? Icons.star : Icons.star_border, color: Colors.amber.shade700),
                ),
            ],
          ),
          TextField(controller: comment, maxLines: 3, decoration: InputDecoration(labelText: 'review.comment'.tr)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
        FilledButton(onPressed: () => Get.back(result: true), child: Text('review.send'.tr)),
      ],
    ),
  ));
  if (send != true) return;

  try {
    await Get.find<CocoApi>().review(bookingId, rating: rating, comment: comment.text.trim().isEmpty ? null : comment.text.trim());
    Get.snackbar('review.thanks'.tr, '');
  } catch (e) {
    UtilityFunctions.showErrorSnackBar(Formatters.error(e));
  }
}
