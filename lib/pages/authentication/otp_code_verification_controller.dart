import 'package:coco_rider/services/authentication_response.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OTPCodeVerificationController extends GetxController {
  @override
  void onInit() {
    focusNodeForDigit0.value.addListener(() {
      print('🤯 Listener for digit 0 called.');
      focusNodeForDigit0.refresh();
    });
    focusNodeForDigit1.value.addListener(() {
      print('🤯 Listener for digit 1 called.');
      focusNodeForDigit1.refresh();
    });
    focusNodeForDigit2.value.addListener(() {
      print('🤯 Listener for digit 2 called.');
      focusNodeForDigit2.refresh();
    });
    focusNodeForDigit3.value.addListener(() {
      print('🤯 Listener for digit 3 called.');
      focusNodeForDigit3.refresh();
    });
    focusNodeForDigit4.value.addListener(() {
      print('🤯 Listener for digit 4 called.');
      focusNodeForDigit4.refresh();
    });
    focusNodeForDigit5.value.addListener(() {
      print('🤯 Listener for digit 5 called.');
      focusNodeForDigit5.refresh();
    });

    super.onInit();
  }

  /// The value which determines if the otp code entered was correct.
  Rx<AuthenticationResponse> otpAuthResponseState =
      AuthenticationResponse.init.obs;

  /// The loading state of the screen when we begin the auth process.
  RxBool isLoading = false.obs;

  /// FocusNodes for all the 4 digits of the otp code.
  final focusNodeForDigit0 = FocusNode().obs;
  final focusNodeForDigit1 = FocusNode().obs;
  final focusNodeForDigit2 = FocusNode().obs;
  final focusNodeForDigit3 = FocusNode().obs;
  final focusNodeForDigit4 = FocusNode().obs;
  final focusNodeForDigit5 = FocusNode().obs;

  /// Controllers for all the 4 digits of the otp code.
  final _otpTextControllerDigit0 = TextEditingController();

  get otpTextControllerDigit0 => _otpTextControllerDigit0;

  final _otpTextControllerDigit1 = TextEditingController();

  get otpTextControllerDigit1 => _otpTextControllerDigit1;

  final _otpTextControllerDigit2 = TextEditingController();

  get otpTextControllerDigit2 => _otpTextControllerDigit2;

  final _otpTextControllerDigit3 = TextEditingController();

  get otpTextControllerDigit3 => _otpTextControllerDigit3;

  final _otpTextControllerDigit4 = TextEditingController();

  get otpTextControllerDigit4 => _otpTextControllerDigit4;

  final _otpTextControllerDigit5 = TextEditingController();

  get otpTextControllerDigit5 => _otpTextControllerDigit5;

  String getOTPCode() =>
      '${otpTextControllerDigit0.text}${otpTextControllerDigit1.text}${otpTextControllerDigit2.text}'
      '${otpTextControllerDigit3.text}${otpTextControllerDigit4.text}${otpTextControllerDigit5.text}';

  void initAuthenticationResponseState() {
    if (otpAuthResponseState.value == AuthenticationResponse.failed) {
      otpAuthResponseState.value = AuthenticationResponse.init;
    }
  }

  bool validateOTPCode() => RegExp(r'^\d{6}$').hasMatch(getOTPCode());
}
