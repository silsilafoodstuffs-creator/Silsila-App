import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/services/erp_print_support.dart';

void main() {
  group('ErpPrintSupport numeric direction', () {
    test('converts Arabic and Persian digits to isolated Latin sequences', () {
      expect(
        ErpPrintSupport.normalizeText('رقم ١٢٣ - ۴۵'),
        'رقم \u200E123\u200E - \u200E45\u200E',
      );
    });

    test('keeps ordinary Arabic text unchanged', () {
      expect(ErpPrintSupport.normalizeText('سلسلة'), 'سلسلة');
    });
  });
}
