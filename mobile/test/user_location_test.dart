import 'package:ankara_proje/core/location/user_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallback uses a neutral Turkey center instead of Ankara', () {
    expect(UserLocation.turkeyCenter.latitude, 39.0);
    expect(UserLocation.turkeyCenter.longitude, 35.0);
    expect(UserLocation.turkeyCenter.isFallback, isTrue);
  });
}
