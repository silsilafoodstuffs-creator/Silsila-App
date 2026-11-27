import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity types and item categories open their own independent screens', () {
    final dashboard = File('lib/erp/erp_dashboard_screen.dart')
        .readAsStringSync();
    final categories = File('lib/erp/screens/erp_item_categories_screen.dart')
        .readAsStringSync();

    expect(
      dashboard,
      contains("_page == 'فئات الأصناف'\n                        ? ErpKeyboardNavigation(child: ErpItemCategoriesScreen"),
    );
    expect(
      dashboard,
      contains("_page == 'أنواع وفئات الأنشطة'\n                        ? ErpKeyboardNavigation(child: ErpActivityTypesScreen"),
    );
    expect(categories, contains('class ErpItemCategoriesScreen'));
    expect(categories, contains("title: 'فئات الأصناف'"));
    expect(categories, contains('category_code'));
    expect(categories, contains('parent_id'));
  });
}
