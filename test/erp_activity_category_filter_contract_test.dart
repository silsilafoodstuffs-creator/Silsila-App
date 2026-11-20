import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String categoryScreen;

  setUpAll(() {
    categoryScreen = File('lib/erp/screens/erp_item_categories_screen.dart')
        .readAsStringSync();
  });

  test('activity category filtering canonicalizes legacy and current activity codes', () {
    expect(categoryScreen, contains("RegExp(r'^ACT0*(\\d{1,3})$')"));
    expect(categoryScreen, contains("RegExp(r'^\\d{1,3}$')"));
    expect(categoryScreen, contains("final rawCode = normalizeActivity(_s(row['activity_code']));"));
    expect(categoryScreen, contains('return rawCode == _selectedActivityCode;'));
    expect(categoryScreen, contains("const defaultActivity = '01';"));
  });

  test('food categories remain attached to the canonical food activity', () {
    expect(categoryScreen, contains("'01': 'مواد غذائية'"));
    expect(categoryScreen, contains("_selectedActivityCode = displayCodes.contains(wanted)"));
    expect(categoryScreen, contains("'activity_code': normalizeActivity(_s(row['activity_code']))"));
  });
}
