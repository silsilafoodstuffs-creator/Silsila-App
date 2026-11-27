import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;
  late String appCategoryService;
  late String appMainSource;

  setUpAll(() {
    screen = File('lib/erp/screens/erp_item_categories_screen.dart')
        .readAsStringSync();
    appCategoryService = File('lib/services/category_service.dart')
        .readAsStringSync();
    appMainSource = File('lib/main.dart').readAsStringSync();
  });

  test('category catalog excludes binary image payloads and reads in bounded pages', () {
    expect(screen, contains("const categoryColumns = 'id,company_id,activity_code,category_code,category_name,category_name_en,parent_id,is_active,show_in_app,image_url,image_mime_type,image_source_url,image_attribution,created_at';"));
    expect(screen, contains('const catalogPageSize = 500;'));
    expect(screen, contains('.range(offset, offset + catalogPageSize - 1)'));
    expect(screen, isNot(contains(".select('*')")));
    expect(screen, isNot(contains(".select('id,parent_id,category_code,category_name,category_name_en,activity_code,is_active,show_in_app,image_data")));
  });

  test('visible category page loads image bytes in a tenant-scoped batch', () {
    expect(screen, contains('Future<void> _loadCategoryImages(Iterable<Map<String, dynamic>> sourceRows) async'));
    expect(screen, contains(".select('id,image_data,image_mime_type,image_attribution,image_source_url')"));
    expect(screen, contains(".inFilter('id', batchIds)"));
    expect(screen, contains('_loadCategoryImages(pageRows);'));
  });

  test('hierarchy lookups use a stable ID index instead of scanning the full catalog per row', () {
    expect(screen, contains('final Map<String, Map<String, dynamic>> _categoriesById'));
    expect(screen, contains('void _rebuildCategoryIndexes()'));
    expect(screen, contains('_categoriesById[_s(row[\'parent_id\'])]'));
    expect(screen, isNot(contains('for (final candidate in _all) { if (_s(candidate[\'id\']) == parentId')));
    expect(screen, contains('_expandedIds.clear();'));
    expect(screen, isNot(contains('_expandedIds.addAll(_all.map')));
  });

  test('category coding inherits the two-digit activity code across all hierarchy levels', () {
    expect(screen, contains(r"""'category_code':'$parentDigits${next.toString().padLeft(2, '0')}'"""));
    expect(screen, contains("final parent = parentId == null ? null : _categoriesById[parentId];"));
    expect(screen, contains("_normalizeActivityCode(_s(parent['activity_code']))"));
    expect(screen, contains("_normalizeActivityCode(_s(r['activity_code'])) == draftActivityCode"));
    expect(screen, contains('digits.startsWith(parentDigits)'));
    expect(screen, contains('required String parentDigits'));
    expect(screen, contains("RegExp(r'^[0-9]{2}$').hasMatch(activityCode)"));
    expect(screen, contains("update({'category_code': ''})"));
  });

  test('app category service converts stored PostgreSQL bytea to image bytes', () {
    expect(appCategoryService, contains("'image_data': _decodePostgresBytea(row['image_data'])"));
    expect(appCategoryService, contains('Uint8List? _decodePostgresBytea(dynamic value)'));
    expect(appCategoryService, contains("return r'\\x' + hex;"));
    expect(appMainSource, contains('if (value is Uint8List) return value;'));
    expect(appMainSource, contains('if (value is List<int>) return Uint8List.fromList(value);'));
    expect(appMainSource, contains('liveCategoryImageMimes'));
    expect(appMainSource, contains("SvgPicture.memory(bytes, fit: BoxFit.contain, width: size, height: size)"));
  });

  test('category table renders a bounded page instead of every row at once', () {
    expect(screen, contains('static const int _categoryPageSize = 100;'));
    expect(screen, contains('final pageRows = visibleRows'));
    expect(screen, contains('rows: pageRows.asMap().entries.map'));
    expect(screen, contains('الصفحة التالية'));
    expect(screen, contains('الصفحة السابقة'));
    expect(screen, contains('final ScrollController _categoryVerticalScrollController = ScrollController();'));
    expect(screen, contains('thumbVisibility: true'));
    expect(screen, contains('scrollDirection: Axis.vertical'));
    expect(screen, contains('controller: _categoryVerticalScrollController'));
  });
}
