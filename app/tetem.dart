import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class Controller extends GetxController {
  @override
  void onInit() {
    super.onInit();
    name.value = 'init name';
  }

  @override
  void onClose() {
    name.value = 'closed name';
    super.onClose();
  }

  final name = 'tetem'.obs;

  @override
  void dispose() {
    name.value = '';
  }

  void changeName({String? newName}) => name.value = newName ?? 'changed name';
}

void main() {
  test(
      'Testing the Get package to see if the Get.create and Get.find function '
      'creates new instances or just use the old one which has been created since.',
      () {
    Get.create(() => Controller());
    final Controller controller1 = Get.find();
    controller1.changeName(newName: '1st instance');
    expect(controller1.name.value, '1st instance');

    final Controller controller2 = Get.find();
    expect(controller2.name.value, 'init name');

    expect(controller1 == controller2, false);
  });

  test(
      'Testing the Get package to see if the Get.put and Get.find function '
      'creates new instances or just use the old one which has been created since.',
      () {
    // onInit was called
    // Get.put(Controller());

    final Controller controller1 = Get.find();
    expect(controller1.name.value, 'init name');

    /// Test your functions
    controller1.changeName(newName: 'changed 1stxxx');
    expect(controller1.name.value, 'changed 1stxxx');

    // On init no more called.
    final Controller controller2 = Get.find();

    expect(
      controller2.name.value,
      'changed 1stxxx',
      reason: 'Still contains the old value from controller1',
    );

    expect(controller1 == controller2, true);
    controller1.dispose();
    controller2.dispose();
  });
}
