import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/services/location_service.dart';

void main() {
  test('Silsila operating governorates appear first in the requested order', () {
    expect(
      LocationService.getGovernorates().take(4).toList(),
      ['القاهرة', 'الجيزة', 'القليوبية', 'الشرقية'],
    );
  });
}
