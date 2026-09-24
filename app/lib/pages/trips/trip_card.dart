import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A trip in a list: route, departure, price, seats and driver.
class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final Widget? trailing;

  const TripCard({super.key, required this.trip, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = trip.driver.rating;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      Formatters.departure(trip.departureAt),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    Formatters.price(trip.pricePerSeatXaf),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Stop(icon: Icons.radio_button_checked, place: trip.origin),
              _Stop(icon: Icons.location_on, place: trip.destination),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.person, size: 18),
                  const SizedBox(width: 4),
                  Text(trip.driver.firstName),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 16),
                  Text(rating == null ? 'trip.newRating'.tr : '${rating.toStringAsFixed(1)} (${trip.driver.reviewCount})'),
                  const Spacer(),
                  Text('trip.seatsLeft'.trParams({'count': '${trip.seatsAvailable}'})),
                ],
              ),
              if (trip.womenOnly || trailing != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (trip.womenOnly) Chip(label: Text('trip.womenOnly'.tr), visualDensity: VisualDensity.compact),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  final IconData icon;
  final Place place;

  const _Stop({required this.icon, required this.place});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(place.label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
