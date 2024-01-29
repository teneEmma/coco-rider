import 'dart:ui';

import 'package:coco_rider/pages/authentication/phone_authentication_controller.dart';
import 'package:coco_rider/services/authentication_response.dart';
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
                          onTextChanged: (value) =>
                              onTextChanged(context, value),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit1.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit1,
                          onTextChanged: (value) =>
                              onTextChanged(context, value),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit2.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit2,
                          onTextChanged: (value) =>
                              onTextChanged(context, value),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit3.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit3,
                          onTextChanged: (value) =>
                              onTextChanged(context, value),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit4.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit4,
                          onTextChanged: (value) =>
                              onTextChanged(context, value),
                          authResponse: otpCodeVerificationController
                              .otpAuthResponseState.value,
                        ),
                        OTPDigitTextField(
                          focusNode: otpCodeVerificationController
                              .focusNodeForDigit5.value,
                          textController: otpCodeVerificationController
                              .otpTextControllerDigit5,
                          onTextChanged: (value) => onTextChanged(
                              context, value,
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
                      child: CircularProgressIndicator(),
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
    String value, {
    bool isLastTextField = false,
  }) async {
    final OTPCodeVerificationController controller = Get.find();
    if (isLastTextField) {
      controller.isLoading.value = true;
      final otpCodeEntered = controller.getOTPCode();
      if (!controller.validateOTPCode()) {
        print('🔓🔓🔓 Validation for OTP code = ${otpCodeEntered} Failed.');
        return;
      }
      print('🔓🔓🔓 OTP code = ${otpCodeEntered}');
      try {
        controller.otpAuthResponseState.value =
            await Get.find<PhoneAuthenticationController>()
                .authenticateWithCredentials(otpCodeEntered);
        print(
            '🔓🔓🔓 OTP Authentication result = \n${controller.otpAuthResponseState.value}');
      } catch (e) {
        controller.otpAuthResponseState.value = AuthenticationResponse.failed;
        print('\t\t\tException in phone_authentication_controller.dart');
        print('😓😓😓\n${e}');
      }

      controller.isLoading.value = false;
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
              color: authResponse == AuthenticationResponse.failed
                  ? CocoColors.keyError
                  : CocoColors.keyPrimary,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20.0)),
            borderSide: BorderSide(
              width: 3,
              color: (authResponse == AuthenticationResponse.failed
                      ? CocoColors.keyError
                      : CocoColors.keyPrimary)
                  .withAlpha(50),
            ),
          ),
          fillColor: focusNode.hasFocus
              ? CocoColors.keyGrey.withOpacity(0.2)
              : CocoColors.keyWhite,
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
