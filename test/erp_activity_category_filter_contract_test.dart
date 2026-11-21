import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String categoryScreen;

  setUpAll(() {
    categoryScreen = File('lib/erp/screens/erp_item_categories_screen.dart')
        .readAsStringSync();
  });

  test('activity category filtering canonicalizes legacy and current activity codes', () {
    expect(categoryScreen, contains("RegExp(r'^ACT0*(\\\\d{1,3})\\$')"));
    expect(categoryScreen, contains("RegExp(r'^\\\\d{1,3}\\$')"));
    expect(categoryScreen, contains("final rawCode = normalizeActivity(_s(row['activity_code']));"));
    expect(categoryScreen, contains('return rawCode == _selectedActivityCode;'));
    expect(categoryScreen, contains("const defaultActivity = '01';"));
  });

  test('selected activity is fetched independently and merged by stable category id', () {
    expect(categoryScreen, contains("final selectedCode = normalizeActivity(_selectedActivityCode);"));
    expect(categoryScreen, contains(".eq('company_id', company)"));
    expect(categoryScreen, contains(".eq('activity_code', selectedCode)"));
    expect(categoryScreen, contains("final completeCatalog = catalogById.values.toList(growable: false);"));
    expect(categoryScreen, contains("_all = completeCatalog.where((row)"));
  });

  test('category source rows retain names, status, visibility and hierarchy metadata', () {
    expect(categoryScreen, contains("Map<String, dynamic>.from(row)"));
    expect(categoryScreen, contains("'01': 'مواد غذائية'"));
    expect(categoryScreen, contains("_selectedActivityCode = displayCodes.contains(wanted)"));
  });
}
