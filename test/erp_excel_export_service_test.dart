import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/services/erp_excel_export_service.dart';

void main() {
  group('ERP Excel export contract', () {
    test('builds a workbook from screen-specific columns', () {
      final bytes = buildErpExcelBytes(
        sheets: {
          'العملاء': [
            {'id': 'c-1', 'name': 'عميل تجريبي', 'balance': 125.5},
          ],
        },
        columns: {
          'العملاء': {'المعرف': 'id', 'اسم العميل': 'name', 'الرصيد': 'balance'},
        },
      );
      expect(bytes, isNotEmpty);
    });

    test('neutralizes spreadsheet formulas in text cells', () {
      expect(sanitizeErpExcelCellValue('=1+1'), "'=1+1");
      expect(sanitizeErpExcelCellValue('  @SUM(A1:A2)'), "'  @SUM(A1:A2)");
      expect(sanitizeErpExcelCellValue('-12'), "'-12");
    });

    test('preserves numeric values and rejects missing column contracts', () {
      expect(sanitizeErpExcelCellValue(-12), -12);
      expect(
        () => buildErpExcelBytes(
          sheets: {'بيانات': [{'name': 'x'}]},
          columns: const {},
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty exports instead of generating misleading files', () {
      expect(
        () => buildErpExcelBytes(sheets: const {}, columns: const {}),
        throwsArgumentError,
      );
    });
  });
}
