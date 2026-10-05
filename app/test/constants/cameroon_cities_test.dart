import 'package:coco_rider/constants/cameroon_cities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('city names compare without case or accents', () {
    expect(CameroonCities.fold(' Yaoundé '), 'yaounde');
    expect(CameroonCities.fold('NGAOUNDÉRÉ'), 'ngaoundere');
    expect(CameroonCities.fold('Edéa'), CameroonCities.fold('edea'));
  });
}
