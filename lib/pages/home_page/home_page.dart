import 'package:coco_rider/common/widgets/responsive_layout.dart';
import 'package:coco_rider/common/widgets/responsive_layout_controller.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/constants/coco_constants.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/home_page/home_page_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(ResponsiveLayoutController());
    return const ResponsiveLayout(
      smallScreenWidget: _HomePage(),
      mediumScreenWidget: _HomePage(),
      largeScreenWidget: _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    Get.put(HomePageController());
    final HomePageController homePageController = Get.find();

    return SizedBox(
      height: height - CocoConstants.defaultSmallScreenAppBarHeight - 120,
      child: Center(
        child: Container(
          width: CocoConstants.cocoTextFieldDefaultWidth * 1.10,
          padding: const EdgeInsets.all(10.0),
          margin: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: CocoColors.keyGrey,
                  blurRadius: 10,
                  offset: Offset(0, 3))
            ],
          ),
          child: Wrap(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TextField(
                    controller: homePageController.departureTextController,
                    hint: InternalizationKeys.hintForDepartureTextField,
                    icon: const Icon(Icons.location_history),
                    textInputType: TextInputType.text,
                  ),
                  const SizedBox(height: 10),
                  _TextField(
                    controller: homePageController.destinationTextController,
                    textInputType: TextInputType.text,
                    icon: const Icon(Icons.location_pin),
                    hint: InternalizationKeys.hintForArrivalTextField.tr,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          controller:
                              homePageController.reservationDateTextController,
                          textInputType: TextInputType.datetime,
                          icon: const Icon(Icons.calendar_month_rounded),
                          hint: InternalizationKeys
                              .hintForReservationDateTextField.tr,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TextField(
                        width: 100,
                        controller: homePageController
                            .numberOfReservationsTextController,
                        textInputType: TextInputType.number,
                        icon: const Icon(Icons.person_2_outlined),
                        hint: InternalizationKeys
                            .hintForNumberOfReservationsTextField,
                        formatters: [LengthLimitingTextInputFormatter(1)],
                      ),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType textInputType;
  final List<TextInputFormatter>? formatters;
  final Widget icon;
  final String hint;
  final double? width;

  const _TextField({
    super.key,
    required this.controller,
    required this.textInputType,
    required this.icon,
    required this.hint,
    this.formatters,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CocoConstants.cocoTextFieldDefaultHeight,
      width: width,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.bodyLarge,
        keyboardType: textInputType,
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: icon,
          ),
          hintText: hint,
        ),
        readOnly: true,
        showCursor: true,
        inputFormatters: formatters,
      ),
    );
  }
}
