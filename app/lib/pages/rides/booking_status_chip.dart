import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BookingStatusChip extends StatelessWidget {
  final BookingStatus status;

  const BookingStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BookingStatus.confirmed || BookingStatus.completed => CocoColors.keySuccess,
      BookingStatus.pending => const Color(0xFF9A5B00),
      BookingStatus.rejectedByDriver || BookingStatus.tripCancelled || BookingStatus.noShow => CocoColors.keyError,
      BookingStatus.cancelledByPassenger => CocoColors.keyGrey,
    };
    return StatusChip(label: 'bookingStatus.${status.name}'.tr, color: color);
  }
}
