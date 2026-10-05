import 'dart:async';

import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/pages/publish/publish_tab.dart';
import 'package:coco_rider/pages/rides/rides_tab.dart';
import 'package:coco_rider/pages/trips/search_tab.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Selected tab and the unread message count shown in the header.
class HomeController extends GetxController {
  final CocoApi api;

  HomeController(this.api);

  static const home = 0;
  static const cocoRide = 1;
  static const history = 2;

  final tab = home.obs;

  /// History shows the driver's trips instead of the passenger's bookings.
  final historyAsDriver = false.obs;
  final unread = 0.obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    refreshUnread();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => refreshUnread());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> refreshUnread() async {
    try {
      final conversations = await api.getConversations();
      unread.value = conversations.fold(0, (sum, c) => sum + c.unread);
    } catch (_) {
      // The badge is a hint; a failed refresh keeps the last value.
    }
  }

  Future<void> openInbox() async {
    await Get.toNamed(CocoRoutes.keyInboxPage);
    refreshUnread();
  }
}

/// The signed-in shell: header with the user's card, then Home / Coco Ride / History.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController(Get.find()));
    final wide = MediaQuery.sizeOf(context).width >= 700;

    final destinations = [
      (Icons.home_outlined, Icons.home_rounded, 'nav.home'.tr),
      (Icons.explore_outlined, Icons.explore, 'nav.cocoRide'.tr),
      (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'nav.history'.tr),
    ];

    final body = Obx(() => switch (controller.tab.value) {
          HomeController.cocoRide => const PublishTab(),
          HomeController.history => const RidesTab(),
          _ => const SearchTab(),
        });

    // Light status bar icons over the dark header.
    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: CocoColors.keyBlack, // Pure black, like the Figma header and its photo.
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 14), child: _HeaderCard()),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );

    if (wide) {
      return Scaffold(
        body: Row(children: [
          Obx(() => NavigationRail(
                selectedIndex: controller.tab.value,
                onDestinationSelected: (i) => controller.tab.value = i,
                destinations: [
                  for (final d in destinations) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                ],
              )),
          Expanded(child: page),
        ]),
      );
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
        child: Obx(() => NavigationBar(
              selectedIndex: controller.tab.value,
              onDestinationSelected: (i) => controller.tab.value = i,
              destinations: [
                for (final d in destinations) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
              ],
            )),
      ),
    );
  }
}

/// White rounded card: avatar and name (opens the profile), then the messages button.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find();
    final HomeController home = Get.find();
    final theme = Theme.of(context);

    return ContentWidth(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          child: Obx(() {
            final profile = session.profile.value;
            final name = profile == null ? '' : '${profile.firstName} ${profile.lastName}';
            final verified = profile?.passenger.isVerified ?? false;
            return Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => Get.toNamed(CocoRoutes.keyProfilePage),
                    child: Semantics(
                      button: true,
                      label: 'profile.open'.tr,
                      child: Row(
                        children: [
                          CocoAvatar(name: name, radius: 23, verified: verified),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
                                Text(
                                  verified ? 'profile.verifiedMember'.tr : 'profile.completeVerification'.tr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: verified ? CocoColors.keySuccess : CocoColors.keyWarning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Obx(() => Badge(
                      isLabelVisible: home.unread.value > 0,
                      label: Text('${home.unread.value}'),
                      child: RoundAction(
                        icon: Icons.chat_bubble_rounded,
                        color: CocoColors.keyWarning,
                        tooltip: 'inbox.title'.tr,
                        onPressed: home.openInbox,
                      ),
                    )),
              ],
            );
          }),
        ),
      ),
    );
  }
}
