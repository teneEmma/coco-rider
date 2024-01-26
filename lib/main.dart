import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/navigation/coco_navigation.dart';
import 'package:coco_rider/pages/authentication/phone_authentication.dart';
import 'package:coco_rider/services/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GetMaterialApp(
        translations: CocoInternalization(),
        locale: Get.deviceLocale,
        fallbackLocale: const Locale('en', 'UK'),
        getPages: CocoNavigation.pages,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const PhoneAuthentication(),
      ),
    );
  }
}
