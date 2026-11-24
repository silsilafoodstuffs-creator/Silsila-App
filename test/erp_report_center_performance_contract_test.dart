import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report center uses smaller initial pages and keeps load-more pagination', () {
    final source = File('lib/erp/screens/erp_report_center_screen.dart')
        .readAsStringSync();

    expect(source, contains('static const int _pageSize = 100;'));
    expect(source, contains('query.range(0, _pageSize - 1)'));
    expect(source, contains('query.range(offset, offset + _pageSize - 1)'));
    expect(source, contains("'تحميل 100 سجل إضافي'"));
    expect(source, contains('onPressed: _loadingMore ? null : _loadMore'));
  });
}
