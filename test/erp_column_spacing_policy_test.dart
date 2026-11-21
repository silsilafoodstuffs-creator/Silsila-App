import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final spacingFiles = <String>[
    'lib/core/app_theme.dart',
    'lib/erp/widgets/erp_screen_frame.dart',
    'lib/erp/erp_dashboard_screen.dart',
    'lib/erp/services/studio_renderer.dart',
    'lib/erp/screens/erp_brands_tab.dart',
    'lib/erp/screens/erp_app_ticker_ads_tab.dart',
    'lib/erp/screens/erp_item_data_import_download_screen.dart',
    'lib/erp/screens/erp_activity_branches_screen.dart',
    'lib/erp/screens/erp_user_admin_screen.dart',
    'lib/erp/screens/erp_user_admin_screen_backup.dart',
    'lib/erp/screens/erp_cost_centers_screen.dart',
    'lib/erp/screens/erp_activity_types_screen.dart',
    'lib/erp/screens/erp_company_members_screen.dart',
    'lib/erp/screens/hr_attendance_rules_screen.dart',
    'lib/erp/screens/erp_user_classifications_screen.dart',
    'lib/erp/screens/erp_inventory_master_screen.dart',
    'lib/erp/screens/erp_financial_operations_screen.dart',
    'lib/erp/screens/erp_operational_documents_screen.dart',
  ];

  test('every explicit ERP DataTable column spacing is exactly 2px', () {
    for (final path in spacingFiles) {
      final source = File(path).readAsStringSync();
      for (final match in RegExp(r'columnSpacing:\s*([^,\n]+)').allMatches(source)) {
        expect(match.group(1)!.trim(), '2', reason: '$path must not override the 2px global column gap');
      }
    }
  });

  test('all DataTable2 grids specify the same 2px column gap', () {
    for (final path in [
      'lib/erp/screens/erp_brands_tab.dart',
      'lib/erp/screens/erp_app_ticker_ads_tab.dart',
      'lib/erp/screens/erp_item_data_import_download_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final tableCount = RegExp(r'DataTable2\(').allMatches(source).length;
      final spacingCount = RegExp(r'columnSpacing:\s*2').allMatches(source).length;
      expect(spacingCount, greaterThanOrEqualTo(tableCount), reason: '$path must set spacing explicitly on every DataTable2');
    }
  });

  test('programming policy is fixed to 2px and persisted for every company', () {
    final policy = File('lib/erp/screens/erp_program_policies_screen.dart').readAsStringSync();
    final migration = File('supabase/migrations/20261121033000_enforce_two_pixel_erp_column_spacing.sql').readAsStringSync();

    expect(policy, contains('column_spacing":2'));
    expect(policy, contains("'column_spacing': 2"));
    expect(policy, contains("selector('المسافة بين الأعمدة', 'column_spacing', [2])"));
    expect(policy, contains("key == 'column_spacing' ? 2 : value"));
    expect(policy, contains("previousSpacing != 2"));
    expect(migration, contains("'{column_spacing}'"));
    expect(migration, contains("'2'::jsonb"));
  });

  test('brands tree rows and headers keep 2px between each adjacent column', () {
    final brands = File('lib/erp/screens/erp_brands_tab.dart').readAsStringSync();
    expect(brands, contains('const SizedBox(width: 2), status'));
    expect(brands, contains('const SizedBox(width: 2), appVisibility'));
    expect(brands, contains('const SizedBox(width: 2), displayOrder'));
    expect(brands, contains("Text('الترتيب', style: headingStyle)"));
    expect(brands, contains("Text('الشعار', style: headingStyle)"));
  });
}
