import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog metadata does not transfer product image bytes', () {
    final source = File('lib/services/product_service.dart').readAsStringSync();

    final catalogColumnsStart = source.indexOf('_productCatalogColumns');
    final catalogColumnsEnd = source.indexOf('static const String _productColumns', catalogColumnsStart);
    expect(catalogColumnsStart, greaterThanOrEqualTo(0));
    expect(catalogColumnsEnd, greaterThan(catalogColumnsStart));
    expect(source.substring(catalogColumnsStart, catalogColumnsEnd), isNot(contains('image_data')));

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

  test('product images are fetched in small batches on demand, not during catalog load', () {
    final service = File('lib/services/product_service.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(service, contains('getProductImageRowsByIds'));
    expect(service, contains("select('id,image_data')"));
    expect(service, contains('offset += 100'));
    expect(service, contains("readImages('products', ids)"));
    expect(service, contains("readImages('erp_items', missing)"));
    expect(service, isNot(contains('_attachErpMasterImages')));
    expect(service, isNot(contains('await _attachErpMasterImages(merged)')));

    expect(main, contains('_loadProductImagesForProducts'));
    expect(main, contains('productService.getProductImageRowsByIds(ids)'));
    expect(main, contains('if (!brandExpanded)'));
    expect(main, contains('imageBytes: null'));
  });
}
