import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class UtilityFunctions {
  static String addCountryCodeToPhoneNumber(String phoneNumber) {
    if (phoneNumber
        .contains(InternalizationKeys.countryCodeForPhoneNumberTextField)) {
      return phoneNumber;
    }
    return '${InternalizationKeys.countryCodeForPhoneNumberTextField}$phoneNumber';
  }

  static void debugPrint(String msg, {String leadingIcons = ''}) {
    if (kDebugMode) {
      print('$leadingIcons $msg');
    }
  }

  static void showErrorSnackBar(String msg) {
    Get.showSnackbar(GetSnackBar(
      backgroundColor: CocoColors.keyError.withAlpha(230),
      title: InternalizationKeys.errorText.tr,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(8),
      animationDuration: const Duration(milliseconds: 100),
      forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
      reverseAnimationCurve: Curves.fastOutSlowIn,
      borderRadius: 20,
      snackStyle: SnackStyle.FLOATING,
      message: msg,
      dismissDirection: DismissDirection.horizontal,
    ));
  }
}
