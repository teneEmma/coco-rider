import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/widgets/coco_button.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/authentication/phone_authentication.dart';
import 'package:coco_rider/services/authentication_response.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class PhoneAuthenticationController extends GetxController {
  // Todo: To be kept in Auth class.
  late String? authVerificationCode = null;

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
    print('👉👉👉 authentication started 👈👈👈');
    await setButtonState(CocoButtonState.onLoading);

    // TODO: All these auth stuffs should be kept in an appSpecific Class called Auth.
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: addCountryCodeToPhoneNumber(phoneNumberTextController.text),
      verificationCompleted: (phoneAuthCredential) {
        print('👍 verification completed$phoneAuthCredential');
        setButtonState(CocoButtonState.onSuccess);
      },
      verificationFailed: (authException) {
        print('🚫 verification failed $authException');
        switch (authException.code) {
          case 'network-request-failed':
            // Todo: Show snackbar to tell user there is no internet connection,
            setButtonState(CocoButtonState.initialState);
          default:
            setButtonState(CocoButtonState.onError);
        }
      },
      codeSent: (verifId, token) {
        print('📲 code sent $verifId && $token');
        setButtonState(CocoButtonState.onSuccess);
        authVerificationCode = verifId;
        Get.toNamed(CocoRoutes.keyOTPVerificationCode);
      },
      codeAutoRetrievalTimeout: (verifId) {},
    );
  }

  //TODO: This function should equally ke kept in the Auth Class.
  Future<AuthenticationResponse> authenticateWithCredentials(
      String codeEntered) async {
    if (authVerificationCode == null) {
      return AuthenticationResponse.failed;
    }
    PhoneAuthCredential phoneAuthCredential = PhoneAuthProvider.credential(
      verificationId: authVerificationCode ?? '',
      smsCode: codeEntered,
    );

    try {
      final value =
          await FirebaseAuth.instance.signInWithCredential(phoneAuthCredential);
      return (value.user?.uid != null)
          ? AuthenticationResponse.successful
          : AuthenticationResponse.failed;
    } catch (e) {
      print('\t\t\tException in phone_authentication_controller.dart');
      print('😓😓😓\n${e}');
      return AuthenticationResponse.failed;
    }
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

  String addCountryCodeToPhoneNumber(String phoneNumber) =>
      '${InternalizationKeys.prefixForPhoneNumberTextField}$phoneNumber';

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
