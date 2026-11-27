import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report center uses smaller initial pages and keeps load-more pagination', () {
    final source = File('lib/erp/screens/erp_report_center_screen.dart')
        .readAsStringSync();

    expect(source, contains('static const int _pageSize = 50;'));
    expect(source, contains('query.range(0, _pageSize - 1)'));
    expect(source, contains('query.range(offset, offset + _pageSize - 1)'));
    expect(source, contains('rows: _pageRows.map((row) => DataRow('));
    expect(source, contains('رقم الصفحة'));
    expect(source, contains("'تحميل 50 سجلًا'"));
    expect(source, contains('onPressed: _loadingMore ? null : _loadMore'));
  });
}
