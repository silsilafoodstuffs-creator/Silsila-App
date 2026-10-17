import 'package:supabase_flutter/supabase_flutter.dart';

class ErpPriceListsRepository {
  ErpPriceListsRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول لقوائم الأسعار.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchLists(String companyId, {String kind = 'sale'}) async {
    final rows = await _db.from('erp_price_lists')
      .select('id, price_list_code, price_list_name, price_kind, currency_code, starts_on, ends_on, is_default, is_active, notes')
      .eq('company_id', companyId.trim()).eq('price_kind', kind)
      .order('price_list_code');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<List<Map<String, dynamic>>> fetchItems(String companyId) async {
    final rows = await _db.from('erp_items')
      .select('id, item_code, item_name, base_unit, sale_price, purchase_price, is_active')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('item_code').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<List<Map<String, dynamic>>> fetchParties(String companyId, String kind) async {
    final rows = await _db.from('erp_parties')
      .select('id, party_code, party_name, party_kind, is_active')
      .eq('company_id', companyId.trim()).eq('is_active', true)
      .inFilter('party_kind', [kind, 'both']).order('party_name').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<List<Map<String, dynamic>>> fetchLines(String companyId, String listId) async {
    final rows = await _db.from('erp_price_list_lines')
      .select('id, item_id, min_quantity, unit_price, discount_percent, starts_on, ends_on')
      .eq('company_id', companyId.trim()).eq('price_list_id', listId)
      .order('item_id').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<void> createList({
    required String companyId, required String code, required String name,
    required String kind, bool isDefault = false, String currency = 'EGP', String? notes,
  }) async {
    if (companyId.trim().isEmpty || code.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('الشركة وكود القائمة واسمها حقول مطلوبة.');
    }
    if (!['sale','purchase'].contains(kind)) throw ArgumentError('نوع القائمة غير صحيح.');
    await _db.from('erp_price_lists').insert({
      'company_id': companyId.trim(), 'price_list_code': code.trim(),
      'price_list_name': name.trim(), 'price_kind': kind,
      'currency_code': currency.trim().isEmpty ? 'EGP' : currency.trim().toUpperCase(),
      'is_default': isDefault, 'is_active': true, 'notes': _blank(notes),
    });
  }
  Future<void> addLine({
    required String companyId, required String listId, required String itemId,
    required double unitPrice, double minQuantity = 1, double discountPercent = 0,
  }) async {
    if (unitPrice < 0 || minQuantity <= 0 || discountPercent < 0 || discountPercent > 100) {
      throw ArgumentError('راجع السعر والحد الأدنى ونسبة الخصم.');
    }
    await _db.from('erp_price_list_lines').insert({
      'company_id': companyId.trim(), 'price_list_id': listId, 'item_id': itemId,
      'unit_price': unitPrice, 'min_quantity': minQuantity, 'discount_percent': discountPercent,
    });
  }
  Future<void> assignParty({
    required String companyId, required String partyId, required String listId,
  }) async {
    await _db.from('erp_party_price_lists').upsert({
      'company_id': companyId.trim(), 'party_id': partyId, 'price_list_id': listId,
    }, onConflict: 'party_id,price_list_id');
  }
  Future<Map<String, dynamic>?> resolvePrice({
    required String companyId, required String itemId, required String kind,
    required double quantity, String? partyId, DateTime? priceDate,
  }) async {
    final day = (priceDate ?? DateTime.now()).toIso8601String().substring(0, 10);
    final result = await _db.rpc('erp_resolve_item_price', params: {
      'p_company_id': companyId.trim(),
      'p_item_id': itemId,
      'p_price_kind': kind,
      'p_quantity': quantity,
      'p_party_id': partyId,
      'p_price_date': day,
    });
    if (result is List && result.isNotEmpty) return Map<String, dynamic>.from(result.first as Map);
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  Future<void> setListActive(String id, bool active) async {
    await _db.from('erp_price_lists').update({'is_active': active}).eq('id', id);
  }
  static String? _blank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
