import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:get/get.dart';

class ResponsiveLayoutController extends GetxController {
  /// Constant that indicates the actual selected page on the navigationBar or
  /// navigationRail.
  final RxInt navigationBarSelectedIndex = 0.obs;

  /// Callback function that updates the [navigationBarSelectedIndex].
  void onNavigationBarDestinationChanged(int newDestination) {
    UtilityFunctions.debugPrint(
        'Navigation is been changed. NEW_VALUE: $newDestination',
        leadingIcons: '🔬🔬🔬');
    navigationBarSelectedIndex.value = newDestination;
  }
}
