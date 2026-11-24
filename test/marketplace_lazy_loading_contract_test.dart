import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();

  test('startup loads only the initially visible marketplace directory', () {
    final stateStart = source.indexOf('class _MainShellState');
    final initStart = source.indexOf('void initState()', stateStart);
    final initEnd = source.indexOf(
      'Future<void> _loadActivityCodeAndIntroAd()',
      initStart,
    );
    expect(stateStart, greaterThanOrEqualTo(0));
    expect(initStart, greaterThanOrEqualTo(0));
    expect(initEnd, greaterThan(initStart));

    final initState = source.substring(initStart, initEnd);
    expect(initState, contains('_ensureBrowseEntityLoaded(selectedEntity)'));
    expect(initState, isNot(contains('loadLiveSuppliers()')));
    expect(initState, isNot(contains('loadLiveCustomers()')));
    expect(initState, isNot(contains('loadLiveShippingCompanies()')));
  });

  test('each directory is loaded only when its tab is selected', () {
    final helperStart = source.indexOf('void _ensureBrowseEntityLoaded');
    final helperEnd = source.indexOf(
      'Future<void> _changeActivity',
      helperStart,
    );
    expect(helperStart, greaterThanOrEqualTo(0));
    expect(helperEnd, greaterThan(helperStart));

    final helper = source.substring(helperStart, helperEnd);
    expect(helper, contains("case 'فئات':"));
    expect(helper, contains("case 'موردين':"));
    expect(helper, contains("case 'عملاء':"));
    expect(helper, contains("case 'شركات شحن':"));
    expect(helper, contains('_suppliersLoaded'));
    expect(helper, contains('_customersLoaded'));
    expect(helper, contains('_shippingCompaniesLoaded'));
  });

  test('changing activity invalidates only the active directory cache', () {
    final changeStart = source.indexOf('Future<void> _changeActivity');
    final changeEnd = source.indexOf(
      'Future<void> loadUnreadNotifications',
      changeStart,
    );
    expect(changeStart, greaterThanOrEqualTo(0));
    expect(changeEnd, greaterThan(changeStart));

    final changeActivity = source.substring(changeStart, changeEnd);
    expect(changeActivity, contains('_ensureBrowseEntityLoaded(selectedEntity)'));
    expect(changeActivity, contains('_productsLoaded = false'));
    expect(changeActivity, contains('_suppliersLoaded = false'));
    expect(changeActivity, contains('_customersLoaded = false'));
    expect(changeActivity, contains('_shippingCompaniesLoaded = false'));
    expect(changeActivity, isNot(contains('loadLiveSuppliers();')));
    expect(changeActivity, isNot(contains('loadLiveCustomers();')));
    expect(changeActivity, isNot(contains('loadLiveShippingCompanies();')));
  });
}
