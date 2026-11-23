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
    expect(categoryScreen, contains('final wanted = normalizeActivity(_selectedActivityCode);'));
    expect(categoryScreen, contains("_selectedActivityCode = _selectedActivityCode == '*'"));
    expect(categoryScreen, contains('displayCodes.contains(wanted)'));
  });
  test('main, sub and secondary category tabs share the compact activity grid contract', () {
    expect(categoryScreen, contains("String _viewMode = 'grid';"));
    expect(categoryScreen, contains("MediaQuery.sizeOf(context).width * 0.25"));
    expect(categoryScreen, contains(r"DataColumn(label: Text('كود فئة $levelName'))"));
    expect(categoryScreen, contains("DataColumn(label: Text('اسم الفئة'))"));
    expect(categoryScreen, contains("DataColumn(label: Text('معاينة'))"));
    expect(categoryScreen, contains("DataColumn(label: Text('صورة الفئة'))"));
    expect(categoryScreen, contains("DataColumn(label: Text('نشط'))"));
    expect(categoryScreen, contains("DataColumn(label: Text('يظهر في التطبيق'))"));
    expect(categoryScreen, contains("DataColumn(label: Text('حذف'))"));
    expect(categoryScreen, contains('rowHeight: 40'));
    expect(categoryScreen, contains('showCheckboxColumn: false'));
    expect(categoryScreen, contains("DataColumn(label: Text('نوع النشاط'))"));
    expect(categoryScreen, contains("DataColumn(label: Text('فئة رئيسية'))"));
    expect(categoryScreen, contains("DataColumn(label: Text('فئة فرعية'))"));
    expect(categoryScreen, contains('_mainCategoryFilter'));
    expect(categoryScreen, contains('_subCategoryFilter'));
    expect(categoryScreen, contains('_isDescendantOf'));
  });

  test('category recoding follows policy segments and keeps stable UUID relationships', () {
    expect(categoryScreen, contains("eq('policy_key', 'code_generation_registry')"));
    expect(categoryScreen, contains("segments['main']"));
    expect(categoryScreen, contains("segments['sub']"));
    expect(categoryScreen, contains("segments['secondary']"));
    expect(categoryScreen, contains("update({'category_code': code})"));
    expect(categoryScreen, contains(".eq('id', _s(row['id']))"));
    expect(categoryScreen, contains("final roots = ordered(rows.where((row) => row['parent_id'] == null).toList());"));
    expect(categoryScreen, contains("subsByRoot[rootId] = subs;"));
  });

}
