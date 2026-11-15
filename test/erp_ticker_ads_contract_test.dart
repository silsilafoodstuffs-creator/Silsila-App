import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String homeSource;
  late String adminSource;
  late String brandSource;
  late String migrationSource;
  late String activityMigrationSource;

  setUpAll(() {
    homeSource = File('lib/main.dart').readAsStringSync();
    adminSource = File('lib/erp/screens/erp_app_ticker_ads_tab.dart')
        .readAsStringSync();
    brandSource = File('lib/erp/screens/erp_brands_tab.dart').readAsStringSync();
    migrationSource = File(
      'supabase/migrations/20261114140500_ticker_ads_unlimited_active_brands.sql',
    ).readAsStringSync();
    activityMigrationSource = File(
      'supabase/migrations/20261114141137_brand_activity_scope_and_ticker_feed.sql',
    ).readAsStringSync();
  });

  test('home ticker renders circular brand logos with their names below and horizontal scrolling', () {
    final start = homeSource.indexOf('class _HomeTickerAdsStrip extends StatefulWidget');
    final end = homeSource.indexOf('class MainShell extends StatefulWidget', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final ticker = homeSource.substring(start, end);

    expect(ticker, contains('get_silsila_public_ticker_ads'));
    expect(ticker, contains("'p_activity_code': widget.activityCode"));
    expect(ticker, contains('scrollDirection: Axis.horizontal'));
    expect(ticker, contains('shape: BoxShape.circle'));
    expect(ticker, contains('Image.memory'));
    expect(ticker, contains("ad['brand_name']"));
    expect(ticker, isNot(contains("ad['brand_code']")));
  });

  test('admin ticker supports every active brand without a fixed 15 or 25 cap', () {
    expect(adminSource, contains('int get _slotCount'));
    expect(adminSource, contains('final brandRows = List<Map<String, dynamic>>.from(brandRowsResult)'));
    expect(adminSource, contains('return _brands.length > lastAssigned'));
    expect(adminSource, contains("brand_name_en']).toLowerCase().contains(term"));
    expect(adminSource, contains('columnSpacing: 2.5'));
    expect(adminSource, contains("Text('كود البراند')"));
    expect(adminSource, contains("Text('اسم البراند')"));
    expect(adminSource, contains('هل ترغب في الحفظ؟'));
    expect(adminSource, isNot(contains('slot <= 15')));
    expect(adminSource, isNot(contains('slot <= 25')));
  });

  test('public ticker automatically includes all active brands for the selected activity', () {
    expect(activityMigrationSource, contains('activity_brand_catalog'));
    expect(activityMigrationSource, contains('public.erp_item_categories'));
    expect(activityMigrationSource, contains('ADD COLUMN IF NOT EXISTS activity_code text'));
    expect(activityMigrationSource, contains('SET activity_code = COALESCE'));
    expect(activityMigrationSource, contains('REFERENCES public.activity_types(code)'));
    expect(brandSource, contains("'activity_code': activityCode"));
    expect(adminSource, contains("_s(brand['activity_code']) != _activityCode"));
    expect(activityMigrationSource, contains('public.erp_items i'));
    expect(activityMigrationSource, contains('WHERE NOT EXISTS'));
    expect(activityMigrationSource, contains('ORDER BY result.slot_no'));
  });

  test('database migration removes the fixed ticker slot ceiling', () {
    expect(migrationSource, contains('CHECK (slot_no >= 1)'));
    expect(migrationSource, contains('slot_no') );
    expect(migrationSource, contains('SECURITY INVOKER'));
    expect(migrationSource, contains('NOT EXISTS'));
    expect(migrationSource, contains('a.activity_code IS NULL'));
    expect(migrationSource, contains('GRANT EXECUTE ON FUNCTION public.get_silsila_public_ticker_ads(text) TO anon, authenticated'));
  });
}
