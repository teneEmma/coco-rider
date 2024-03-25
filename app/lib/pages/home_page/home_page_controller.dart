import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class HomePageController extends GetxController {
  /// Text controller for departure location textField.
  final departureTextController = TextEditingController();

  /// Text controller for arrival location textField.
  final destinationTextController = TextEditingController();

  /// Text controller for travelling date textField.
  final reservationDateTextController = TextEditingController();

  /// Text controller for the number of persons customer wants to reserve.
  final numberOfReservationsTextController = TextEditingController();
}
