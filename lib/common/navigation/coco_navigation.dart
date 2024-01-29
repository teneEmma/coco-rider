import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/pages/authentication/otp_code_verification.dart';
import 'package:coco_rider/pages/authentication/phone_authentication.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';

class CocoNavigation {
  static List<GetPage> pages = [
    GetPage(
      name: CocoRoutes.keyAuthenticationPage,
      page: () => const PhoneAuthentication(),
    ),
    GetPage(
      name: CocoRoutes.keyOTPVerificationCode,
      page: () => const OTPCodeVerification(),
    ),
  ];
}
