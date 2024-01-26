import 'package:coco_rider/navigation/routes.dart';
import 'package:coco_rider/pages/authentication/phone_authentication.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';

class CocoNavigation {
  static List<GetPage> pages = [
    GetPage(
      name: CocoRoutes.keyAuthenticationPage,
      page: () => const PhoneAuthentication(),
    ),
  ];
}
