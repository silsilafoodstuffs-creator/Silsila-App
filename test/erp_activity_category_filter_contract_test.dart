import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String categoryScreen;

  setUpAll(() {
    categoryScreen = File('lib/erp/screens/erp_item_categories_screen.dart')
        .readAsStringSync();
  });

  test('activity code normalization and food default remain present', () {
    expect(categoryScreen, contains('normalizeActivity'));
    expect(categoryScreen, contains('ACT0*'));
    expect(categoryScreen, contains("const defaultActivity = '01';"));
    expect(categoryScreen, contains("'01': 'مواد غذائية'"));
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
    expect(categoryScreen, contains("_selectedActivityCode = displayCodes.contains(wanted)"));
  });
}
