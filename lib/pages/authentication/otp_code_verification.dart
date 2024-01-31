import 'dart:ui';

import 'package:coco_rider/services/authentication/auth.dart';
import 'package:coco_rider/services/authentication/authentication_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../constants/coco_colors.dart';
import '../../constants/image_keys.dart';
import '../../constants/internalization.dart';
import 'otp_code_verification_controller.dart';

class OTPCodeVerification extends StatelessWidget {
  const OTPCodeVerification({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(OTPCodeVerificationController());
    final OTPCodeVerificationController otpCodeVerificationController =
        Get.find();
    final Auth auth = Get.find();
    if (otpCodeVerificationController.phoneNumber == null) {
      Get.back();
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 70,
        elevation: 0,
        title: Center(
          child: Image.asset(
            Get.isDarkMode
                ? ImageKeys.keyLogoImageWithoutBGGreen
                : ImageKeys.keyLogoImageWithoutBGDark,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaY: 10,
              sigmaX: 10,
            ),
            child: Container(
              color: CocoColors.keyTransparent,
            ),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Obx(
            () => Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      child: Text(
                        InternalizationKeys.enterOTPCodeText.tr,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit0.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit0,
                          onTextChanged: (value) => onTextChanged(context,
                              value, otpCodeVerificationController, auth),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit1.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit1,
                          onTextChanged: (value) => onTextChanged(context,
                              value, otpCodeVerificationController, auth),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit2.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit2,
                          onTextChanged: (value) => onTextChanged(context,
                              value, otpCodeVerificationController, auth),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit3.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit3,
                          onTextChanged: (value) => onTextChanged(context,
                              value, otpCodeVerificationController, auth),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit4.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit4,
                          onTextChanged: (value) => onTextChanged(context,
                              value, otpCodeVerificationController, auth),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit5.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit5,
                          onTextChanged: (value) => onTextChanged(context,
                              value, otpCodeVerificationController, auth,
                              isLastTextField: true),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                      ],
                    ),
                  ],
                ),
                Visibility(
                  visible: otpCodeVerificationController.isLoading.value,
                  child: Center(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaY: 3,
                        sigmaX: 3,
                      ),
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TODO: Replace this logic with a button.
  Future<void> onTextChanged(
    BuildContext context,
    String value,
    OTPCodeVerificationController controller,
    Auth auth, {
    bool isLastTextField = false,
  }) async {
    final OTPCodeVerificationController controller = Get.find();
    if (isLastTextField) {
      controller.onTextChanged(value, auth);
      return;
    }

    controller.initAuthenticationResponseState();
    if (value.length == 1) {
      FocusScope.of(context).nextFocus();
    }
  }
}

class OTPDigitTextField extends StatelessWidget {
  final TextEditingController textController;
  final Function(String) onTextChanged;
  final FocusNode focusNode;
  final AuthenticationResponse authResponse;

  const OTPDigitTextField({
    super.key,
    required this.textController,
    required this.onTextChanged,
    required this.focusNode,
    required this.authResponse,
  });

  @override
  Widget build(BuildContext context) {
    final availableSpace = MediaQuery.of(context).size.width - 30;

    return SizedBox(
      height: 68,
      width: (availableSpace / 6) - 5,
      child: TextField(
        showCursor: false,
        focusNode: focusNode,
        enableInteractiveSelection: false,
        controller: textController,
        textAlign: TextAlign.center,
        onChanged: (value) => onTextChanged(value),
        style: Theme.of(context).textTheme.bodyLarge,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20.0)),
            borderSide: BorderSide(
              width: 3,
              color: authResponse == AuthenticationResponse.verificationFailed
                  ? CocoColors.keyError
                  : CocoColors.keyPrimary,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20.0)),
            borderSide: BorderSide(
              width: 3,
              color: (authResponse == AuthenticationResponse.verificationFailed
                      ? CocoColors.keyError
                      : CocoColors.keyPrimary)
                  .withAlpha(50),
            ),
          ),
          fillColor: getFillColor(context, focusNode.hasFocus),
          hintText: InternalizationKeys.hintForOTPDigitTextField,
        ),
        inputFormatters: [
          ClearingTextInputFormatter(),
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
      ),
    );
  }

  Color getFillColor(BuildContext context, bool hasFocus) {
    final focusedColor = CocoColors.keyGrey.withOpacity(0.3);
    final noFocusColor = Theme.of(context).colorScheme.background;
    return hasFocus ? focusedColor : noFocusColor;
  }
}

class ClearingTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > 1) {
      return TextEditingValue(
        text: newValue.text.substring(newValue.text.length - 1),
        selection: const TextSelection.collapsed(offset: 1),
      );
    }
    return newValue;
  }
}
