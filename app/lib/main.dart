import 'package:coco_rider/common/navigation/coco_navigation.dart';
import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/theme/coco_theme.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/authentication/auth.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:coco_rider/services/config/app_config.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  final auth = Get.put(Auth(AppConfig.usesCognito ? AuthType.cognito : AuthType.development));
  final api = Get.put(CocoApi(baseUrl: AppConfig.apiUrl, authHeaders: auth.authHeaders));
  Get.put(SessionController(auth: auth, api: api));

  runApp(const MyApp());
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
