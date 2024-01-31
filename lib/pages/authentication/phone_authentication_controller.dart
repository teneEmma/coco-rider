import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/coco_button.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/authentication/phone_authentication.dart';
import 'package:coco_rider/services/authentication/auth.dart';
import 'package:coco_rider/services/authentication/authentication_response.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PhoneAuthenticationController extends GetxController {
  /// Error messages from network requests to be displayed by a snackBar.
  final RxString errorMessage = ''.obs;

  /// Text controller for the textField in [PhoneAuthentication].
  final phoneNumberTextController = TextEditingController();

  /// Error text for the phone number text field.
  final Rx<String?> phoneNumberTextFieldError = ''.obs;

  /// Button state for button to authenticate.
  final Rx<CocoButtonState> buttonState = CocoButtonState.initialState.obs;

  /// Callback function to authenticate a user.
  bool _onValidatePhoneNumber() => RegExp(r'^6[7895][0-9]{7}$')
      .hasMatch(removeSpacesInNumber(phoneNumberTextController.text));

  @override
  void onInit() {
    errorMessage.listen((msg) {
      UtilityFunctions.showErrorSnackBar(msg);
    });
    super.onInit();
  }

  Future<void> authenticateUserWithPhoneNumber(Auth auth) async {
    if (!_onValidatePhoneNumber()) {
      phoneNumberTextFieldError.value =
          InternalizationKeys.errorFormatPhoneNumber.tr;
      return;
    }
    phoneNumberTextFieldError.value = '';
    await setButtonState(CocoButtonState.onLoading);

    PhoneNumberAuthenticationParameter param =
        PhoneNumberAuthenticationParameter(
      phoneNumber: UtilityFunctions.addCountryCodeToPhoneNumber(
          phoneNumberTextController.text),
      onVerificationCompleted: () => setButtonState(CocoButtonState.onSuccess),
      onVerificationFailed: (error) {
        UtilityFunctions.debugPrint('IT HAS BEEN CALLED HERE');
        updateErrorMessage(error);
        setButtonState(CocoButtonState.onError);
      },
      onVerificationCodeSent: () {
        setButtonState(CocoButtonState.onSuccess);
        Get.toNamed(
          CocoRoutes.keyOTPVerificationCode,
          arguments: UtilityFunctions.addCountryCodeToPhoneNumber(
              phoneNumberTextController.text),
        );
      },
      onVerificationAutoRetrievalTimeout: () =>
          updateErrorMessage(InternalizationKeys.errorAutoRetrievalTimeOut.tr),
    );
    final result = await auth.authenticateWithPhoneNumber(param);
    if (result == AuthenticationResponse.verificationFailed) {
      updateErrorMessage(InternalizationKeys.errorOccurred.tr);
    }
  }

  /// Method which updates the error message depending on the new value
  /// which is to be assigned.
  void updateErrorMessage(String newValue) {
    if (newValue == errorMessage.value) {
      errorMessage.refresh();
      return;
    }
    errorMessage.value = newValue;
  }

  Future<void> setButtonState(
    CocoButtonState btnState, {
    CocoButtonState nextBtnState = CocoButtonState.initialState,
  }) async {
    buttonState.value = btnState;
    if (btnState == CocoButtonState.onLoading) {
      return;
    }
    Future.delayed(
      const Duration(milliseconds: 1000),
      () => buttonState.value = nextBtnState,
    );
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
