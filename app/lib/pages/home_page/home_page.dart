import 'package:coco_rider/common/widgets/responsive_layout.dart';
import 'package:coco_rider/common/widgets/responsive_layout_controller.dart';
import 'package:coco_rider/pages/chat/inbox_tab.dart';
import 'package:coco_rider/pages/profile/profile_tab.dart';
import 'package:coco_rider/pages/publish/publish_tab.dart';
import 'package:coco_rider/pages/rides/rides_tab.dart';
import 'package:coco_rider/pages/trips/search_tab.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The signed-in shell: the navigation bar (or rail on tablets) switches between tabs.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ResponsiveLayoutController());
    final content = Obx(() => switch (controller.navigationBarSelectedIndex.value) {
          1 => const PublishTab(),
          2 => const RidesTab(),
          3 => const InboxTab(),
          4 => const ProfileTab(),
          _ => const SearchTab(),
        });

    return ResponsiveLayout(
      smallScreenWidget: content,
      mediumScreenWidget: content,
      largeScreenWidget: content,
    );
  }
}
