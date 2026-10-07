import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:coco_rider/common/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Splash screen: restores the session and opens sign-in, profile setup or home.
class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final SessionController session = Get.find();
    String route;
    try {
      route = await session.resolveStartRoute();
    } catch (e) {
      UtilityFunctions.debugPrint('Start failed: $e', leadingIcons: '🚦');
      route = session.auth.userIsLogged.value
          ? CocoRoutes.keyHomePage
          : CocoRoutes.keyAuthenticationPage;
    }
    Get.offAllNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(height: 44),
            const SizedBox(height: 14),
            Text('brand.tagline'.tr, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
