import 'dart:ui';

import 'package:coco_rider/common/widgets/responsive_layout_controller.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/constants/coco_constants.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:coco_rider/constants/internalization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// This is the app backbone layout for each screen. When a new screen is to be added
/// or to be created, this widget should be called and provided with the
/// required parameters.
class ResponsiveLayout extends StatelessWidget {
  /// The widget to be for screen sizes which are less than 700dp.
  /// Such screen would mainly include:
  /// -> Android smartphones.
  /// -> IOS smartphones.
  /// -> web pages on smartphones.
  final Widget smallScreenWidget;

  /// The widget to be for screen sizes which are greater than 700dp and less than 1000dp.
  /// Such screen would mainly include:
  /// -> Android tablets.
  /// -> IOS tablets.
  /// -> web pages on tablets.
  final Widget mediumScreenWidget;

  /// The widget to be for screen sizes which are greater than 1000dp.
  /// Such screen would mainly include:
  /// -> equally PC windows with such sizes.
  final Widget largeScreenWidget;

  /// The bottom bar navigation for small screens.
  final Widget? navigationBar;

  /// The side navigation bar for medium and large screens.
  final Widget? navigationRails;

  /// Appbars for small screens.
  final PreferredSizeWidget? smallScreenAppBar;

  /// Appbars for large screens.
  final PreferredSizeWidget? mediumAndLargerScreenAppBar;

  /// The variable that determines if the appbar should be shown in the screen.
  /// We might be confronted to situations when we don't want to show the app bar,
  /// like in the lodIn an logOut pages.
  final bool shouldShowAppbar;

  /// The variable that determines if the footer should be shown in the screen
  /// (only exclusive for web pages).
  /// We might be confronted to situations when we don't want to show the app bar,
  /// like in the logIn an logOut pages.
  final bool shouldShowFooter;

  /// The variable that determines if the navigation widget(bottom nav bar or
  /// navigation rails depending on the screen size) should be shown in the screen.
  /// We might be confronted to situations when we don't want to show the app bar,
  /// like in the logIn an logOut pages.
  final bool shouldShowNavbar;

  const ResponsiveLayout({
    super.key,
    required this.smallScreenWidget,
    required this.mediumScreenWidget,
    required this.largeScreenWidget,
    this.navigationBar,
    this.navigationRails,
    this.smallScreenAppBar,
    this.mediumAndLargerScreenAppBar,
    this.shouldShowAppbar = true,
    this.shouldShowFooter = false,
    this.shouldShowNavbar = true,
  });

  @override
  Widget build(BuildContext context) {
    final PreferredSizeWidget smallScreenAppBarWidget =
        smallScreenAppBar ?? defaultSmallScreenAppBar();

    final PreferredSizeWidget mediumAndLargeScreenAppBarWidget =
        mediumAndLargerScreenAppBar ?? defaultMediumAndLargeScreenAppBar();

    final navigationBarWidget =
        navigationBar ?? const DefaultBottomNavigationBar();
    final navigationRailsWidget = Row(children: [
      navigationBar ?? const DefaultAppNavigationRails(),
      const VerticalDivider(
        thickness: 1,
        width: 1,
      )
    ]);
    final screenSize = MediaQuery.of(context).size.width;

    final screenSkeleton = switch (screenSize) {
      <= CocoConstants.smallScreenWidth => _ScreenSkeleton(
          appBar: shouldShowAppbar ? smallScreenAppBarWidget : null,
          content: smallScreenWidget,
          shouldShowFooter: shouldShowFooter && kIsWeb,
        ),
      > CocoConstants.smallScreenWidth && < CocoConstants.mediumScreenWidth =>
        _ScreenSkeleton(
          appBar: shouldShowAppbar ? mediumAndLargeScreenAppBarWidget : null,
          content: mediumScreenWidget,
          navigationRails: shouldShowNavbar ? navigationRailsWidget : null,
          shouldShowFooter: shouldShowFooter && kIsWeb,
        ),
      _ => _ScreenSkeleton(
          content: largeScreenWidget,
          navigationRails: shouldShowNavbar ? navigationRailsWidget : null,
          shouldShowFooter: shouldShowFooter && kIsWeb,
        ),
    };

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: screenSkeleton.appBar,
      bottomNavigationBar:
          screenSize <= CocoConstants.smallScreenWidth && shouldShowNavbar
              ? navigationBarWidget
              : null,
      body: screenSkeleton,
    );
  }
}

class _ScreenSkeleton extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? navigationRails;
  final Widget content;
  final bool shouldShowFooter;

  const _ScreenSkeleton({
    required this.shouldShowFooter,
    required this.content,
    this.appBar,
    this.navigationRails,
  });

  @override
  Widget build(BuildContext context) {
    if (navigationRails == null) {
      /// Small screens.
      return ListView(
        children: [
          content,
          kIsWeb && shouldShowFooter
              ? const AppFooter()
              : const SizedBox.shrink(),
        ],
      );
    }

    /// Large screens.
    return Row(children: [
      navigationRails ?? const SizedBox.shrink(),
      Expanded(
        child: ListView(
          children: [
            content,
            kIsWeb && shouldShowFooter
                ? const AppFooter()
                : const SizedBox.shrink(),
          ],
        ),
      )
    ]);
  }
}

PreferredSizeWidget defaultSmallScreenAppBar() => AppBar(
      title: Center(
        child: Image.asset(
          Get.isDarkMode
              ? ImageKeys.keyLogoImageWithoutBGGreen
              : ImageKeys.keyLogoImageWithoutBGDark,
        ),
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaY: 10,
            sigmaX: 10,
          ),
          child: Container(
            color: CocoColors.keyTransparent,
          ),
        ),
      ),
    );

PreferredSizeWidget defaultMediumAndLargeScreenAppBar() => AppBar(
      title: Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          Get.isDarkMode
              ? ImageKeys.keyLogoImageWithoutBGGreen
              : ImageKeys.keyLogoImageWithoutBGDark,
        ),
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaY: 10,
            sigmaX: 10,
          ),
          child: Container(
            color: CocoColors.keyTransparent,
          ),
        ),
      ),
    );

class AppFooter extends StatelessWidget {
  const AppFooter({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      color: CocoColors.keyError,
      child: Text(
        InternalizationKeys.notYetImplementedText.tr,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
    );
  }
}

class DefaultAppNavigationRails extends StatelessWidget {
  const DefaultAppNavigationRails({super.key});

  @override
  Widget build(BuildContext context) {
    final ResponsiveLayoutController controller = Get.find();

    /// TODO: Remove navigation rail for small devices if rotated.
    return Obx(
      () => NavigationRail(
        selectedIndex: controller.navigationBarSelectedIndex.value,
        onDestinationSelected: (index) =>
            controller.onNavigationBarDestinationChanged(index),
        destinations: [
          NavigationRailDestination(
            icon: const Icon(Icons.manage_search),
            selectedIcon: const Icon(Icons.search),
            label: Text(InternalizationKeys.searchTitle.tr),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.car_crash),
            selectedIcon: const Icon(Icons.car_crash),
            label: Text(InternalizationKeys.postARideTitle.tr),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.history_toggle_off_outlined),
            selectedIcon: const Icon(Icons.history_sharp),
            label: Text(InternalizationKeys.yourRidesHistoryTitle.tr),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.message_outlined),
            selectedIcon: const Icon(Icons.message),
            label: Text(InternalizationKeys.profileTitle.tr),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.person_2_outlined),
            selectedIcon: const Icon(Icons.person_3_rounded),
            label: Text(InternalizationKeys.profileTitle.tr),
          ),
        ],
      ),
    );
  }
}

class DefaultBottomNavigationBar extends StatelessWidget {
  const DefaultBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ResponsiveLayoutController controller = Get.find();
    return Obx(
      // TODO: Create a theme for this[NavigationBar].
      () => NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        selectedIndex: controller.navigationBarSelectedIndex.value,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        indicatorColor: CocoColors.keyPrimary.withAlpha(150),
        onDestinationSelected: (index) =>
            controller.onNavigationBarDestinationChanged(index),
        elevation: 2,
        animationDuration: const Duration(milliseconds: 1000),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.manage_search),
            selectedIcon: const Icon(Icons.search),
            label: InternalizationKeys.searchTitle.tr,
          ),
          NavigationDestination(
            icon: const Icon(Icons.car_crash),
            selectedIcon: const Icon(Icons.car_crash),
            label: InternalizationKeys.postARideTitle.tr,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_toggle_off_outlined),
            selectedIcon: const Icon(Icons.history_sharp),
            label: InternalizationKeys.yourRidesHistoryTitle.tr,
          ),
          NavigationDestination(
            icon: const Icon(Icons.message_outlined),
            selectedIcon: const Icon(Icons.message),
            label: InternalizationKeys.profileTitle.tr,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_2_outlined),
            selectedIcon: const Icon(Icons.person_3_rounded),
            label: InternalizationKeys.profileTitle.tr,
          ),
        ],
      ),
    );
  }
}
