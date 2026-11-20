import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String homeSource;
  late String adminSource;
  late String brandSource;
  late String migrationSource;
  late String activityMigrationSource;
  late String brandVisibilityMigrationSource;
  late String tickerOrderMigrationSource;
  late String adsScreenSource;
  late String categoryServiceSource;
  late String itemCodePolicyMigrationSource;

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
    brandVisibilityMigrationSource = File(
      'supabase/migrations/20261120083304_brand_master_app_visibility_and_ticker_order.sql',
    ).readAsStringSync();
    tickerOrderMigrationSource = File(
      'supabase/migrations/20261120084349_preserve_existing_ticker_brand_order.sql',
    ).readAsStringSync();
    adsScreenSource = File('lib/erp/screens/erp_app_advertisements_screen.dart')
        .readAsStringSync();
    categoryServiceSource = File('lib/services/category_service.dart').readAsStringSync();
    itemCodePolicyMigrationSource = File(
      'supabase/migrations/20261120110000_align_item_codes_with_activity_category_policy.sql',
    ).readAsStringSync();
  });


  test('public category loading resolves and filters the selected activity code', () {
    expect(homeSource, contains('final selectedActivity = await ActivityService().findActivity(activity)'));
    expect(homeSource, contains('activityCode: activityCode'));
    expect(categoryServiceSource, contains('Never query the entire cross-activity catalogue'));
    expect(categoryServiceSource, contains("eq('activity_code', resolvedActivityCode)"));
  });

  test('ticker brand artwork is explicitly circular and consistently cover-cropped', () {
    final start = homeSource.indexOf('class _HomeTickerAdsStrip extends StatefulWidget');
    final end = homeSource.indexOf('class MainShell extends StatefulWidget', start);
    final ticker = homeSource.substring(start, end);
    expect(ticker, contains('ClipOval('));
    expect(ticker, contains('width: 46'));
    expect(ticker, contains('height: 46'));
    expect(ticker, contains('fit: BoxFit.cover'));
    expect(homeSource, contains('Image.memory(bytes, fit: BoxFit.cover'));
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
    expect(adminSource, contains('minScale: 1'));
    expect(adminSource, contains('maxScale: 5'));
    expect(adminSource, contains('constrained: false'));
    expect(adminSource, contains('class _TickerNumberCircle'));
    expect(adminSource, contains('_TickerNumberCircle(number: rowIndex, size: 58)'));
    expect(adminSource, contains('_TickerBrandCircle(bytes: bytes, size: 58)'));
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
    expect(adsScreenSource, contains('isScrollable: true'));
    expect(adsScreenSource, isNot(contains('tabAlignment: TabAlignment.fill')));
  });

  test('ticker preview follows brand master visibility and display order', () {
    expect(adminSource, contains("select('id,brand_code,brand_name,brand_name_en,logo_data,logo_mime_type,is_active,show_in_app,activity_code,display_order')"));
    expect(adminSource, contains(".eq('show_in_app', true)"));
    expect(adminSource, contains(".order('display_order')"));
    expect(adminSource, contains("Text('كود البراند')"));
    expect(adminSource, contains('معاينة دائرية'));
    expect(adminSource, isNot(contains('ترتيبه في العرض')));
    expect(adminSource, isNot(contains('erp_save_app_ticker_ads')));
    expect(adminSource, isNot(contains('_slotOwners')));
    expect(adminSource, isNot(contains('Checkbox(')));
    expect(adminSource, isNot(contains('take(25)')));
  });

  test('ticker brand grid remains a compact preview table without a second order editor', () {
    expect(adminSource, contains("import 'package:data_table_2/data_table_2.dart';"));
    expect(adminSource, contains('DataTable2('));
    expect(adminSource, contains('minWidth: 470'));
    expect(adminSource, contains('fixedTopRows: 1'));
    expect(adminSource, contains("rows: brands.asMap().entries.map((entry)"));
    expect(adminSource, contains("Text('معاينة دائرية')"));
    expect(adminSource, isNot(contains("Text('ترتيبه في العرض')")));
    expect(adminSource, contains('لا توجد براندات نشطة لعرضها في هذا النطاق.'));
  });

  test('brand master stores app visibility and is the authoritative ticker order', () {
    expect(brandVisibilityMigrationSource, contains('ADD COLUMN IF NOT EXISTS show_in_app boolean NOT NULL DEFAULT true'));
    expect(brandVisibilityMigrationSource, contains('AND b.show_in_app = true'));
    expect(brandVisibilityMigrationSource, contains('ORDER BY display_order NULLS LAST, brand_code, id'));
    expect(tickerOrderMigrationSource, contains('SET display_order = ticker.slot_no'));
    expect(tickerOrderMigrationSource, contains('public.erp_app_ticker_ads'));
    expect(tickerOrderMigrationSource, contains("app.app_key = 'silsila'"));
    expect(brandSource, contains("'show_in_app'"));
    expect(brandSource, contains('Future<void> _assignActivity'));
    expect(brandSource, contains('Future<void> _toggleBrandVisibility'));
    expect(brandSource, contains('Future<void> _saveDisplayOrder'));
    expect(brandSource, contains('DropdownButton<String?>'));
    expect(brandSource, contains('DropdownButtonFormField<String?>'));
    expect(brandSource, contains('_logoPreview(row, size: 44)'));
    expect(brandSource, contains('_logoPreview(current, size: 50)'));
    expect(brandSource, contains('Future<void> _showLogoDialog'));
    // The default view is the tree, so verify its live row/header layout too.
    expect(brandSource, contains("String _viewMode = 'tree'"));
    expect(brandSource, contains("SizedBox(width: 220, child: _brandGridField(name))"));
    expect(brandSource, contains("SizedBox(width: 220, child: Text('اسم البراند/الماركة'"));
    expect(brandSource, contains("SizedBox(width: 145, child: _brandGridField(DropdownButton<String>("));
    expect(brandSource, contains("SizedBox(width: 165, child: _brandGridField(DropdownButton<String?>("));
    expect(brandSource, contains("const Expanded(child: SizedBox.shrink())"));

    expect(brandSource, contains('ImageSource.camera'));
    expect(brandSource, contains("Text('اسم البراند/الماركة')"));
    expect(brandSource, contains('columnSpacing: 2'));
    expect(brandSource, contains('fixedWidth: 110'));
    expect(brandSource, contains("_showLogoDialog(row)"));
    expect(brandSource, contains('value: row[\'show_in_app\'] == true, activeColor: _brandPurple'));
    expect(brandSource, isNot(contains('تعديل صورة البراند')));
    expect(brandSource, isNot(contains('حذف صورة البراند')));
    expect(brandSource, contains('dataRowHeight: compactMobile ? 40 : 60'));
    expect(brandSource, contains('dataRowHeight: compactMobile ? 40 : 54'));
    expect(brandSource, contains('itemHeight: 48'));
    expect(brandSource, contains('materialTapTargetSize: compactMobile ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded'));
    expect(brandSource, contains('maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis'));
    expect(itemCodePolicyMigrationSource, contains('2+v_main_digits+v_sub_digits+v_secondary_digits'));
    expect(itemCodePolicyMigrationSource, contains("'{category_digits}', '8'::jsonb"));
    expect(brandSource, contains('shape: BoxShape.circle'));
    expect(brandSource, contains('SizedBox(width: 220, child: _brandGridField(name))'));
    expect(brandSource, contains('Expanded(flex: 2, child: Text(group =='));
  });

  test('public ticker automatically includes all active brands for the selected activity', () {
    expect(activityMigrationSource, contains('activity_brand_catalog'));
    expect(activityMigrationSource, contains('public.erp_item_categories'));
    expect(activityMigrationSource, contains('ADD COLUMN IF NOT EXISTS activity_code text'));
    expect(activityMigrationSource, contains('SET activity_code = COALESCE'));
    expect(activityMigrationSource, contains('REFERENCES public.activity_types(code)'));
    expect(brandSource, contains("'activity_code': activityCode"));
    expect(adminSource, contains("brandRows = brandRows.where((brand) => _s(brand['activity_code']) == _activityCode).toList();"));
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
