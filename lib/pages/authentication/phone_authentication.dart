import 'dart:ui';

import 'package:coco_rider/common/theme/coco_text_styles.dart';
import 'package:coco_rider/common/widgets/coco_button.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/constants/coco_constants.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/authentication/phone_authentication_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class PhoneAuthentication extends StatelessWidget {
  const PhoneAuthentication({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(PhoneAuthenticationController());
    final PhoneAuthenticationController phoneAuthenticationController =
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      child: Text(
                        InternalizationKeys.enterPhoneNumberText.tr,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 380, maxHeight: 70),
                      child: TextField(
                        controller: phoneAuthenticationController
                            .phoneNumberTextController,
                        textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              wordSpacing: 3,
                              letterSpacing: 2,
                            ),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  ImageKeys.keyCameroonFlag,
                                  width: 35,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  InternalizationKeys
                                      .prefixForPhoneNumberTextField,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                          hintText:
                              InternalizationKeys.hintForPhoneNumberTextField,
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            CocoConstants.phoneNumbersLengthLimit,
                          ),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (newStr) => {
                          phoneAuthenticationController
                              .onPhoneNumberTextChanged()
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 10),
                      child: Obx(
                        () => Visibility(
                          visible: phoneAuthenticationController
                                  .phoneNumberTextFieldError
                                  .value
                                  ?.isNotEmpty ==
                              true,
                          child: Text(
                            phoneAuthenticationController
                                    .phoneNumberTextFieldError.value ??
                                '',
                            style: CocoTextStyles.errorMsgTextStyle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                CocoButton(
                  buttonState: phoneAuthenticationController.buttonState,
                  onValidate: () =>
                      phoneAuthenticationController.authenticateUser(),
                  normalStateText: InternalizationKeys.nextText.tr,
                )
              ],
            ),
          ),
        ));
  }
}
