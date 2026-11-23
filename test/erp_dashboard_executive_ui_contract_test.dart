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
    expect(dashboard, contains('return value == null ? null : double.tryParse(value.toString());'));
  });

  test('executive summary adapts KPI and analysis grids to phone, tablet, and desktop widths', () {
    expect(dashboard, contains('final width = outerConstraints.maxWidth;'));
    expect(dashboard, contains('final wide = width >= 1120;'));
    expect(dashboard, contains('final tablet = width >= 720;'));
    expect(dashboard, contains('final columns = wide ? 3 : tablet ? 2 : 1;'));
    expect(dashboard, contains('crossAxisCount: columns'));
    expect(dashboard, contains('Widget periodPicker() => Wrap('));
    expect(dashboard, contains('if (constraints.maxWidth < 760) return Column('));
  });

  test('executive charts and analysis cards retain readable light-surface contrast', () {
    expect(dashboard, contains('colors: [Colors.white, Color(0xFFFCFAFF), Color(0xFFF5EFFB)]'));
    expect(dashboard, contains('color: const Color(0xFF241735)'));
    expect(dashboard, contains('color: const Color(0xFF766B80)'));
    expect(dashboard, contains('RepaintBoundary(child: CustomPaint(painter: chart'));
    expect(dashboard, contains('const Color(0xFF3E007D)'));
    expect(dashboard, contains('const Color(0xFFFFA015)'));
    expect(dashboard, contains('const Color(0xFFFF27C3)'));
  });
}
