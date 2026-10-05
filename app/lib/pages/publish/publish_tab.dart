import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/constants/cameroon_cities.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/pages/home_page/home_page.dart';
import 'package:coco_rider/pages/trips/trip_card.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// "Coco Ride": the driver's area. Verified drivers publish a trip in three steps.
class PublishTab extends StatefulWidget {
  const PublishTab({super.key});

  @override
  State<PublishTab> createState() => _PublishTabState();
}

class _PublishTabState extends State<PublishTab> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find();

    return Obx(() {
      final profile = session.profile.value;
      if (profile == null || !profile.driver.isVerified) {
        return SheetScrollView(title: 'publish.title'.tr, child: const _NotVerified());
      }
      return AsyncView<List<Vehicle>>(
        key: ValueKey(_version),
        load: Get.find<CocoApi>().getVehicles,
        builder: (context, vehicles, _) => _PublishWizard(
          vehicles: vehicles,
          onVehiclesChanged: () => setState(() => _version++),
        ),
      );
    });
  }
}

class _NotVerified extends StatelessWidget {
  const _NotVerified();

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find();
    return Column(
      children: [
        const SizedBox(height: 12),
        CircleAvatar(
          radius: 42,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.badge_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 18),
        Text('publish.notVerified'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              await Get.toNamed(CocoRoutes.keyDocumentsPage);
              await session.refreshProfile();
            },
            child: Text('profile.documents'.tr),
          ),
        ),
      ],
    );
  }
}

class _PublishWizard extends StatefulWidget {
  final List<Vehicle> vehicles;
  final VoidCallback onVehiclesChanged;

  const _PublishWizard({required this.vehicles, required this.onVehiclesChanged});

  @override
  State<_PublishWizard> createState() => _PublishWizardState();
}

class _PublishWizardState extends State<_PublishWizard> {
  final _stepForms = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];
  final _fromLandmark = TextEditingController();
  final _toLandmark = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  int _step = 0;
  TripKind _kind = TripKind.intercity;
  CameroonCity _from = CameroonCities.all[0];
  CameroonCity _to = CameroonCities.all[1];
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  late String? _vehicleId = widget.vehicles.isEmpty ? null : widget.vehicles.first.id;
  int _seats = 3;
  bool _luggage = true;
  bool _smoking = false;
  bool _instant = true;
  bool _busy = false;
  Trip? _published;

  Vehicle? get _vehicle => widget.vehicles.where((v) => v.id == _vehicleId).firstOrNull;

  /// The time typed by the driver is Cameroon time (UTC+1).
  DateTime get _departureUtc =>
      DateTime.utc(_date.year, _date.month, _date.day, _time.hour, _time.minute).subtract(Formatters.cameroonOffset);

  @override
  void dispose() {
    for (final c in [_fromLandmark, _toLandmark, _price, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (!_stepForms[_step].currentState!.validate()) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _publish();
    }
  }

  Future<void> _publish() async {
    if (_vehicle == null) return;
    setState(() => _busy = true);
    try {
      final to = _kind == TripKind.urban ? _from : _to;
      final trip = await Get.find<CocoApi>().publishTrip(
        vehicleId: _vehicle!.id,
        kind: _kind,
        origin: Place(city: _from.name, landmark: _fromLandmark.text.trim(), latitude: _from.latitude, longitude: _from.longitude),
        destination: Place(city: to.name, landmark: _toLandmark.text.trim(), latitude: to.latitude, longitude: to.longitude),
        departureAt: _departureUtc,
        seats: _seats,
        pricePerSeatXaf: int.parse(_price.text),
        luggageAllowed: _luggage,
        smokingAllowed: _smoking,
        instantBooking: _instant,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      setState(() => _published = trip);
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startOver() => setState(() {
        _published = null;
        _step = 0;
        for (final c in [_fromLandmark, _toLandmark, _price, _notes]) {
          c.clear();
        }
      });

  @override
  Widget build(BuildContext context) {
    final published = _published;
    if (published != null) {
      return SheetScrollView(child: _Published(trip: published, onAnother: _startOver));
    }

    final steps = [_pickUpStep, _dropOffStep, _detailsStep];
    final illustrations = [Icons.near_me_rounded, Icons.signpost_rounded, Icons.directions_car_filled_rounded];
    final intros = ['publish.pickUpIntro'.tr, 'publish.dropOffIntro'.tr, 'publish.detailsIntro'.tr];

    return SheetScrollView(
      title: 'publish.title'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepIndicator(
            icons: illustrations,
            labels: ['publish.stepPickUp'.tr, 'publish.stepDropOff'.tr, 'publish.stepDetails'.tr],
            current: _step,
          ),
          const SizedBox(height: 18),
          Center(
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(illustrations[_step], size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          Text(intros[_step], textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          Form(key: _stepForms[_step], child: steps[_step](context)),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _next,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: CocoColors.keyWhite))
                : Text(_step < 2 ? 'common.continue'.tr : 'publish.button'.tr),
          ),
          if (_step > 0) ...[
            const SizedBox(height: 6),
            TextButton(onPressed: () => setState(() => _step--), child: Text('common.back'.tr)),
          ],
          const SizedBox(height: 16),
          Image.asset(ImageKeys.figmaSkyline, fit: BoxFit.fitWidth, excludeFromSemantics: true),
        ],
      ),
    );
  }

  Widget _cityPicker(String label, CameroonCity value, ValueChanged<CameroonCity> onChanged) =>
      DropdownButtonFormField<CameroonCity>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(Icons.location_city_rounded, color: Theme.of(context).colorScheme.primary),
        ),
        borderRadius: BorderRadius.circular(14),
        items: [for (final c in CameroonCities.all) DropdownMenuItem(value: c, child: Text(c.name))],
        onChanged: (c) => setState(() => onChanged(c!)),
      );

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'common.required'.tr : null;

  Widget _pickUpStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TripKind>(
            segments: [
              ButtonSegment(value: TripKind.intercity, label: Text('publish.intercity'.tr)),
              ButtonSegment(value: TripKind.urban, label: Text('publish.urban'.tr)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 14),
          _cityPicker('publish.fromCity'.tr, _from, (c) => _from = c),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fromLandmark,
            decoration: InputDecoration(
              hintText: 'publish.fromLandmark'.tr,
              prefixIcon: Icon(Icons.place_rounded, color: Theme.of(context).colorScheme.primary),
              helperText: 'publish.landmarkHelp'.tr,
            ),
            validator: _required,
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: DashedLine()),
          Row(children: [
            Expanded(
              child: PillButton(
                icon: Icons.calendar_month_rounded,
                label: Formatters.shortDay(_date),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PillButton(
                icon: Icons.schedule_rounded,
                label: _time.format(context),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              ),
            ),
          ]),
        ],
      );

  Widget _dropOffStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_kind == TripKind.intercity) ...[
            _cityPicker('publish.toCity'.tr, _to, (c) => _to = c),
            const SizedBox(height: 12),
          ] else ...[
            PillButton(icon: Icons.location_city_rounded, label: _from.name),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _toLandmark,
            decoration: InputDecoration(
              hintText: 'publish.toLandmark'.tr,
              prefixIcon: Icon(Icons.flag_rounded, color: Theme.of(context).colorScheme.primary),
              helperText: 'publish.landmarkHelp'.tr,
            ),
            validator: _required,
          ),
        ],
      );

  Widget _detailsStep(BuildContext context) {
    final maxSeats = _vehicle?.passengerSeats ?? 4;
    if (_seats > maxSeats) _seats = maxSeats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _vehicleId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              decoration: InputDecoration(
                hintText: 'publish.vehicle'.tr,
                prefixIcon: Icon(Icons.directions_car_filled_rounded, color: Theme.of(context).colorScheme.primary),
              ),
              items: [for (final v in widget.vehicles) DropdownMenuItem(value: v.id, child: Text(v.label, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _vehicleId = v),
              validator: (v) => v == null ? 'publish.addVehicleFirst'.tr : null,
            ),
          ),
          const SizedBox(width: 10),
          SquareIconButton(
            icon: Icons.add_rounded,
            tooltip: 'publish.addVehicle'.tr,
            onPressed: () async {
              final added = await Get.toNamed(CocoRoutes.keyAddVehiclePage);
              if (added == true) widget.onVehiclesChanged();
            },
          ),
        ]),
        const SizedBox(height: 12),
        TextFormField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'publish.price'.tr,
            prefixIcon: const Icon(Icons.payments_rounded, color: CocoColors.keySuccess),
            suffixText: 'FCFA',
          ),
          validator: (v) {
            final price = int.tryParse(v ?? '');
            return price == null || price <= 0 || price > 100000 ? 'publish.priceRange'.tr : null;
          },
        ),
        const SizedBox(height: 8),
        SettingRow(
          icon: Icons.event_seat_rounded,
          label: 'publish.seats'.tr,
          trailing: QuantityStepper(value: _seats, max: maxSeats, onChanged: (v) => setState(() => _seats = v), semanticLabel: 'publish.seats'.tr),
        ),
        SettingRow(
          icon: Icons.flash_on_rounded,
          label: 'trip.instant'.tr,
          trailing: Switch(value: _instant, onChanged: (v) => setState(() => _instant = v)),
        ),
        SettingRow(
          icon: Icons.luggage_rounded,
          label: 'trip.luggage'.tr,
          trailing: Switch(value: _luggage, onChanged: (v) => setState(() => _luggage = v)),
        ),
        SettingRow(
          icon: Icons.smoking_rooms_rounded,
          label: 'trip.smoking'.tr,
          trailing: Switch(value: _smoking, onChanged: (v) => setState(() => _smoking = v)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notes,
          maxLines: 3,
          decoration: InputDecoration(hintText: 'publish.notesHint'.tr),
        ),
      ],
    );
  }
}

/// "Trip published" with the ticket and what to do next.
class _Published extends StatelessWidget {
  final Trip trip;
  final VoidCallback onAnother;

  const _Published({required this.trip, required this.onAnother});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('publish.done'.tr, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 18),
        const Center(
          child: CircleAvatar(
            radius: 38,
            backgroundColor: CocoColors.keySuccess,
            child: Icon(Icons.check_rounded, size: 46, color: CocoColors.keyWhite),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          trip.instantBooking ? 'publish.doneInstant'.tr : 'publish.doneOnRequest'.tr,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        TripCard(trip: trip, onTap: () => Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: trip.id)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final home = Get.find<HomeController>();
            home.historyAsDriver.value = true;
            home.tab.value = HomeController.history;
          },
          child: Text('publish.seeMyTrips'.tr),
        ),
        const SizedBox(height: 6),
        TextButton(onPressed: onAnother, child: Text('publish.another'.tr)),
      ],
    );
  }
}
