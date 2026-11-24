import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('geographic hierarchy pages are fetched concurrently and cached briefly', () {
    final repository = File('lib/erp/services/erp_geographic_data_repository.dart')
        .readAsStringSync();

    expect(repository, contains('Duration(minutes: 3)'));
    expect(repository, contains('static const int _pageSize = 1000'));
    expect(repository, contains('static const int _parallelPages = 4'));
    expect(repository, contains('Future.wait<List<dynamic>>'));
    expect(repository, contains("from('erp_geographic_data')"));
    expect(repository, contains("const fields = 'id,parent_id,geo_code,name_ar,name_en,level,is_active'"));
    expect(repository, isNot(contains('latitude,longitude')));
    expect(repository, contains("eq('is_active', true)"));
    expect(repository, contains('static void invalidate(String companyId)'));
  });

  test('party, employee, inventory, and branch screens share geographic data', () {
    for (final path in [
      'lib/erp/screens/erp_parties_screen.dart',
      'lib/erp/screens/erp_employee_master_screen.dart',
      'lib/erp/screens/erp_inventory_master_screen.dart',
      'lib/erp/screens/erp_company_branches_design_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ErpGeographicDataRepository.fetchActive'));
    }
  });

  test('geographic master changes invalidate shared cached rows', () {
    final source = File('lib/erp/screens/erp_geographic_data_screen.dart')
        .readAsStringSync();

    expect(source, contains('ErpGeographicDataRepository.invalidate(writeCompanyId)'));
    expect(source, contains('ErpGeographicDataRepository.invalidate(companyId)'));
  });
}
