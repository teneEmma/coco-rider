import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/pages/authentication/otp_page.dart';
import 'package:coco_rider/pages/authentication/sign_in_page.dart';
import 'package:coco_rider/pages/chat/chat_page.dart';
import 'package:coco_rider/pages/chat/inbox_page.dart';
import 'package:coco_rider/pages/documents/documents_page.dart';
import 'package:coco_rider/pages/home_page/home_page.dart';
import 'package:coco_rider/pages/profile/profile_page.dart';
import 'package:coco_rider/pages/profile/profile_setup_page.dart';
import 'package:coco_rider/pages/publish/add_vehicle_page.dart';
import 'package:coco_rider/pages/start_page.dart';
import 'package:coco_rider/pages/tracking/live_tracking_page.dart';
import 'package:coco_rider/pages/trips/trip_details_page.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';

class CocoNavigation {
  static List<GetPage> pages = [
    GetPage(name: CocoRoutes.keyStartPage, page: () => const StartPage()),
    GetPage(name: CocoRoutes.keyAuthenticationPage, page: () => const SignInPage()),
    GetPage(name: CocoRoutes.keyOTPVerificationCodePage, page: () => const OtpPage(), arguments: String),
    GetPage(name: CocoRoutes.keyHomePage, page: () => const HomePage()),
    GetPage(name: CocoRoutes.keyProfileSetupPage, page: () => const ProfileSetupPage()),
    GetPage(name: CocoRoutes.keyProfilePage, page: () => const ProfilePage()),
    GetPage(name: CocoRoutes.keyDocumentsPage, page: () => const DocumentsPage()),
    GetPage(name: CocoRoutes.keyInboxPage, page: () => const InboxPage()),
    GetPage(name: CocoRoutes.keyAddVehiclePage, page: () => const AddVehiclePage()),
    GetPage(name: CocoRoutes.keyTrackingPage, page: () => const LiveTrackingPage(), arguments: String),
    GetPage(name: CocoRoutes.keyChatPage, page: () => const ChatPage(), arguments: String),
    GetPage(name: CocoRoutes.keyTripDetailsPage, page: () => const TripDetailsPage(), arguments: String),
  ];
}
