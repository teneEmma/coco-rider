import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/constants/cameroon_cities.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// "Publier": verified drivers publish a trip.
class PublishTab extends StatelessWidget {
  const PublishTab({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            final profile = session.profile.value;
            if (profile == null || !profile.driver.isVerified) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.badge_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text('publish.notVerified'.tr, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Get.toNamed(CocoRoutes.keyDocumentsPage),
                        child: Text('profile.documents'.tr),
                      ),
                    ],
                  ),
                ),
              );
            }
            return AsyncView<List<Vehicle>>(
              load: Get.find<CocoApi>().getVehicles,
              builder: (context, vehicles, reload) => _PublishForm(vehicles: vehicles, onVehicleAdded: reload),
            );
          }),
        ),
      ),
    );
  }
}

class _PublishForm extends StatefulWidget {
  final List<Vehicle> vehicles;
  final VoidCallback onVehicleAdded;

  const _PublishForm({required this.vehicles, required this.onVehicleAdded});

  @override
  State<_PublishForm> createState() => _PublishFormState();
}

class _PublishFormState extends State<_PublishForm> {
  final _formKey = GlobalKey<FormState>();
  final _fromLandmark = TextEditingController();
  final _toLandmark = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  TripKind _kind = TripKind.intercity;
  CameroonCity _from = CameroonCities.all[0];
  CameroonCity _to = CameroonCities.all[1];
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  late String? _vehicleId = widget.vehicles.isEmpty ? null : widget.vehicles.first.id;
  int _seats = 3;
  bool _womenOnly = false;
  bool _luggage = true;
  bool _smoking = false;
  bool _instant = true;
  bool _busy = false;

  Vehicle? get _vehicle => widget.vehicles.where((v) => v.id == _vehicleId).firstOrNull;

  /// The time typed by the driver is Cameroon time (UTC+1).
  DateTime get _departureUtc =>
      DateTime.utc(_date.year, _date.month, _date.day, _time.hour, _time.minute).subtract(Formatters.cameroonOffset);

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate() || _vehicle == null) return;
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
        womenOnly: _womenOnly,
        luggageAllowed: _luggage,
        smokingAllowed: _smoking,
        instantBooking: _instant,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      Get.snackbar('publish.done'.tr, Formatters.departure(trip.departureAt),
          backgroundColor: CocoColors.keySuccess.withAlpha(230), colorText: CocoColors.keyWhite);
      Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: trip.id);
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find();
    final isWoman = session.profile.value?.gender == Gender.female;
    final maxSeats = _vehicle?.passengerSeats ?? 4;
    if (_seats > maxSeats) _seats = maxSeats;

    DropdownButtonFormField<CameroonCity> cityPicker(String label, CameroonCity value, ValueChanged<CameroonCity> onChanged) =>
        DropdownButtonFormField<CameroonCity>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [for (final c in CameroonCities.all) DropdownMenuItem(value: c, child: Text(c.name))],
          onChanged: (c) => setState(() => onChanged(c!)),
        );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('publish.title'.tr, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<TripKind>(
            segments: [
              ButtonSegment(value: TripKind.intercity, label: Text('publish.intercity'.tr)),
              ButtonSegment(value: TripKind.urban, label: Text('publish.urban'.tr)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          cityPicker('search.from'.tr, _from, (c) => _from = c),
          const SizedBox(height: 10),
          TextFormField(
            controller: _fromLandmark,
            decoration: InputDecoration(labelText: 'publish.fromLandmark'.tr, hintText: 'Carrefour Ndokoti'),
            validator: (v) => v == null || v.trim().isEmpty ? 'common.required'.tr : null,
          ),
          const SizedBox(height: 12),
          if (_kind == TripKind.intercity) ...[
            cityPicker('search.to'.tr, _to, (c) => _to = c),
            const SizedBox(height: 10),
          ],
          TextFormField(
            controller: _toLandmark,
            decoration: InputDecoration(labelText: 'publish.toLandmark'.tr, hintText: 'Total Mvan'),
            validator: (v) => v == null || v.trim().isEmpty ? 'common.required'.tr : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(Formatters.day(_date)),
                  onPressed: () async {
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(_time.format(context)),
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _vehicleId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'publish.vehicle'.tr),
                  items: [for (final v in widget.vehicles) DropdownMenuItem(value: v.id, child: Text(v.label, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => _vehicleId = v),
                  validator: (v) => v == null ? 'common.required'.tr : null,
                ),
              ),
              IconButton(
                tooltip: 'publish.addVehicle'.tr,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  if (await showAddVehicleDialog()) widget.onVehicleAdded();
                },
              ),
            ],
          ),
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
          TextFormField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'publish.price'.tr, suffixText: 'FCFA'),
            validator: (v) {
              final price = int.tryParse(v ?? '');
              return price == null || price <= 0 || price > 100000 ? 'common.required'.tr : null;
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('trip.instant'.tr), value: _instant, onChanged: (v) => setState(() => _instant = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('trip.luggage'.tr), value: _luggage, onChanged: (v) => setState(() => _luggage = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('trip.smoking'.tr), value: _smoking, onChanged: (v) => setState(() => _smoking = v)),
          if (isWoman)
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('trip.womenOnly'.tr), value: _womenOnly, onChanged: (v) => setState(() => _womenOnly = v)),
          TextFormField(controller: _notes, maxLines: 2, decoration: InputDecoration(labelText: 'trip.notes'.tr)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _publish, child: Text('publish.button'.tr)),
        ],
      ),
    );
  }
}

/// Returns true when a vehicle was added.
Future<bool> showAddVehicleDialog() async {
  final make = TextEditingController();
  final model = TextEditingController();
  final color = TextEditingController();
  final plate = TextEditingController();
  var seats = 4;
  final formKey = GlobalKey<FormState>();
  String? required(String? v) => v == null || v.trim().isEmpty ? 'common.required'.tr : null;

  final added = await Get.dialog<bool>(StatefulBuilder(
    builder: (context, setState) => AlertDialog(
      title: Text('publish.addVehicle'.tr),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: make, decoration: InputDecoration(labelText: 'vehicle.make'.tr), validator: required),
              TextFormField(controller: model, decoration: InputDecoration(labelText: 'vehicle.model'.tr), validator: required),
              TextFormField(controller: color, decoration: InputDecoration(labelText: 'vehicle.color'.tr), validator: required),
              TextFormField(
                controller: plate,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: 'vehicle.plate'.tr, hintText: 'LT 123 AB'),
                validator: required,
              ),
              DropdownButtonFormField<int>(
                initialValue: seats,
                decoration: InputDecoration(labelText: 'vehicle.seats'.tr),
                items: [for (var i = 1; i <= 8; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                onChanged: (v) => setState(() => seats = v ?? 4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            try {
              await Get.find<CocoApi>().addVehicle(
                make: make.text.trim(),
                model: model.text.trim(),
                color: color.text.trim(),
                plateNumber: plate.text.trim(),
                passengerSeats: seats,
              );
              Get.back(result: true);
            } catch (e) {
              UtilityFunctions.showErrorSnackBar(Formatters.error(e));
            }
          },
          child: Text('profile.save'.tr),
        ),
      ],
    ),
  ));
  return added == true;
}
