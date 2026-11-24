import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HR dashboard bounds database request fan-out', () {
    final source = File('lib/erp/screens/erp_hr_executive_dashboard_screen.dart')
        .readAsStringSync();

    expect(source, contains('final requests = <Future<dynamic>>[];'));
    expect(source, contains('offset += 4'));
    expect(source, contains('requests.skip(offset).take(4)'));
    expect(source, isNot(contains('.limit(20000)')));
  });

  test('HR dashboard fetches payroll lines only for the latest payroll run', () {
    final source = File('lib/erp/screens/erp_hr_executive_dashboard_screen.dart')
        .readAsStringSync();

    expect(source, contains('final latestPayrollRunId ='));
    expect(source, contains(".eq('payroll_run_id', latestPayrollRunId)"));
    expect(source, contains('List<Map<String, dynamic>>.from(latestPayrollLines)'));
  });
}
