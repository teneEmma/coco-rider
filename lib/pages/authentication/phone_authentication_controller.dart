import 'package:coco_rider/common/widgets/coco_button.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/authentication/phone_authentication.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class PhoneAuthenticationController extends GetxController {
  /// Text controller for the textField in [PhoneAuthentication].
  final phoneNumberTextController = TextEditingController();

  /// Error text for the phone number text field.
  final Rx<String?> phoneNumberTextFieldError = ''.obs;

  /// Button state for button to authenticate.
  final Rx<CocoButtonState> buttonState = CocoButtonState.initialState.obs;

  /// Callback function to authenticate a user.
  bool _onValidate() => RegExp(r'^6[7895][0-9]{7}$')
      .hasMatch(removeSpacesInNumber(phoneNumberTextController.text));

  Future<void> authenticateUser() async {
    if (!_onValidate()) {
      phoneNumberTextFieldError.value =
          InternalizationKeys.errorFormatPhoneNumber.tr;
      return;
    }
    phoneNumberTextFieldError.value = '';
  }

  String removeSpacesInNumber(String number) {
    return number.removeAllWhitespace;
  }

  void onPhoneNumberTextChanged() {
    if (phoneNumberTextFieldError.value?.isNotEmpty == true) {
      phoneNumberTextFieldError.value = '';
    }
    final digitsOnlyRegex = RegExp(r'^[0-9]+$');
    if (!digitsOnlyRegex.hasMatch(phoneNumberTextController.text)) {
      phoneNumberTextFieldError.value =
          InternalizationKeys.errorNonDigitInNumber.tr;
    }
  }
}
