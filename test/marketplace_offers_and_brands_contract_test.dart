import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final mainSource = File('lib/main.dart').readAsStringSync();
  final brandSource = File('lib/erp/screens/erp_brands_tab.dart').readAsStringSync();
  final erpOffersSource = File('lib/erp/screens/erp_item_offers_screen.dart').readAsStringSync();
  final offerRepository = File('lib/services/supplier_offer_service.dart').readAsStringSync();
  final offerPrices = File('lib/services/offer_service.dart').readAsStringSync();
  final brandMigration = File('supabase/migrations/20261115023000_erp_brand_names_atomic_grid_edit.sql').readAsStringSync();
  final offerMigration = File('supabase/migrations/20261115025000_supplier_offers_support_erp_catalog_items.sql').readAsStringSync();

  test('Trader Market uses the ERP UUID catalog and the complete owner header', () {
    expect(mainSource, contains("from('erp_item_categories')"));
    expect(mainSource, contains("from('erp_items')"));
    expect(mainSource, contains("from('erp_item_units')"));
    expect(mainSource, contains('_marketUnitOptions'));
    expect(mainSource, contains("'small_unit_price':smallUnitPrice"));
    expect(mainSource, contains('FavoriteService().setProductFavorite'));
    expect(mainSource, contains('OfferService().getActiveProductOfferPrices'));
    expect(mainSource, contains('عرض خاص'));
    expect(mainSource, contains('final Set<String> _expandedCategoryIds'));
    expect(mainSource, contains('_marketCategoryParentId'));
    expect(mainSource, contains('_marketDescendantProducts'));
    expect(mainSource, contains("'image_data': item['image_data']"));
    expect(mainSource, contains('whatsapp_phone'));
    expect(mainSource, contains('_publisherAccountLabel'));
    expect(mainSource, contains('_publisherClassification'));
    expect(mainSource, contains('avatar_url'));
  });

  test('Supplier offers select categories, brands and ERP items before publishing', () {
    expect(mainSource, contains('offerItemCategories'));
    expect(mainSource, contains('offerCategoryNode'));
    expect(mainSource, contains('offerBrandNode'));
    expect(mainSource, contains('offerProductNode'));
    expect(mainSource, contains('erpItemIdByCartKey'));
    expect(mainSource, contains("'erp_item_id': erpItemId"));
    expect(mainSource, contains('اختر صنفًا واحدًا على الأقل قبل نشر العرض'));
    expect(offerRepository, contains("'erp_item_id': erpItemId"));
    expect(offerPrices, contains("erp_item_id, offer_price"));
    expect(offerMigration, contains('offer_items_erp_item_id_idx'));
    expect(offerMigration, contains('validate_supplier_offer_erp_item'));
  });

  test('ERP campaign offers support recursive product selection and editing', () {
    expect(erpOffersSource, contains('categoryNode=(category,depth'));
    expect(erpOffersSource, contains('groupByBrand'));
    expect(erpOffersSource, contains('_inventory.fetchBrands(company)'));
    expect(erpOffersSource, contains('_editCampaign(campaign)'));
    expect(erpOffersSource, contains('_editingCampaignId'));
    expect(erpOffersSource, contains("onConflict:'campaign_id,item_id'"));
    expect(erpOffersSource, contains('image_data'));
  });

  test('Brand image and group changes preserve the current screen and refresh silently', () {
    expect(brandSource, contains('Future<void> _load({bool showLoading = true})'));
    expect(brandSource, contains('if (showLoading) setState(() { _loading = true; _error = null; });'));
    expect(brandSource, contains('Keep the current Brands tab alive after each upload'));
    expect(brandSource, contains('await _load(showLoading: false);'));
    expect(brandSource, contains('Future<void> _assignGroup'));
    expect(brandSource, contains('Future<void> _toggleGroupField'));
    expect(brandSource, contains('Future<void> _uploadLogo'));
  });

  test('Brand grid supports single-row and bulk atomic renaming', () {
    expect(brandSource, contains('تعديل المحدد'));
    expect(brandSource, contains('تعديل الكل'));
    expect(brandSource, contains('_gridEditingOnlyId'));
    expect(brandSource, contains('erp_update_brand_names_batch'));
    expect(brandSource, contains('لم يتم عرض تفاصيل تقنية أو أكواد للمستخدم'));
    expect(brandMigration, contains('SECURITY INVOKER'));
    expect(brandMigration, contains('v_marker'));
    expect(brandMigration, contains('lower(btrim(b.brand_name))'));
  });
}
