import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/constants/cameroon_cities.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/pages/trips/trip_card.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class TripSearchController extends GetxController {
  final CocoApi api;

  TripSearchController(this.api);

  final fromText = TextEditingController();
  final toText = TextEditingController();
  /// Optional filters: null means any day / any number of seats.
  final date = Rxn<DateTime>();
  final seats = RxnInt();
  final loading = false.obs;
  final locating = false.obs;
  final Rx<List<Trip>?> results = Rx<List<Trip>?>(null);
  final RxnString error = RxnString();

  Future<void> search() async {
    loading.value = true;
    error.value = null;
    try {
      results.value = await api.searchTrips(TripSearch(
        date: date.value,
        fromCity: fromText.text.trim(),
        toCity: toText.text.trim(),
        seats: seats.value,
      ));
    } catch (e) {
      error.value = Formatters.error(e);
    } finally {
      loading.value = false;
    }
  }

  /// Fills the departure with the city closest to the phone's position.
  Future<void> useMyLocation() async {
    locating.value = true;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        UtilityFunctions.showErrorSnackBar('search.locationDenied'.tr);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
      );
      fromText.text = CameroonCities.nearest(position.latitude, position.longitude).name;
    } catch (_) {
      UtilityFunctions.showErrorSnackBar('search.locationFailed'.tr);
    } finally {
      locating.value = false;
    }
  }

  @override
  void onClose() {
    fromText.dispose();
    toText.dispose();
    super.onClose();
  }
}

/// Home tab: "where to?" — find a trip by city, day and number of seats.
class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TripSearchController(Get.find()));
    final theme = Theme.of(context);

    return SheetScrollView(
      hero: const _Hero(),
      title: 'search.title'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: CityField(
                controller: controller.fromText,
                hint: 'search.from'.tr,
                icon: Icons.trip_origin,
              ),
            ),
            const SizedBox(width: 10),
            Obx(() => SquareIconButton(
                  icon: Icons.my_location,
                  tooltip: 'search.useLocation'.tr,
                  busy: controller.locating.value,
                  onPressed: controller.useMyLocation,
                )),
          ]),
          const SizedBox(height: 12),
          CityField(
            controller: controller.toText,
            hint: 'search.to'.tr,
            icon: Icons.directions_car_filled,
            tinted: true,
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: DashedLine()),
          Row(children: [
            Expanded(
              flex: 5,
              child: Obx(() {
                final date = controller.date.value;
                return PillButton(
                  icon: Icons.calendar_month_rounded,
                  label: date == null ? 'search.anyDate'.tr : Formatters.shortDay(date),
                  trailing: date == null ? null : _ClearFilter(onTap: () => controller.date.value = null),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) controller.date.value = picked;
                  },
                );
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Obx(() {
                final seats = controller.seats.value;
                return PillButton(
                  icon: Icons.people_alt_rounded,
                  label: seats == null ? 'search.anySeats'.tr : 'search.seatCount'.trParams({'count': '$seats'}),
                  trailing: seats == null ? null : _ClearFilter(onTap: () => controller.seats.value = null),
                  onTap: () async {
                    final picked = await _pickSeats(context, seats);
                    if (picked != null) controller.seats.value = picked;
                  },
                );
              }),
            ),
          ]),
          const SizedBox(height: 18),
          Obx(() => FilledButton.icon(
                icon: const Icon(Icons.search_rounded),
                label: Text('search.button'.tr),
                onPressed: controller.loading.value ? null : controller.search,
              )),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.loading.value) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            if (controller.error.value != null) {
              return Padding(padding: const EdgeInsets.all(16), child: Text(controller.error.value!, textAlign: TextAlign.center));
            }
            final trips = controller.results.value;
            if (trips == null) {
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Image.asset(ImageKeys.figmaSkyline, fit: BoxFit.fitWidth, excludeFromSemantics: true),
              );
            }
            if (trips.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Icon(Icons.travel_explore_rounded, size: 44, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 10),
                  Text('search.noResults'.tr, textAlign: TextAlign.center),
                ]),
              );
            }
            Future<void> open(Trip trip) async {
              await Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: trip.id);
              // Seats may have changed (e.g. the user just booked).
              controller.search();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                Text('search.results'.trParams({'count': '${trips.length}'}), style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final trip in trips)
                  TripCard(
                    trip: trip,
                    onTap: () => open(trip),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: CocoColors.keyInk, foregroundColor: CocoColors.keyWhite),
                      onPressed: () => open(trip),
                      child: Text('search.viewTrip'.tr),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  static Future<int?> _pickSeats(BuildContext context, int? current) => showModalBottomSheet<int>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('search.seats'.tr, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var i = 1; i <= 4; i++)
                ListTile(
                  title: Text('search.seatCount'.trParams({'count': '$i'})),
                  trailing: i == current ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () => Navigator.of(context).pop(i),
                ),
            ],
          ),
        ),
      );
}

/// Small ✕ inside a filter pill that removes the filter.
class _ClearFilter extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearFilter({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'search.clearFilter'.tr,
        child: InkResponse(
          onTap: onTap,
          radius: 18,
          child: Icon(Icons.close_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('home.tagline'.tr, style: theme.textTheme.headlineSmall?.copyWith(color: CocoColors.keyWhite)),
                  const SizedBox(height: 6),
                  Text('home.subtitle'.tr, style: theme.textTheme.bodyMedium?.copyWith(color: CocoColors.keyWhite.withAlpha(190))),
                  const SizedBox(height: 26),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(ImageKeys.figmaHero, height: 170, fit: BoxFit.contain, excludeFromSemantics: true),
          ],
        ),
      ),
    );
  }
}

/// A pill-shaped text field that suggests Cameroonian cities but accepts any value.
class CityField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  /// Pale blue background, as the "Where to?" field in the design.
  final bool tinted;

  const CityField({super.key, required this.controller, required this.hint, required this.icon, this.tinted = false});

  @override
  State<CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<CityField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = CameroonCities.fold(value.text);
        if (query.isEmpty) return const Iterable<String>.empty();
        return CameroonCities.all.map((c) => c.name).where((name) => CameroonCities.fold(name).startsWith(query));
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) => TextField(
        controller: textController,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon, color: scheme.primary),
          fillColor: widget.tinted ? scheme.primaryContainer : null,
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    leading: const Icon(Icons.location_city_rounded),
                    title: Text(option),
                    onTap: () => onSelected(option),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
