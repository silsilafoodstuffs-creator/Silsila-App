import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'package:file_saver/file_saver.dart';

/// Exports the exact records already loaded by a specialized ERP screen.
/// Column labels and source keys are supplied by that screen, so no generic
/// dashboard rows or cross-entity mappings are introduced.
Future<void> exportErpExcel({
  required String fileName,
  required Map<String, List<Map<String, dynamic>>> sheets,
  required Map<String, Map<String, String>> columns,
}) async {
  final workbook = excel.Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet();
  var first = true;
  for (final entry in sheets.entries) {
    final sheet = first && defaultSheet != null
        ? workbook[defaultSheet]
        : workbook[entry.key];
    first = false;
    final fields = columns[entry.key] ?? const <String, String>{};
    sheet.appendRow(fields.keys.map((label) => excel.TextCellValue(label)).toList());
    for (final row in entry.value) {
      sheet.appendRow(fields.values.map((key) {
        final value = row[key];
        return value == null
            ? excel.TextCellValue('')
            : excel.TextCellValue(value.toString());
      }).toList());
    }
  }
  final bytes = workbook.encode();
  if (bytes == null || bytes.isEmpty) {
    throw StateError('تعذر إنشاء ملف Excel من البيانات المحددة.');
  }
  await FileSaver.instance.saveFile(
    name: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: MimeType.microsoftExcel,
    fileExtension: 'xlsx',
  );
}

/// Screen-scoped raw export: keeps each sheet tied to the exact records loaded by that screen.
Future<void> exportErpRawRowsExcel({required String fileName, required Map<String, List<Map<String, dynamic>>> sheets}) async {
  final columns = <String, Map<String, String>>{};
  for (final entry in sheets.entries) {
    final keys = <String>[];
    for (final row in entry.value) {
      for (final key in row.keys) { if (!keys.contains(key)) keys.add(key); }
    }
    columns[entry.key] = {for (final key in keys) key: key};
  }
  await exportErpExcel(fileName: fileName, sheets: sheets, columns: columns);
}
