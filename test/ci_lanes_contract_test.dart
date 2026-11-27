import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unified HR routing and active global UI standards stay wired', () {
    final dashboard = File('lib/erp/erp_dashboard_screen.dart').readAsStringSync();
    final hr = File('lib/erp/screens/erp_hr_affairs_screen.dart').readAsStringSync();
    final hrRecords = File('lib/erp/screens/erp_hr_records_screen.dart').readAsStringSync();
    final app = File('lib/main.dart').readAsStringSync();

    final menuCatalog = File('lib/erp/services/erp_menu_catalog.dart').readAsStringSync();
    expect(dashboard, contains('ErpMenuCatalog.modules'));
    expect(menuCatalog, contains("'موارد بشرية': {"));
    expect(dashboard, isNot(contains("'شئون موظفين': {")));
    final permissionCatalog = File('lib/erp/screens/erp_permissions_screen.dart').readAsStringSync();
    final userAdmin = File('lib/erp/screens/erp_user_admin_screen.dart').readAsStringSync();
    expect(permissionCatalog, contains('ErpMenuCatalog.modules'));
    expect(permissionCatalog, isNot(contains("'شئون موظفين':{")));
    expect(userAdmin, contains('ErpMenuCatalog.modules'));
    expect(userAdmin, isNot(contains("'شئون موظفين':{")));
    expect(menuCatalog, contains("'الهيكل الوظيفي'"));
    expect(menuCatalog, contains("'سلف الموظفين'"));
    expect(menuCatalog, contains("'تقرير الحضور'"));
    expect(menuCatalog, contains("'تقرير الإجازات'"));
    expect(menuCatalog, contains("'تقرير التدريب'"));
    expect(menuCatalog, contains("'التأمينات والتراخيص'"));
    expect(menuCatalog, contains("'كشف الرواتب'"));
    expect(hr, contains("page == 'تقرير التدريب'"));
    expect(hr, contains("page == 'تقرير الحضور'"));
    expect(hr, contains("page == 'تقرير الإجازات'"));
    expect(hr, contains("page == 'كشف الرواتب'"));
    final shiftMaster = File('lib/erp/screens/erp_hr_shift_master_screen.dart').readAsStringSync();
    final shiftMigration = File('supabase/migrations/20261116040000_prevent_overlapping_hr_shift_assignments.sql').readAsStringSync();
    expect(hr, contains('ErpHrShiftMasterScreen(companyId: companyId)'));
    expect(shiftMaster, contains("from('erp_hr_shifts')"));
    expect(shiftMaster, contains("from('erp_hr_shift_assignments')"));
    expect(shiftMaster, contains("from('erp_employees')"));
    expect(shiftMaster, contains("'weekly_holidays'"));
    expect(shiftMigration, contains('daterange'));
    expect(shiftMigration, contains('erp_hr_shift_assignment_overlap_guard'));
    final shiftRlsMigration = File('supabase/migrations/20261116040500_hr_shift_master_rls_for_hr_manager.sql').readAsStringSync();
    expect(shiftRlsMigration, contains('erp_user_can_manage_hr_shift'));
    expect(shiftRlsMigration, contains("r.page_name = 'الورديات وجداول العمل'"));
    expect(shiftRlsMigration, contains('erp_scope_guard_erp_hr_shifts'));
    expect(shiftRlsMigration, contains('erp_scope_guard_erp_hr_shift_assignments'));
    expect(hr, contains("page == 'أجهزة البصمة وربط الحضور'"));
    expect(hr, contains('HrFingerprintDevicesScreen(companyId: companyId)'));
    expect(hr, contains("page == 'الوظائف الشاغرة'"));
    expect(hrRecords, isNot(contains("p.contains('الوظائف الشاغرة')")));

    expect(app, contains('headingRowHeight: 40'));
    expect(app, contains('dataRowMinHeight: 40'));
    expect(app, contains('dataRowMaxHeight: 40'));
    expect(app, contains('space: 5'));
  });

  test('one automatic validation lane deploys the exact successful build to permanent GitHub Pages', () {
    final web = File('.github/workflows/web-validation.yml').readAsStringSync();
    final full = File('.github/workflows/full-validation.yml').readAsStringSync();
    final releaseSetup = File('tools/prepare_android_release.sh').readAsStringSync();
    final maintenance = File('lib/erp/screens/erp_maintenance_center_screen.dart').readAsStringSync();

    expect(web, contains('name: Silsila Web App Validation'));
    expect(web, contains('flutter analyze lib test --no-fatal-infos --no-fatal-warnings'));
    expect(web, contains('flutter test --reporter expanded'));
    expect(web, contains('flutter build web --release'));
    expect(web, contains('actions/upload-artifact@v4'));
    expect(web, contains('silsila-web-build-'));
    expect(web, contains('deploy-github-pages:'));
    expect(web, contains('actions/deploy-pages@v4'));
    expect(web, contains('actions/upload-pages-artifact@v3'));
    expect(web, contains('silsilafoodstuffs-creator.github.io/Silsila-App/'));
    expect(web, contains('cancel-in-progress: false'));
    expect(web, contains('github.sha'));
    expect(web, isNot(contains('workflow_run:')));

    expect(full, contains('workflow_dispatch:'));
    expect(full, contains('flutter analyze lib test'));
    expect(full, contains('flutter test'));
    expect(full, contains('flutter build apk --release'));
    expect(full, contains('app-release.apk'));
    expect(full, contains('cancel-in-progress: false'));

    expect(releaseSetup, contains('dart run flutter_launcher_icons'));
    expect(releaseSetup, contains('ANDROID_KEYSTORE_BASE64'));
    expect(releaseSetup, contains('signingConfig = signingConfigs.getByName("release")'));
    expect(maintenance, contains('flutter build apk --release'));
    expect(maintenance, isNot(contains('flutter build apk --debug')));

    expect(File('.github/workflows/deploy.yml').existsSync(), isFalse);
    expect(File('.github/workflows/build.yml').existsSync(), isFalse);
    expect(File('.github/workflows/mobile-validation.yml').existsSync(), isFalse);
    expect(File('.github/workflows/ci-smoke.yml').existsSync(), isFalse);
    expect(File('.github/workflows/web-preview-validation.yml').existsSync(), isFalse);
  });

  test('unified HR permissions migration preserves the consolidated 78-page catalog', () {
    final migration = File('supabase/migrations/20261116034000_unify_hr_permission_template_menu.sql').readAsStringSync();
    final expansion = File('supabase/migrations/20261116034500_complete_hr_manager_template_78_pages.sql').readAsStringSync();
    final dashboard = File('lib/erp/erp_dashboard_screen.dart').readAsStringSync();
    final permissionCatalog = File('lib/erp/screens/erp_permissions_screen.dart').readAsStringSync();
    final userAdmin = File('lib/erp/screens/erp_user_admin_screen.dart').readAsStringSync();
    final menuCatalog = File('lib/erp/services/erp_menu_catalog.dart').readAsStringSync();
    expect(migration, contains("set menu_name='موارد بشرية'"));
    expect(migration, contains("where menu_name='شئون موظفين'"));
    expect(migration, contains("name_ar='مدير موارد بشرية'"));
    expect(migration, contains("'شريط قبض مجمع'"));
    expect(migration, contains("show_in_quick_tasks"));
    expect(migration, contains("on conflict (template_id,menu_name,submenu_name,page_name)"));
    expect(expansion, contains("'الهيكل الوظيفي'"));
    expect(expansion, contains("'تقرير التدريب'"));
    List<String> hrPages(String source, String nextMenu) {
      final start = source.indexOf("'موارد بشرية'");
      final end = source.indexOf(nextMenu, start);
      final block = source.substring(start, end);
      const headings = {'موارد بشرية', 'بيانات أساسية', 'حركات', 'تقارير'};
      return RegExp(r"'([^']+)'")
          .allMatches(block)
          .map((match) => match.group(1)!)
          .where((value) => !headings.contains(value))
          .toList();
    }
    expect(dashboard, contains('ErpMenuCatalog.modules'));
    expect(permissionCatalog, contains('ErpMenuCatalog.modules'));
    expect(userAdmin, contains('ErpMenuCatalog.modules'));
    final pages = hrPages(menuCatalog, "'علاقات عملاء'");
    expect(pages, hasLength(78));
  });

  test('food category activity filtering and three-level tree remain wired', () {
    final categories = File('lib/erp/screens/erp_item_categories_screen.dart').readAsStringSync();
    expect(categories, contains("const defaultActivity = '01';"));
    expect(categories, contains('if (company.isEmpty && activeCompanies.isNotEmpty)'));
    expect(categories, contains('if (rawRows.isEmpty && activeCompanies.isNotEmpty)'));
    expect(categories, contains('const catalogPageSize = 500;'));
    expect(categories, contains(".select(categoryColumns)"));
    expect(categories, contains("final rawCode = normalizeActivity(_s(row['activity_code']));"));
    expect(categories, contains("return rawCode == _selectedActivityCode;"));
    expect(categories, contains("Map<String,dynamic>? _parentOf"));
    expect(categories, contains("if (row['parent_id'] == null) return 0;"));
  });

  test('dashboard filters screens and actions while keeping system administrators unrestricted', () {
    final dashboard = File('lib/erp/erp_dashboard_screen.dart').readAsStringSync();
    expect(dashboard, contains('if (_isSystemAdmin) return true;'));
    expect(dashboard, contains("'مديرالنظام'"));
    expect(dashboard, contains("'superadmin'"));
    expect(dashboard, contains('.where((page) => _canOpenScreen(name, groupEntry.key, page))'));
    expect(dashboard, contains('bool _canPerformCurrentAction(String action)'));
    expect(dashboard, contains("_canPerformCurrentAction('إضافة')"));
    expect(dashboard, contains("_canPerformCurrentAction('حذف')"));
    expect(dashboard, contains('can_import_excel'));
    expect(dashboard, contains('can_export_excel'));
    expect(dashboard, contains('ErpQuickTaskPermissionScope'));
    expect(dashboard, contains("const executiveKey = 'إعدادات عامة::بيانات أساسية::الملخص التنفيذي';"));
    expect(dashboard, contains('if (_executiveSummaryAllowed)'));
    expect(dashboard, contains('void _ensureCurrentScreenAllowed()'));
    expect(dashboard, contains('body: !_executiveAccessChecked'));
    expect(dashboard, contains('_executiveSummaryAllowed = false;'));
  });

}
