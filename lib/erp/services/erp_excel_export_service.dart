import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'package:file_saver/file_saver.dart';

/// Prevents spreadsheet formula injection while preserving real numeric values.
dynamic sanitizeErpExcelCellValue(dynamic value) {
  if (value == null) return '';
  if (value is! String) return value;
  final trimmed = value.trimLeft();
  if (trimmed.startsWith('=') ||
      trimmed.startsWith('+') ||
      trimmed.startsWith('-') ||
      trimmed.startsWith('@') ||
      trimmed.startsWith('\t') ||
      trimmed.startsWith('\r')) {
    return "'$value";
  }
  return value;
}

/// Builds a workbook from explicitly supplied screen rows and column contracts.
/// Keeping this pure allows the workbook content to be validated in unit tests.
Uint8List buildErpExcelBytes({
  required Map<String, List<Map<String, dynamic>>> sheets,
  required Map<String, Map<String, String>> columns,
}) {
  if (sheets.isEmpty) {
    throw ArgumentError('لا توجد بيانات محددة لتصديرها.');
  }
  final workbook = excel.Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet();
  var first = true;
  for (final entry in sheets.entries) {
    final fields = columns[entry.key] ?? const <String, String>{};
    if (fields.isEmpty) {
      throw ArgumentError('لا توجد أعمدة تصدير معرفة للورقة: ${entry.key}');
    }
    final safeName = entry.key.replaceAll(RegExp(r'[\\/*?:\\[\\]]'), '-');
    final sheetName = safeName.length > 31 ? safeName.substring(0, 31) : safeName;
    final sheet = first && defaultSheet != null
        ? workbook[defaultSheet]
        : workbook[sheetName];
    first = false;
    sheet.appendRow(fields.keys
        .map((label) => excel.TextCellValue(label))
        .toList());
    for (final row in entry.value) {
      sheet.appendRow(fields.values.map((key) {
        final value = sanitizeErpExcelCellValue(row[key]);
        if (value == null || value == '') return excel.TextCellValue('');
        if (value is num) return excel.DoubleCellValue(value.toDouble());
        if (value is bool) return excel.BoolCellValue(value);
        return excel.TextCellValue(value.toString());
      }).toList());
    }
  }
  final bytes = workbook.encode();
  if (bytes == null || bytes.isEmpty) {
    throw StateError('تعذر إنشاء ملف Excel من البيانات المحددة.');
  }
  return Uint8List.fromList(bytes);
}

/// Exports the exact records already loaded by a specialized ERP screen.
/// Column labels and source keys are supplied by that screen.
Future<void> exportErpExcel({
  required String fileName,
  required Map<String, List<Map<String, dynamic>>> sheets,
  required Map<String, Map<String, String>> columns,
}) async {
  final bytes = buildErpExcelBytes(sheets: sheets, columns: columns);
  await FileSaver.instance.saveFile(
    name: fileName,
    bytes: bytes,
    mimeType: MimeType.microsoftExcel,
    fileExtension: 'xlsx',
  );
}

/// Screen-scoped convenience export. Never exports credentials, secrets,
/// binary payloads, or implementation-only fields from raw database rows.
/// Import templates must still be declared by each screen's own importer.
Future<void> exportErpRawRowsExcel({
  required String fileName,
  required Map<String, List<Map<String, dynamic>>> sheets,
}) async {
  const excluded = <String>{
    'password', 'password_hash', 'access_token', 'refresh_token',
    'api_key', 'secret', 'client_secret', 'private_key',
    'authorization', 'auth_token', 'session_token',
  };
  final columns = <String, Map<String, String>>{};
  for (final entry in sheets.entries) {
    final keys = <String>[];
    for (final row in entry.value) {
      for (final key in row.keys) {
        final normalized = key.toLowerCase();
        final sensitive = excluded.contains(normalized) ||
            normalized.contains('password') ||
            normalized.contains('token') ||
            normalized.contains('secret') ||
            normalized.contains('private_key') ||
            normalized.endsWith('_bytes') ||
            normalized.endsWith('_binary');
        if (!sensitive && !keys.contains(key)) keys.add(key);
      }
    }
    if (keys.isEmpty) {
      throw ArgumentError('لا توجد حقول آمنة قابلة للتصدير في: ${entry.key}');
    }
    columns[entry.key] = {for (final key in keys) key: key};
  }
  await exportErpExcel(fileName: fileName, sheets: sheets, columns: columns);
}
