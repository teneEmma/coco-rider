import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/constants/cameroon_cities.dart';
import 'package:coco_rider/pages/trips/trip_card.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TripSearchController extends GetxController {
  final CocoApi api;

  TripSearchController(this.api);

  final from = ''.obs;
  final to = ''.obs;
  final date = DateTime.now().obs;
  final seats = 1.obs;
  final loading = false.obs;
  final Rx<List<Trip>?> results = Rx<List<Trip>?>(null);
  final RxnString error = RxnString();

  Future<void> search() async {
    loading.value = true;
    error.value = null;
    try {
      results.value = await api.searchTrips(TripSearch(
        date: date.value,
        fromCity: from.value,
        toCity: to.value,
        seats: seats.value,
      ));
    } catch (e) {
      error.value = Formatters.error(e);
    } finally {
      loading.value = false;
    }
  }
}

/// Home tab: find a trip by city and day.
class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TripSearchController(Get.find()));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CityField(
                        label: 'search.from'.tr,
                        icon: Icons.radio_button_checked,
                        initialValue: controller.from.value,
                        onChanged: (v) => controller.from.value = v,
                      ),
                      const SizedBox(height: 10),
                      CityField(
                        label: 'search.to'.tr,
                        icon: Icons.location_on,
                        initialValue: controller.to.value,
                        onChanged: (v) => controller.to.value = v,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() => OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text(Formatters.day(controller.date.value)),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: controller.date.value,
                                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                      lastDate: DateTime.now().add(const Duration(days: 90)),
                                    );
                                    if (picked != null) controller.date.value = picked;
                                  },
                                )),
                          ),
                          const SizedBox(width: 10),
                          Obx(() => DropdownButton<int>(
                                value: controller.seats.value,
                                items: [
                                  for (var i = 1; i <= 4; i++)
                                    DropdownMenuItem(value: i, child: Text('$i ${'search.seats'.tr}')),
                                ],
                                onChanged: (v) => controller.seats.value = v ?? 1,
                              )),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Obx(() => FilledButton.icon(
                            icon: const Icon(Icons.search),
                            label: Text('search.button'.tr),
                            onPressed: controller.loading.value ? null : controller.search,
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                if (controller.loading.value) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                if (controller.error.value != null) {
                  return Padding(padding: const EdgeInsets.all(16), child: Text(controller.error.value!, textAlign: TextAlign.center));
                }
                final trips = controller.results.value;
                if (trips == null) return const SizedBox.shrink();
                if (trips.isEmpty) {
                  return Padding(padding: const EdgeInsets.all(16), child: Text('search.noResults'.tr, textAlign: TextAlign.center));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('search.results'.trParams({'count': '${trips.length}'}), style: Theme.of(context).textTheme.titleSmall),
                    for (final trip in trips)
                      TripCard(
                        trip: trip,
                        onTap: () async {
                          await Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: trip.id);
                          // Seats may have changed (e.g. the user just booked).
                          controller.search();
                        },
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field that suggests Cameroonian cities but accepts any value.
class CityField extends StatelessWidget {
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final String? initialValue;

  const CityField({super.key, required this.label, required this.icon, required this.onChanged, this.initialValue});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: initialValue == null ? null : TextEditingValue(text: initialValue!),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return CameroonCities.all.map((c) => c.name).where((name) => name.toLowerCase().startsWith(query));
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, textController, focusNode, onSubmit) => TextField(
        controller: textController,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        onChanged: onChanged,
      ),
    );
  }
}
