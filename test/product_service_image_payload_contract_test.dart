import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ERP catalog metadata does not transfer category or item image bytes', () {
    final source = File('lib/services/product_service.dart').readAsStringSync();

    final categoryStart = source.indexOf('var categoryQuery');
    final categoryEnd = source.indexOf('final categoryRows', categoryStart);
    expect(categoryStart, greaterThanOrEqualTo(0));
    expect(categoryEnd, greaterThan(categoryStart));
    expect(source.substring(categoryStart, categoryEnd), isNot(contains('image_data')));

    final itemStart = source.indexOf('var itemQuery');
    final itemEnd = source.indexOf('final itemRows', itemStart);
    expect(itemStart, greaterThanOrEqualTo(0));
    expect(itemEnd, greaterThan(itemStart));
    expect(source.substring(itemStart, itemEnd), isNot(contains('image_data')));
  });

  test('ERP images are fetched only for visible rows and retain master IDs after merge', () {
    final source = File('lib/services/product_service.dart').readAsStringSync();

    expect(source, contains('await _attachErpMasterImages(merged)'));
    expect(source, contains("existing['_erp_master_item_id'] = master['_erp_master_item_id'];"));
    expect(source, contains('final masterIdsByRow = <Map<String, dynamic>, String>{};'));
    expect(source, contains("row.remove('_erp_master_item_id')"));
    expect(source, contains(".select('id,image_data,image_mime_type')"));
    expect(source, contains(".inFilter('id', ids)"));
    expect(source, contains('final masterId = masterIdsByRow[row];'));
    expect(source, contains('final image = imagesById[masterId];'));
    expect(source, isNot(contains("imagesById[row['id']?.toString()]")));
  });
}
