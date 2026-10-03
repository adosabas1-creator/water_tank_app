import 'package:flutter_test/flutter_test.dart';
import 'package:water_tank_app/core/constants/app_constants.dart';

void main() {
  test('app constants are defined', () {
    expect(AppConstants.localDbName, isNotEmpty);
  });
}
