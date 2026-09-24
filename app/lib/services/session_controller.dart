import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/authentication/auth.dart';
import 'package:coco_rider/services/notifications/push_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Holds the signed-in user's profile and decides where the app starts.
class SessionController extends GetxController {
  final Auth auth;
  final CocoApi api;
  final PushNotifications? push;

  SessionController({required this.auth, required this.api, this.push});

  final Rx<Profile?> profile = Rx<Profile?>(null);

  /// Route to open at startup or right after sign-in.
  Future<String> resolveStartRoute() async {
    if (!await auth.restoreSession() && auth.userIsLogged.isFalse) {
      return CocoRoutes.keyAuthenticationPage;
    }
    final current = await api.getProfile();
    if (current == null) return CocoRoutes.keyProfileSetupPage;
    _apply(current);
    return CocoRoutes.keyHomePage;
  }

  Future<Profile?> refreshProfile() async {
    final current = await api.getProfile();
    if (current != null) _apply(current);
    return current;
  }

  void setProfile(Profile value) => _apply(value);

  Future<void> logout() async {
    // Unregister the phone while the session is still valid.
    await push?.stop();
    await auth.logout();
    profile.value = null;
    Get.offAllNamed(CocoRoutes.keyAuthenticationPage);
  }

  void _apply(Profile value) {
    profile.value = value;
    // Signed in with a profile: this phone can receive the account's notifications.
    push?.start();
    final locale = value.language == Language.english
        ? const Locale('en', 'CM')
        : const Locale('fr', 'CM');
    if (Get.locale != locale) Get.updateLocale(locale);
  }
}
