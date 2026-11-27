import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;

  setUpAll(() {
    screen = File('lib/erp/screens/erp_item_categories_screen.dart')
        .readAsStringSync();
  });

  test('category catalog excludes binary image payloads and reads in bounded pages', () {
    expect(screen, contains("const categoryColumns = 'id,company_id,activity_code,category_code,category_name,category_name_en,parent_id,is_active,show_in_app,image_url,image_mime_type,image_source_url,image_attribution,created_at';"));
    expect(screen, contains('const catalogPageSize = 500;'));
    expect(screen, contains('.range(offset, offset + catalogPageSize - 1)'));
    expect(screen, isNot(contains(".select('*')")));
    expect(screen, isNot(contains(".select('id,parent_id,category_code,category_name,category_name_en,activity_code,is_active,show_in_app,image_data")));
  });

  test('category images are fetched individually only after selecting a category', () {
    expect(screen, contains('Future<void> _loadCategoryImage(Map<String, dynamic> row) async'));
    expect(screen, contains(".select('image_data,image_mime_type,image_attribution,image_source_url')"));
    expect(screen, contains('_loadCategoryImage(row);'));
    expect(screen, contains('final Set<String> _categoryImageLoads'));
  });

  test('hierarchy lookups use a stable ID index instead of scanning the full catalog per row', () {
    expect(screen, contains('final Map<String, Map<String, dynamic>> _categoriesById'));
    expect(screen, contains('void _rebuildCategoryIndexes()'));
    expect(screen, contains('_categoriesById[_s(row[\'parent_id\'])]'));
    expect(screen, isNot(contains('for (final candidate in _all) { if (_s(candidate[\'id\']) == parentId')));
    expect(screen, contains('_expandedIds.clear();'));
    expect(screen, isNot(contains('_expandedIds.addAll(_all.map')));
  });

  test('category coding uses the standard Cat prefix for all hierarchy levels', () {
    expect(screen, contains("'category_code':'Cat$parentDigits${next.toString().padLeft(2, '0')}'"));
    expect(screen, contains("await saveCode(entry.value[i], categoryPrefix + segment(i + 1));"));
    expect(screen, contains("_s(root['category_code']) + segment(i + 1)"));
    expect(screen, contains("_s(sub['category_code']) + segment(i + 1)"));
  });

  test('category table renders a bounded page instead of every row at once', () {
    expect(screen, contains('static const int _categoryPageSize = 100;'));
    expect(screen, contains('final pageRows = visibleRows'));
    expect(screen, contains('rows: pageRows.asMap().entries.map'));
    expect(screen, contains('الصفحة التالية'));
    expect(screen, contains('الصفحة السابقة'));
  });
}
