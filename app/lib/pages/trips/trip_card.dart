import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A trip as a "ticket" (Figma): route, departure, seats, vehicle, driver and price.
class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;

  /// Shown at the top of the ticket (e.g. the booking status).
  final Widget? status;

  /// Actions under the ticket (buttons).
  final Widget? trailing;

  const TripCard({super.key, required this.trip, this.onTap, this.status, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = scheme.surfaceContainerLow;
    final rating = trip.driver.rating;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status != null) ...[Center(child: status!), const SizedBox(height: 8)],
                Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: RouteHeader(trip: trip)),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: LabeledValue(label: 'ticket.departure'.tr, value: Formatters.departure(trip.departureAt)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Semantics(
                          label: 'trip.seatsLeft'.trParams({'count': '${trip.seatsAvailable}'}),
                          excludeSemantics: true,
                          child: LabeledValue(
                            label: 'ticket.seats'.tr,
                            value: '${trip.seatsAvailable}',
                            alignment: CrossAxisAlignment.end,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _TicketDivider(background: theme.scaffoldBackgroundColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Image.asset(ImageKeys.figmaTicketCar, width: 40, excludeFromSemantics: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip.vehicle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Icon(Icons.person, size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Flexible(child: Text(trip.driver.firstName, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                              const SizedBox(width: 6),
                              const Icon(Icons.star_rounded, size: 15, color: CocoColors.keyWarning),
                              const SizedBox(width: 2),
                              Text(
                                rating == null ? 'trip.newRating'.tr : '${rating.toStringAsFixed(1)} (${trip.driver.reviewCount})',
                                style: theme.textTheme.bodySmall,
                              ),
                            ]),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 34, color: scheme.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 12)),
                      Image.asset(ImageKeys.figmaMoney, width: 32, excludeFromSemantics: true),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ticket.price'.tr, style: theme.textTheme.labelSmall),
                          Text(Formatters.price(trip.pricePerSeatXaf), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 14),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: trailing!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "DOUALA ⌒🚗⌒ YAOUNDÉ" with the landmarks under the cities.
class RouteHeader extends StatelessWidget {
  final Trip trip;

  const RouteHeader({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget end(Place place, CrossAxisAlignment alignment) => Column(
          crossAxisAlignment: alignment,
          children: [
            Text(place.city.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              place.landmark,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: alignment == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start,
              style: theme.textTheme.labelSmall,
            ),
          ],
        );

    return Semantics(
      label: '${trip.origin.label} → ${trip.destination.label}',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(flex: 4, child: end(trip.origin, CrossAxisAlignment.start)),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Icon(Icons.directions_car_filled_outlined, size: 18, color: theme.colorScheme.onSurface),
                const SizedBox(height: 2),
                const Row(children: [
                  _Dot(),
                  Expanded(child: DashedLine()),
                  _Dot(),
                ]),
                const SizedBox(height: 3),
                Text(
                  'tripKind.${trip.kind.name}'.tr,
                  style: theme.textTheme.labelSmall?.copyWith(color: CocoColors.keyWarning, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(flex: 4, child: end(trip.destination, CrossAxisAlignment.end)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: const BoxDecoration(color: CocoColors.keySuccess, shape: BoxShape.circle),
      );
}

/// Dashed line with a half-circle notch on each side, like a tear-off ticket.
class _TicketDivider extends StatelessWidget {
  final Color background;

  const _TicketDivider({required this.background});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: DashedLine()),
            Positioned(left: -10, child: _notch()),
            Positioned(right: -10, child: _notch()),
          ],
        ),
      );

  Widget _notch() => Container(width: 20, height: 20, decoration: BoxDecoration(color: background, shape: BoxShape.circle));
}
