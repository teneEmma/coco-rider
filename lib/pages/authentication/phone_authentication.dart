import 'dart:ui';

import 'package:coco_rider/common/widgets/coco_button.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/constants/coco_constants.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/pages/authentication/phone_authentication_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get_utils/get_utils.dart';

class PhoneAuthentication extends StatelessWidget {
  const PhoneAuthentication({super.key});

  @override
  Widget build(BuildContext context) {
    final phoneAuthenticationController = PhoneAuthenticationController();

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          toolbarHeight: 70,
          elevation: 0,
          title: Center(
              child: Image.asset(
            ImageKeys.keyLogoImageWithoutBGDark,
          )),
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
          backgroundColor: CocoColors.keyWhite.withAlpha(200),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 380, maxHeight: 70),
                      child: TextField(
                        controller: phoneAuthenticationController
                            .phoneNumberTextController,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontSize: 24,
                          wordSpacing: 3,
                          letterSpacing: 2,
                          color: CocoColors.keyBlack,
                        ),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: CocoColors.keyGrey.withOpacity(0.3),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(20.0)),
                            borderSide: BorderSide(
                                width: 3, color: CocoColors.keyPrimary),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(20.0)),
                            borderSide: BorderSide(
                                width: 3,
                                color: CocoColors.keyPrimary.withAlpha(50)),
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(20.0)),
                            borderSide: BorderSide(
                                width: 3, color: CocoColors.keyError),
                          ),
                          errorStyle: const TextStyle(
                            color: CocoColors.keyError,
                            fontWeight: FontWeight.w200,
                            fontStyle: FontStyle.italic,
                          ),
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
                                const Text(
                                  '+237',
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: CocoColors.keyBlack,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          prefixStyle: const TextStyle(
                            fontSize: 24,
                            color: CocoColors.keyBlack,
                          ),
                          hintText: '000 000 000',
                          hintStyle: TextStyle(
                            fontSize: 24,
                            wordSpacing: 3,
                            letterSpacing: 2,
                            color: CocoColors.keyBlack.withAlpha(80),
                          ),
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            CocoConstants.phoneNumbersLengthLimit,
                          ),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
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
