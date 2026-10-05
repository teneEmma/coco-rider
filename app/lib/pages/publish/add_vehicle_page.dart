import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Add a vehicle". Returns true (Get.back result) when the vehicle was saved.
class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  int _seats = 4;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_make, _model, _color, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Get.find<CocoApi>().addVehicle(
        make: _make.text.trim(),
        model: _model.text.trim(),
        color: _color.text.trim(),
        plateNumber: _plate.text.trim(),
        passengerSeats: _seats,
      );
      Get.back(result: true);
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) => v == null || v.trim().isEmpty ? 'common.required'.tr : null;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text('publish.addVehicle'.tr)),
      body: SafeArea(
        child: ContentWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                SectionTitle('vehicle.general'.tr),
                TextFormField(
                  controller: _make,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(hintText: 'vehicle.make'.tr, prefixIcon: Icon(Icons.directions_car_filled_rounded, color: primary)),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(hintText: 'vehicle.model'.tr, prefixIcon: Icon(Icons.car_repair_rounded, color: primary)),
                  validator: required,
                ),
                const SizedBox(height: 20),
                SectionTitle('vehicle.identification'.tr),
                TextFormField(
                  controller: _plate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(hintText: 'vehicle.plateHint'.tr, prefixIcon: Icon(Icons.pin_rounded, color: primary)),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _color,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: 'vehicle.color'.tr, prefixIcon: Icon(Icons.palette_rounded, color: primary)),
                  validator: required,
                ),
                const SizedBox(height: 8),
                SettingRow(
                  icon: Icons.event_seat_rounded,
                  label: 'vehicle.seats'.tr,
                  trailing: QuantityStepper(value: _seats, max: 8, onChanged: (v) => setState(() => _seats = v), semanticLabel: 'vehicle.seats'.tr),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('vehicle.save'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
