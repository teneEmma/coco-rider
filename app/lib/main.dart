import 'package:coco_rider/common/navigation/coco_navigation.dart';
import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/theme/coco_theme.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/authentication/auth.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:coco_rider/services/config/app_config.dart';
import 'package:coco_rider/services/notifications/push_messaging.dart';
import 'package:coco_rider/services/notifications/push_notifications.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:coco_rider/services/tracking/position_sharing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  final auth = Get.put(Auth(AppConfig.usesCognito ? AuthType.cognito : AuthType.development));
  final api = Get.put(CocoApi(baseUrl: AppConfig.apiUrl, authHeaders: auth.authHeaders));
  final push = PushNotifications(
    messaging: FirebasePushMessaging(),
    api: api,
    onForeground: (event) => Get.snackbar(
      event.title ?? 'Coco Rider',
      event.body ?? '',
      onTap: (_) => _openFromNotification(event),
      duration: const Duration(seconds: 5),
    ),
    onOpen: _openFromNotification,
  );
  Get.put(SessionController(auth: auth, api: api, push: push));
  Get.put(PositionSharing(api: api, location: GeolocatorLocationProvider()));

  runApp(const MyApp());
}

/// A message opens the chat; other notifications about a trip open the trip details.
void _openFromNotification(PushEvent event) {
  final bookingId = event.data['bookingId'];
  if (event.data['kind'] == 'NewMessage' && bookingId != null) {
    Get.toNamed(CocoRoutes.keyChatPage, arguments: bookingId);
  } else if (event.data['kind'] == 'TripStarted' && event.tripId != null) {
    Get.toNamed(CocoRoutes.keyTrackingPage, arguments: event.tripId);
  } else if (event.tripId != null) {
    Get.toNamed(CocoRoutes.keyTripDetailsPage, arguments: event.tripId);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Coco Rider',
      translations: CocoInternalization(),
      locale: Get.deviceLocale?.languageCode == 'en'
          ? const Locale('en', 'CM')
          : const Locale('fr', 'CM'),
      fallbackLocale: const Locale('fr', 'CM'),
      // French/English date and time pickers.
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr', 'CM'), Locale('en', 'CM')],
      getPages: CocoNavigation.pages,
      initialRoute: CocoRoutes.keyStartPage,
      theme: CocoTheme.lightTheme,
      darkTheme: CocoTheme.darkTheme,
    );
  }
}
