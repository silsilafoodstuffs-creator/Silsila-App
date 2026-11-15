import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String homeSource;
  late String adminSource;
  late String brandSource;
  late String migrationSource;
  late String activityMigrationSource;
  late String adsScreenSource;

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
    adsScreenSource = File('lib/erp/screens/erp_app_advertisements_screen.dart')
        .readAsStringSync();
  });


  test('public app displays activity-scoped popup ads after the startup intro', () {
    expect(homeSource, contains("get_silsila_public_intro_ad"));
    expect(homeSource, contains("get_silsila_public_popup_ads"));
    expect(homeSource, contains('_showPopupAdvertisement'));
    expect(homeSource, contains('_closePopupAdvertisement'));
    expect(homeSource, contains('_handleAdDestination'));
    expect(homeSource, contains('Timer(Duration(seconds: duration)'));
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
    expect(ticker, contains('fit: BoxFit.cover'));
    expect(ticker, contains("ad['brand_name']"));
    expect(ticker, contains('widget.onBrandTap'));
    expect(ticker, contains('_manualScrollPaused'));
    expect(ticker, contains('ScrollStartNotification'));
    expect(homeSource, contains("(p.brand ?? '').toLowerCase().contains(q)"));
    expect(ticker, isNot(contains("ad['brand_code']")));
  });


  test('ticker preview supports per-logo circular pan and zoom plus manual scroll controls', () {
    expect(adminSource, contains('class _TickerAdsPreview extends StatefulWidget'));
    expect(adminSource, contains('class _TickerBrandCircle extends StatelessWidget'));
    expect(adminSource, contains('InteractiveViewer('));
    expect(adminSource, contains('panAxis: PanAxis.free'));
    expect(adminSource, contains('minScale: 0.5'));
    expect(adminSource, contains('maxScale: 4'));
    expect(adminSource, contains('BoxFit.cover'));
    expect(adminSource, contains('Switch.adaptive('));
    expect(adminSource, contains('Slider('));
    expect(adminSource, contains('notification.direction != ScrollDirection.idle'));
    expect(adminSource, contains('_autoScroll = false'));
    expect(adminSource, contains('_speed'));
  });

  test('poster ads use compact responsive rows and branded WhatsApp placeholder', () {
    expect(adsScreenSource, contains('Widget _buildAdCard(String slot)'));
    expect(adsScreenSource, contains('if (snap.hasError)'));
    expect(adsScreenSource, contains('constraints.maxWidth < 560'));
    expect(adsScreenSource, contains('assets/images/silsila_logo.png'));
    expect(adsScreenSource, contains('ضع إعلانك هنا'));
    expect(adsScreenSource, contains('01019617100'));
    expect(adsScreenSource, contains('https://wa.me/201019617100'));
    expect(adsScreenSource, contains('_adSlots.map(_buildAdCard)'));
    expect(adsScreenSource, contains('إعلانات بوسترات التمرير'));
  });

  test('admin ticker orders all active brands by numeric brand code in one order column', () {
    expect(adminSource, contains('int get _slotCount => _brands.length'));
    expect(adminSource, contains('final brandRows = List<Map<String, dynamic>>.from(brandRowsResult)'));
    expect(adminSource, contains('_brandOrderDigits'));
    expect(adminSource, contains('_brandOrderValue'));
    expect(adminSource, contains('return numeric != 0 ? numeric'));
    expect(adminSource, contains("Text('كود البراند')"));
    expect(adminSource, contains("Text('ترتيبه في العرض')"));
    expect(adminSource, contains('معاينة دائرية'));
    expect(adminSource, isNot(contains('Checkbox(')));
    expect(adminSource, isNot(contains('take(25)')));
    expect(adminSource, contains('هل ترغب في الحفظ؟'));
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

  test('database migration removes the fixed ticker slot ceiling without downgrading the public feed', () {
    expect(migrationSource, contains('CHECK (slot_no > 0)'));
    expect(migrationSource, contains('slot_no'));
    expect(activityMigrationSource, contains('SECURITY INVOKER'));
    expect(activityMigrationSource, contains('NOT EXISTS'));
    expect(activityMigrationSource, contains('a.activity_code IS NULL'));
    expect(activityMigrationSource, contains('GRANT EXECUTE ON FUNCTION public.get_silsila_public_ticker_ads(text) TO anon, authenticated'));
  });
}
