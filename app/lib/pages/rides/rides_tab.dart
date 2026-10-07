import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/pages/home_page/home_page.dart';
import 'package:coco_rider/pages/trips/trip_card.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The filters of the history (Figma "Ride History").
enum RideFilter { all, scheduled, ongoing, completed, cancelled }

/// Which filter a booking belongs to.
RideFilter bookingCategory(Booking booking, DateTime now) => switch (booking.status) {
      BookingStatus.completed => RideFilter.completed,
      BookingStatus.pending || BookingStatus.confirmed =>
        booking.trip.departureAt.isAfter(now) ? RideFilter.scheduled : RideFilter.ongoing,
      _ => RideFilter.cancelled,
    };

/// Which filter a driver's trip belongs to.
RideFilter tripCategory(Trip trip, DateTime now) => switch (trip.status) {
      TripStatus.completed => RideFilter.completed,
      TripStatus.cancelled => RideFilter.cancelled,
      TripStatus.scheduled => trip.departureAt.isAfter(now) ? RideFilter.scheduled : RideFilter.ongoing,
    };

Color categoryColor(RideFilter filter) => switch (filter) {
      RideFilter.completed => CocoColors.keySuccess,
      RideFilter.ongoing => CocoColors.keyWarning,
      RideFilter.cancelled => CocoColors.keyDanger,
      _ => const Color(0xFFD9D9D9),
    };

/// "History": the passenger's bookings and the driver's trips.
class RidesTab extends StatefulWidget {
  const RidesTab({super.key});

  @override
  State<RidesTab> createState() => _RidesTabState();
}

class _RidesTabState extends State<RidesTab> {
  final HomeController _home = Get.find();
  RideFilter _filter = RideFilter.all;
  int _version = 0;
  late Future<_History> _history = _load();

  Future<_History> _load() async {
    final api = Get.find<CocoApi>();
    if (_home.historyAsDriver.value) {
      final trips = [...await api.getMyTrips(), ...await api.getMyTrips(past: true)];
      return _History(trips: trips);
    }
    return _History(bookings: await api.getMyBookings());
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _version++;
      _history = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return SheetScrollView(
      title: 'history.title'.tr,
      onRefresh: _reload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text('rides.asPassenger'.tr), icon: const Icon(Icons.event_seat_rounded)),
                  ButtonSegment(value: true, label: Text('rides.asDriver'.tr), icon: const Icon(Icons.directions_car_rounded)),
                ],
                selected: {_home.historyAsDriver.value},
                onSelectionChanged: (s) {
                  _home.historyAsDriver.value = s.first;
                  _reload();
                },
              )),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in RideFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('history.filter.${f.name}'.tr),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          FutureBuilder<_History>(
            key: ValueKey(_version),
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text(Formatters.error(snapshot.error!), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _reload, child: Text('common.retry'.tr)),
                  ]),
                );
              }
              final history = snapshot.data!;
              final List<Widget> items;
              if (history.trips != null) {
                items = [
                  for (final trip in history.trips!)
                    if (_filter == RideFilter.all || tripCategory(trip, now) == _filter)
                      TripCard(
                        trip: trip,
                        status: StatusPill(
                          label: 'history.filter.${tripCategory(trip, now).name}'.tr,
                          color: categoryColor(tripCategory(trip, now)),
                        ),
                        onTap: () async {
                          await Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: trip.id);
                          _reload();
                        },
                        trailing: OutlinedButton(
                          onPressed: () async {
                            await Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: trip.id);
                            _reload();
                          },
                          child: Text('history.manageTrip'.tr),
                        ),
                      ),
                ];
              } else {
                items = [
                  for (final booking in history.bookings!)
                    if (_filter == RideFilter.all || bookingCategory(booking, now) == _filter)
                      _BookingTicket(booking: booking, now: now, onChanged: _reload),
                ];
              }
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(children: [
                    Icon(Icons.history_rounded, size: 44, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 10),
                    Text('rides.none'.tr, textAlign: TextAlign.center),
                  ]),
                );
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
            },
          ),
        ],
      ),
    );
  }
}

class _History {
  final List<Booking>? bookings;
  final List<Trip>? trips;

  _History({this.bookings, this.trips});
}

class _BookingTicket extends StatelessWidget {
  final Booking booking;
  final DateTime now;
  final Future<void> Function() onChanged;

  const _BookingTicket({required this.booking, required this.now, required this.onChanged});

  Future<void> _cancel() async {
    final confirmed = await Get.dialog<bool>(AlertDialog(
      content: Text('booking.cancelConfirm'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('common.back'.tr)),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: CocoColors.keyDanger),
          onPressed: () => Get.back(result: true),
          child: Text('booking.cancel'.tr),
        ),
      ],
    ));
    if (confirmed != true) return;
    try {
      await Get.find<CocoApi>().cancelBooking(booking.id);
      await onChanged();
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = bookingCategory(booking, now);
    final canChat = booking.isActive || booking.status == BookingStatus.completed;
    final canFollow = booking.status == BookingStatus.confirmed &&
        now.isAfter(booking.trip.departureAt.subtract(const Duration(hours: 1)));
    // A request can always be withdrawn; a confirmed seat only until 24 h before departure (as on the server).
    final canCancel = booking.status == BookingStatus.pending && booking.trip.departureAt.isAfter(now) ||
        booking.status == BookingStatus.confirmed && booking.trip.departureAt.difference(now) >= const Duration(hours: 24);

    return TripCard(
      trip: booking.trip,
      status: StatusPill(label: 'bookingStatus.${booking.status.name}'.tr, color: categoryColor(category)),
      onTap: () => Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: booking.trip.id),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('booking.yourSeats'.trParams({'count': '${booking.seats}'}), style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text('${'booking.total'.tr} : ${Formatters.price(booking.totalPriceXaf)}', style: Theme.of(context).textTheme.titleSmall),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canChat)
                RoundAction(
                  icon: Icons.chat_bubble_rounded,
                  color: CocoColors.keyWarning,
                  tooltip: 'chat.open'.tr,
                  onPressed: () => Get.toNamed(CocoRoutes.keyChatPage, arguments: booking.id),
                ),
              if (booking.driverPhone != null)
                RoundAction(
                  icon: Icons.call_rounded,
                  color: CocoColors.keySuccess,
                  tooltip: 'booking.driverPhone'.tr,
                  onPressed: () => showPhoneDialog('booking.driverPhone'.tr, booking.driverPhone!),
                ),
              if (canFollow)
                RoundAction(
                  icon: Icons.near_me_rounded,
                  color: CocoColors.keyPrimary,
                  tooltip: 'tracking.follow'.tr,
                  onPressed: () => Get.toNamed(CocoRoutes.keyTrackingPage, arguments: booking.trip.id),
                ),
              if (booking.status == BookingStatus.completed)
                OutlinedButton.icon(
                  icon: const Icon(Icons.star_rounded, color: CocoColors.keyWarning),
                  onPressed: () => showReviewDialog(booking.id),
                  label: Text('booking.review'.tr),
                ),
            ],
          ),
          if (canCancel) ...[
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CocoColors.keyDanger, foregroundColor: CocoColors.keyWhite),
              onPressed: _cancel,
              child: Text('booking.cancel'.tr),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows a phone number that can be selected and copied.
Future<void> showPhoneDialog(String title, String phone) => Get.dialog(AlertDialog(
      title: Text(title),
      content: SelectableText(phone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      actions: [TextButton(onPressed: Get.back, child: Text('common.close'.tr))],
    ));

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
                  icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_border_rounded, color: CocoColors.keyWarning, size: 32),
                ),
            ],
          ),
          TextField(controller: comment, maxLines: 3, decoration: InputDecoration(hintText: 'review.comment'.tr)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Get.back(result: true),
          child: Text('review.send'.tr),
        ),
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
