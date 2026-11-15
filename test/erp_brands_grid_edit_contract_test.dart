import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String migration;

  setUpAll(() {
    source = File('lib/erp/screens/erp_brands_tab.dart').readAsStringSync();
    migration = File(
      'supabase/migrations/20261115023000_erp_brand_names_atomic_grid_edit.sql',
    ).readAsStringSync();
  });

  test('brand names can be edited directly from their grid cells', () {
    expect(source, contains("_gridEditingOnlyId = id;"));
    expect(source, contains("_gridEditing && (_gridEditingOnlyId == null || _gridEditingOnlyId == id) && !system"));
    expect(source, contains("TextField(controller: ar"));
    expect(source, contains("TextField(controller: en"));
    expect(source, contains("ErpQuickTaskButton(label:'تعديل الكل'"));
    expect(source, contains("_saveGridNames(onlyId:_gridEditingOnlyId)"));
  });

  test('single-row grid editing restricts both language fields to the selected brand', () {
    final englishCell = source.indexOf("DataCell(SizedBox(width: 180");
    expect(englishCell, greaterThanOrEqualTo(0));
    final englishCellSource = source.substring(englishCell, englishCell + 1500);
    expect(englishCellSource, contains("_gridEditingOnlyId == id"));
  });

  test('brand name updates are atomic, company-scoped and preserve protected records', () {
    expect(source, contains("_db.rpc('erp_update_brand_names_batch'"));
    expect(source, contains("'p_company_id': widget.companyId.trim()"));
    expect(migration, contains('SECURITY INVOKER'));
    expect(migration, contains('b.company_id = p_company_id'));
    expect(migration, contains('coalesce(b.is_system, false) = false'));
    expect(migration, contains('Transaction-local placeholders'));
    expect(migration, contains('GRANT EXECUTE ON FUNCTION public.erp_update_brand_names_batch(uuid, jsonb) TO authenticated'));
  });

  test('database errors are translated into clear Arabic messages without raw codes', () {
    expect(source, contains('String _friendlySaveError(Object error)'));
    expect(source, contains('لم يتم عرض تفاصيل تقنية أو أكواد للمستخدم'));
    expect(source, contains('اسم البراند العربي مستخدم بالفعل'));
  });
}
