import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ERP catalog fetches image bytes only after the visible page is selected', () {
    final source = File('lib/services/product_service.dart').readAsStringSync();

    final categoryQueryStart = source.indexOf('var categoryQuery');
    final categoryQueryEnd = source.indexOf('final categoryRows', categoryQueryStart);
    expect(categoryQueryStart, greaterThanOrEqualTo(0));
    expect(categoryQueryEnd, greaterThan(categoryQueryStart));
    expect(
      source.substring(categoryQueryStart, categoryQueryEnd),
      isNot(contains('image_data')),
    );

    final itemQueryStart = source.indexOf('var itemQuery');
    final itemQueryEnd = source.indexOf('final itemRows', itemQueryStart);
    expect(itemQueryStart, greaterThanOrEqualTo(0));
    expect(itemQueryEnd, greaterThan(itemQueryStart));
    expect(
      source.substring(itemQueryStart, itemQueryEnd),
      isNot(contains('image_data')),
    );

    expect(source, contains('await _attachErpMasterImages(merged)'));
    expect(source, contains(".select('id,image_data,image_mime_type')"));
    expect(source, contains(".inFilter('id', ids)"));
    expect(source, contains("row.remove('_erp_master_item_id')"));
  });
}
