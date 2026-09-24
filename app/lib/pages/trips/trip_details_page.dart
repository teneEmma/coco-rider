import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/pages/rides/booking_status_chip.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Trip details. Passengers book from here; the driver manages bookings and the trip.
class TripDetailsPage extends StatelessWidget {
  const TripDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String tripId = Get.arguments as String;
    final CocoApi api = Get.find();

    return Scaffold(
      appBar: AppBar(title: Text('trip.details'.tr)),
      body: SafeArea(
        child: AsyncView<TripDetails>(
          load: () => api.getTrip(tripId),
          builder: (context, details, reload) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TripSummary(trip: details.trip),
                  const SizedBox(height: 16),
                  if (details.bookings != null)
                    _DriverSection(details: details, onChanged: reload)
                  else if (details.trip.status == TripStatus.scheduled && details.trip.seatsAvailable > 0)
                    _BookingForm(trip: details.trip),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripSummary extends StatelessWidget {
  final Trip trip;

  const _TripSummary({required this.trip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ]),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Formatters.departure(trip.departureAt), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            line(Icons.radio_button_checked, trip.origin.label),
            line(Icons.location_on, trip.destination.label),
            const Divider(height: 24),
            Row(
              children: [
                Text(Formatters.price(trip.pricePerSeatXaf), style: theme.textTheme.titleLarge),
                const SizedBox(width: 6),
                Text('trip.perSeat'.tr),
                const Spacer(),
                Text('trip.seatsLeft'.trParams({'count': '${trip.seatsAvailable}'})),
              ],
            ),
            const Divider(height: 24),
            line(Icons.person, '${'trip.driver'.tr} : ${trip.driver.firstName}'
                '${trip.driver.rating == null ? '' : ' · ★ ${trip.driver.rating!.toStringAsFixed(1)} (${trip.driver.reviewCount})'}'),
            line(Icons.directions_car, '${'trip.vehicle'.tr} : ${trip.vehicle}'),
            line(trip.instantBooking ? Icons.flash_on : Icons.how_to_reg, trip.instantBooking ? 'trip.instant'.tr : 'trip.onRequest'.tr),
            if (trip.luggageAllowed) line(Icons.luggage, 'trip.luggage'.tr),
            if (trip.smokingAllowed) line(Icons.smoking_rooms, 'trip.smoking'.tr),
            if (trip.womenOnly) line(Icons.female, 'trip.womenOnly'.tr),
            if (trip.notes != null) line(Icons.notes, trip.notes!),
          ],
        ),
      ),
    );
  }
}

class _BookingForm extends StatefulWidget {
  final Trip trip;

  const _BookingForm({required this.trip});

  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  int _seats = 1;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _busy = false;

  Future<void> _book() async {
    setState(() => _busy = true);
    try {
      await Get.find<CocoApi>().book(widget.trip.id, seats: _seats, paymentMethod: _payment);
      Get.back();
      Get.snackbar('booking.done'.tr, 'booking.cancelRule'.tr,
          backgroundColor: CocoColors.keySuccess.withAlpha(230), colorText: CocoColors.keyWhite);
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find();
    final isOwnTrip = session.profile.value?.id == widget.trip.driver.id;
    if (isOwnTrip) return const SizedBox.shrink();
    final maxSeats = widget.trip.seatsAvailable.clamp(1, 4);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('booking.title'.tr, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('search.seats'.tr),
                const Spacer(),
                IconButton(onPressed: _seats > 1 ? () => setState(() => _seats--) : null, icon: const Icon(Icons.remove_circle_outline)),
                Text('$_seats', style: Theme.of(context).textTheme.titleMedium),
                IconButton(onPressed: _seats < maxSeats ? () => setState(() => _seats++) : null, icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            const SizedBox(height: 8),
            Text('booking.payment'.tr),
            RadioGroup<PaymentMethod>(
              groupValue: _payment,
              onChanged: (v) => setState(() => _payment = v!),
              child: Column(
                children: [
                  for (final method in PaymentMethod.values)
                    RadioListTile<PaymentMethod>(
                      contentPadding: EdgeInsets.zero,
                      value: method,
                      title: Text('payment.${method.name}'.tr, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                ],
              ),
            ),
            const Divider(),
            Row(
              children: [
                Text('booking.total'.tr),
                const Spacer(),
                Text(Formatters.price(widget.trip.pricePerSeatXaf * _seats), style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text('booking.cancelRule'.tr, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _book, child: Text('booking.confirm'.tr)),
          ],
        ),
      ),
    );
  }
}

class _DriverSection extends StatelessWidget {
  final TripDetails details;
  final VoidCallback onChanged;

  const _DriverSection({required this.details, required this.onChanged});

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      onChanged();
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final CocoApi api = Get.find();
    final trip = details.trip;
    final bookings = details.bookings!;
    final departed = trip.departureAt.isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('driver.bookings'.tr, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (bookings.isEmpty) Text('driver.noBookings'.tr),
        for (final booking in bookings)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${booking.passengerFirstName} · ${booking.seats} × ${Formatters.price(trip.pricePerSeatXaf)}',
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      BookingStatusChip(status: booking.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('payment.${booking.paymentMethod.name}'.tr),
                  if (booking.passengerPhone != null) SelectableText(booking.passengerPhone!),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (booking.status == BookingStatus.pending) ...[
                        FilledButton(onPressed: () => _run(() => api.acceptBooking(booking.id)), child: Text('driver.accept'.tr)),
                        OutlinedButton(onPressed: () => _run(() => api.rejectBooking(booking.id)), child: Text('driver.reject'.tr)),
                      ],
                      if (booking.status == BookingStatus.pending ||
                          booking.status == BookingStatus.confirmed ||
                          booking.status == BookingStatus.completed)
                        TextButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text('chat.open'.tr),
                          onPressed: () => Get.toNamed(CocoRoutes.keyChatPage, arguments: booking.id),
                        ),
                      if (departed && (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.completed))
                        TextButton(onPressed: () => _run(() => api.reportNoShow(booking.id)), child: Text('driver.noShow'.tr)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (trip.status == TripStatus.scheduled && departed)
          FilledButton(onPressed: () => _run(() => api.completeTrip(trip.id)), child: Text('driver.completeTrip'.tr)),
        if (trip.status == TripStatus.scheduled && !departed) ...[
          Text('driver.cancelWarning'.tr, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: CocoColors.keyError,
              side: const BorderSide(color: CocoColors.keyError),
            ),
            onPressed: () async {
              final confirmed = await Get.dialog<bool>(AlertDialog(
                content: Text('driver.cancelWarning'.tr),
                actions: [
                  TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
                  TextButton(onPressed: () => Get.back(result: true), child: Text('driver.cancelTrip'.tr)),
                ],
              ));
              if (confirmed == true) await _run(() => api.cancelTrip(trip.id));
            },
            child: Text('driver.cancelTrip'.tr),
          ),
        ],
      ],
    );
  }
}
