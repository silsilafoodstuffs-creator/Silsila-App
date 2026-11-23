import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String dashboard;

  setUpAll(() {
    dashboard = File('lib/erp/erp_dashboard_screen.dart').readAsStringSync();
  });

  test('executive summary checks permissions before requesting metrics', () {
    final permissionLoad = dashboard.indexOf('_loadExecutivePermissions(companyId)');
    final metricsGate = dashboard.indexOf('if (_executiveSummaryAllowed)', permissionLoad);
    final metricsLoad = dashboard.indexOf('await _loadExecutiveMetrics(companyId)', metricsGate);

    expect(permissionLoad, greaterThanOrEqualTo(0));
    expect(metricsGate, greaterThan(permissionLoad));
    expect(metricsLoad, greaterThan(metricsGate));
    expect(dashboard, contains("(_executiveAccessChecked && !_executiveSummaryAllowed)"));
  });

  test('executive figures use posted non-demo company records and preserve missing values', () {
    expect(dashboard, contains("'erp_get_executive_metrics'"));
    expect(dashboard, contains(".eq('company_id', companyId)"));
    expect(dashboard, contains(".eq('status', 'posted')"));
    expect(dashboard, contains(".eq('is_demo_data', false)"));
    expect(dashboard, contains("employee['is_demo_data'] != true"));
    expect(dashboard, contains('return value == null ? null : double.tryParse(value.toString());'));
  });

  test('section permissions gate KPI, financial breakdowns, staff and chart data', () {
    expect(dashboard, contains("if (canFinance)\n          _executiveKpiCard("));
    expect(dashboard, contains("if (canSales)\n          _executiveKpiCard("));
    expect(dashboard, contains("if (canInventory)\n          _executiveKpiCard("));
    expect(dashboard, contains("if (canFinance)\n          _executiveAnalysisCard("));
    expect(dashboard, contains("if (canSales)\n          _executiveAnalysisCard("));
    expect(dashboard, contains("if (canInventory)\n          _executiveAnalysisCard("));
    expect(dashboard, contains("_executiveStaffPerformance(showSales: canSales, showPurchases: canInventory)"));
    expect(dashboard, contains("loadSales: canSales"));
    expect(dashboard, contains("loadPurchases: canInventory"));
    expect(dashboard, contains("_canPerformActionLabel('تعديل')"));
  });

  test('monthly staff targets are not compared against annual actuals', () {
    expect(dashboard, contains("_executivePeriod.contains('الشهر')"));
    expect(dashboard, contains("اختر فترة شهرية لمقارنة الهدف"));
    expect(dashboard, contains("loadPurchases && useMonthlyTargets"));
  });

  test('executive summary adapts to phone, tablet, and desktop widths', () {
    expect(dashboard, contains('final width = outerConstraints.maxWidth;'));
    expect(dashboard, contains('final wide = width >= 1120;'));
    expect(dashboard, contains('final tablet = width >= 720;'));
    expect(dashboard, contains('final columns = wide ? 3 : tablet ? 2 : 1;'));
    expect(dashboard, contains('crossAxisCount: columns'));
    expect(dashboard, contains('Widget periodPicker() => Wrap('));
    expect(dashboard, contains('if (constraints.maxWidth < 760) return Column('));
    expect(dashboard, contains('Wrap(\n                spacing: 8,\n                runSpacing: 4,'));
  });

  test('RTL chart series and labels use the same visual order', () {
    expect(dashboard, contains('textDirection == TextDirection.rtl ? source.length - 1 - i : i'));
    expect(dashboard, contains('textDirection == TextDirection.rtl ? denominator - i : i'));
    expect(dashboard, contains('oldDelegate.textDirection != textDirection'));
    expect(dashboard, isNot(contains('_ExecutiveDonutPainter')));
  });

  test('executive cards use high-contrast light surfaces and retain Silsila identity', () {
    expect(dashboard, contains('color: Colors.white,'));
    expect(dashboard, contains('color: Color(0xFF241735)'));
    expect(dashboard, contains('color: Color(0xFF766B80)'));
    expect(dashboard, contains('RepaintBoundary(child: CustomPaint(painter: chart'));
    expect(dashboard, contains('const Color(0xFF3E007D)'));
    expect(dashboard, contains('const Color(0xFFFFA015)'));
    expect(dashboard, contains('const Color(0xFFFF27C3)'));
    expect(dashboard, contains("title: 'نتيجة النشاط التقديرية'"));
  });
}
