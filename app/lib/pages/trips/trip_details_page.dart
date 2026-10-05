import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/pages/home_page/home_page.dart';
import 'package:coco_rider/pages/rides/booking_status_chip.dart';
import 'package:coco_rider/pages/rides/rides_tab.dart';
import 'package:coco_rider/pages/trips/trip_card.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:coco_rider/services/tracking/position_sharing.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Your trip". Passengers book from here; the driver manages bookings and the trip.
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
          builder: (context, details, reload) => ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _TripSummary(trip: details.trip),
                const SizedBox(height: 8),
                if (details.bookings != null)
                  _DriverSection(details: details, onChanged: reload)
                else if (details.trip.status == TripStatus.scheduled && details.trip.seatsAvailable > 0)
                  _BookingForm(trip: details.trip),
              ],
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
    final rating = trip.driver.rating;

    Widget feature(IconData icon, String label) => Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RouteHeader(trip: trip),
        const SizedBox(height: 6),
        Text(Formatters.departure(trip.departureAt), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Image.asset(ImageKeys.figmaCar3d, width: 130, fit: BoxFit.contain, excludeFromSemantics: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.vehicle, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Text('trip.availableSeats'.tr, style: theme.textTheme.bodySmall)),
                      Text('${trip.seatsAvailable}', style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: Text('trip.pricePerSeat'.tr, style: theme.textTheme.bodySmall)),
                      Text(Formatters.price(trip.pricePerSeatXaf), style: theme.textTheme.titleSmall),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(children: [
          feature(trip.instantBooking ? Icons.flash_on_rounded : Icons.how_to_reg_rounded,
              trip.instantBooking ? 'trip.instant'.tr : 'trip.onRequest'.tr),
          feature(Icons.luggage_rounded, trip.luggageAllowed ? 'trip.luggage'.tr : 'trip.noLuggage'.tr),
          feature(trip.smokingAllowed ? Icons.smoking_rooms_rounded : Icons.smoke_free_rounded,
              trip.smokingAllowed ? 'trip.smoking'.tr : 'trip.noSmoking'.tr),
        ]),
        if (trip.notes != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.format_quote_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(trip.notes!)),
            ]),
          ),
        ],
        const Divider(height: 32),
        Row(
          children: [
            CocoAvatar(name: trip.driver.firstName, radius: 26, verified: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.driver.firstName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 18, color: CocoColors.keyWarning),
                    const SizedBox(width: 3),
                    Text(
                      rating == null ? 'trip.newRating'.tr : '${rating.toStringAsFixed(1)} · ${'trip.reviews'.trParams({'count': '${trip.driver.reviewCount}'})}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32),
      ],
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
      final booking = await Get.find<CocoApi>().book(widget.trip.id, seats: _seats, paymentMethod: _payment);
      if (!mounted) return;
      await _showBooked(context, booking);
      Get.back();
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
    final theme = Theme.of(context);
    final maxSeats = widget.trip.seatsAvailable.clamp(1, 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          icon: Icons.event_seat_rounded,
          label: 'booking.seats'.tr,
          trailing: QuantityStepper(value: _seats, max: maxSeats, onChanged: (v) => setState(() => _seats = v), semanticLabel: 'booking.seats'.tr),
        ),
        const SizedBox(height: 10),
        SectionTitle('booking.payment'.tr),
        for (final method in PaymentMethod.values)
          _PaymentOption(method: method, selected: _payment == method, onTap: () => setState(() => _payment = method)),
        const SizedBox(height: 6),
        Text('booking.paymentNote'.tr, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            _amountRow(context, 'booking.seatsLine'.trParams({'count': '$_seats', 'price': Formatters.price(widget.trip.pricePerSeatXaf)}),
                Formatters.price(widget.trip.pricePerSeatXaf * _seats)),
            const Divider(height: 22),
            _amountRow(context, 'booking.totalToPay'.tr, Formatters.price(widget.trip.pricePerSeatXaf * _seats), strong: true),
          ]),
        ),
        const SizedBox(height: 8),
        Text('booking.cancelRule'.tr, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _book,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: CocoColors.keyWhite))
              : Text(widget.trip.instantBooking ? 'booking.confirm'.tr : 'booking.request'.tr),
        ),
      ],
    );
  }

  Widget _amountRow(BuildContext context, String label, String amount, {bool strong = false}) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(child: Text(label, style: strong ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)),
      Text(amount, style: strong ? theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary) : theme.textTheme.titleSmall),
    ]);
  }
}

/// A payment method as a selectable card (Figma "Choose Payment Method").
class _PaymentOption extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = switch (method) {
      PaymentMethod.cash => ImageKeys.figmaCash,
      PaymentMethod.mtnMobileMoney => ImageKeys.figmaMtn,
      PaymentMethod.orangeMoney => ImageKeys.figmaOrange,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? theme.colorScheme.primaryContainer.withAlpha(120) : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: selected ? 1.6 : 1.2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(logo, width: 48, height: 48, fit: BoxFit.contain, excludeFromSemantics: true),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('payment.${method.name}'.tr, style: theme.textTheme.titleMedium),
                    Text('payment.${method.name}.hint'.tr, style: theme.textTheme.bodySmall),
                  ]),
                ),
                if (selected) Icon(Icons.check_rounded, color: theme.colorScheme.primary),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// After booking: "waiting for the driver" (request) or "booking confirmed" (instant booking).
Future<void> _showBooked(BuildContext context, Booking booking) {
  final pending = booking.status == BookingStatus.pending;
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pending ? 'booking.requestSent'.tr : 'booking.done'.tr,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                pending ? 'booking.waitingDriver'.trParams({'name': booking.trip.driver.firstName}) : 'booking.cancelRule'.tr,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withAlpha(35)),
                  alignment: Alignment.center,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withAlpha(70)),
                    alignment: Alignment.center,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: pending ? theme.colorScheme.primary : CocoColors.keySuccess,
                      child: Icon(pending ? Icons.hourglass_top_rounded : Icons.check_rounded, color: CocoColors.keyWhite, size: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (Get.isRegistered<HomeController>()) {
                    final home = Get.find<HomeController>();
                    home.historyAsDriver.value = false;
                    home.tab.value = HomeController.history;
                  }
                },
                child: Text('booking.seeMyBookings'.tr),
              ),
            ],
          ),
        ),
      );
    },
  );
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
    final theme = Theme.of(context);
    final trip = details.trip;
    final bookings = details.bookings!;
    final departed = trip.departureAt.isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('driver.bookings'.tr),
        if (bookings.isEmpty) Text('driver.noBookings'.tr, style: theme.textTheme.bodyMedium),
        for (final booking in bookings)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CocoAvatar(name: booking.passengerFirstName, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(booking.passengerFirstName, style: theme.textTheme.titleMedium),
                        Text(
                          '${'booking.yourSeats'.trParams({'count': '${booking.seats}'})} · ${'payment.${booking.paymentMethod.name}'.tr}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ]),
                    ),
                    BookingStatusChip(status: booking.status),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (booking.status == BookingStatus.pending ||
                        booking.status == BookingStatus.confirmed ||
                        booking.status == BookingStatus.completed)
                      RoundAction(
                        icon: Icons.chat_bubble_rounded,
                        color: CocoColors.keyWarning,
                        tooltip: 'chat.open'.tr,
                        onPressed: () => Get.toNamed(CocoRoutes.keyChatPage, arguments: booking.id),
                      ),
                    if (booking.passengerPhone != null)
                      RoundAction(
                        icon: Icons.call_rounded,
                        color: CocoColors.keySuccess,
                        tooltip: 'driver.passengerPhone'.tr,
                        onPressed: () => showPhoneDialog('driver.passengerPhone'.tr, booking.passengerPhone!),
                      ),
                    if (departed && (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.completed))
                      TextButton(onPressed: () => _run(() => api.reportNoShow(booking.id)), child: Text('driver.noShow'.tr)),
                  ],
                ),
                if (booking.status == BookingStatus.pending) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => _run(() => api.rejectBooking(booking.id)), child: Text('driver.reject'.tr)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: () => _run(() => api.acceptBooking(booking.id)),
                        child: Text('driver.accept'.tr),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (trip.status == TripStatus.scheduled && _inSharingWindow(trip)) _PositionSharingCard(tripId: trip.id),
        if (trip.status == TripStatus.scheduled && departed)
          FilledButton(onPressed: () => _run(() => api.completeTrip(trip.id)), child: Text('driver.completeTrip'.tr)),
        if (trip.status == TripStatus.scheduled && !departed) ...[
          Text('driver.cancelWarning'.tr, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CocoColors.keyDanger, foregroundColor: CocoColors.keyWhite),
            onPressed: () async {
              final confirmed = await Get.dialog<bool>(AlertDialog(
                content: Text('driver.cancelWarning'.tr),
                actions: [
                  TextButton(onPressed: () => Get.back(result: false), child: Text('common.back'.tr)),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: CocoColors.keyDanger),
                    onPressed: () => Get.back(result: true),
                    child: Text('driver.cancelTrip'.tr),
                  ),
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

/// Sharing opens one hour before departure and closes 12 hours after (as on the server).
bool _inSharingWindow(Trip trip) {
  final now = DateTime.now();
  return now.isAfter(trip.departureAt.subtract(const Duration(hours: 1))) &&
      now.isBefore(trip.departureAt.add(const Duration(hours: 12)));
}

/// Driver: start or stop sharing the position with the passengers.
class _PositionSharingCard extends StatelessWidget {
  final String tripId;

  const _PositionSharingCard({required this.tripId});

  @override
  Widget build(BuildContext context) {
    final PositionSharing sharing = Get.find();
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
      child: Obx(() {
        final active = sharing.isSharing(tripId);
        final lastSent = sharing.lastSentAt.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(active ? Icons.gps_fixed : Icons.gps_off, color: active ? CocoColors.keySuccess : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(active && lastSent != null
                    ? 'tracking.sharing'.trParams({'time': Formatters.time(lastSent)})
                    : 'tracking.keepOpen'.tr),
              ),
            ]),
            if (sharing.error.value != null) ...[
              const SizedBox(height: 6),
              Text(sharing.error.value!, style: const TextStyle(color: CocoColors.keyError)),
            ],
            const SizedBox(height: 10),
            active
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text('tracking.stop'.tr),
                    onPressed: sharing.stop,
                  )
                : FilledButton.icon(
                    icon: const Icon(Icons.share_location),
                    label: Text('tracking.start'.tr),
                    onPressed: () => sharing.start(tripId),
                  ),
          ],
        );
      }),
    );
  }
}
