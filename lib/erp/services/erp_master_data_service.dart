import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for ERP master records. Every query is company-scoped in the
/// client and must also be enforced by restrictive Supabase RLS policies.
class ErpMasterDataService {
  ErpMasterDataService({SupabaseClient? client})
      : _client = client ?? _defaultClient;

  final SupabaseClient? _client;

  static SupabaseClient? get _defaultClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _db {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase غير مهيأ. قم بتهيئته قبل استخدام بيانات ERP.');
    }
    return client;
  }

  Future<List<Map<String, dynamic>>> listBranches({
    required String companyId,
    bool activeOnly = true,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    var query = _db.from('erp_branches').select().eq('company_id', companyId);
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('branch_name');
    return _maps(rows);
  }

  Future<void> saveBranch({
    String? id,
    required String companyId,
    required String code,
    required String name,
    String? phone,
    String? address,
    bool isMain = false,
    bool isActive = true,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    _require(code, 'كود الفرع مطلوب.');
    _require(name, 'اسم الفرع مطلوب.');
    final payload = <String, Object?>{
      'company_id': companyId,
      'branch_code': code.trim(),
      'branch_name': name.trim(),
      'phone': _nullable(phone),
      'address': _nullable(address),
      'is_main': isMain,
      'is_active': isActive,
    };
    if (id == null || id.trim().isEmpty) {
      await _db.from('erp_branches').insert(payload);
    } else {
      await _db.from('erp_branches').update(payload)
          .eq('id', id).eq('company_id', companyId);
    }
  }

  Future<List<Map<String, dynamic>>> listItemCategorys({
    required String companyId,
    bool activeOnly = true,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    var query = _db.from('erp_item_categories').select('*,category_code:category_code,category_name:category_name,category_name_en:category_name_en').eq('company_id', companyId);
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('category_name');
    return _maps(rows);
  }

  Future<void> saveItemCategory({
    String? id,
    required String companyId,
    String? parentId,
    required String code,
    required String name,
    bool isActive = true,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    _require(code, 'كود الفئة مطلوب.');
    _require(name, 'اسم الفئة مطلوب.');
    final payload = <String, Object?>{
      'company_id': companyId,
      'parent_id': _nullable(parentId),
      'category_code': code.trim(),
      'category_name': name.trim(),
      'is_active': isActive,
    };
    if (id == null || id.trim().isEmpty) {
      await _db.from('erp_item_categories').insert(payload);
    } else {
      await _db.from('erp_item_categories').update(payload)
          .eq('id', id).eq('company_id', companyId);
    }
  }

  Future<List<Map<String, dynamic>>> listItems({
    required String companyId,
    String? categoryId,
    String? search,
    bool activeOnly = true,
    int limit = 100,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    var query = _db.from('erp_items').select().eq('company_id', companyId);
    if (activeOnly) query = query.eq('is_active', true);
    if (categoryId != null && categoryId.trim().isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = _escapeLike(search.trim());
      query = query.or('item_name.ilike.%$term%,item_code.ilike.%$term%,barcode.ilike.%$term%');
    }
    final rows = await query.order('item_name').limit(limit.clamp(1, 500));
    return _maps(rows);
  }

  Future<void> saveItem({
    String? id,
    required String companyId,
    String? categoryId,
    required String code,
    String? barcode,
    required String name,
    String baseUnit = 'وحدة',
    num purchasePrice = 0,
    num salePrice = 0,
    num reorderLevel = 0,
    bool expiryTracking = false,
    bool isActive = true,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    _require(code, 'كود الصنف مطلوب.');
    _require(name, 'اسم الصنف مطلوب.');
    if (purchasePrice < 0 || salePrice < 0 || reorderLevel < 0) {
      throw ArgumentError('الأسعار وحد إعادة الطلب لا يمكن أن تكون سالبة.');
    }
    final payload = <String, Object?>{
      'company_id': companyId,
      'category_id': _nullable(categoryId),
      'item_code': code.trim(),
      'barcode': _nullable(barcode),
      'item_name': name.trim(),
      'base_unit': baseUnit.trim().isEmpty ? 'وحدة' : baseUnit.trim(),
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'reorder_level': reorderLevel,
      'expiry_tracking': expiryTracking,
      'is_active': isActive,
    };
    if (id == null || id.trim().isEmpty) {
      await _db.from('erp_items').insert(payload);
    } else {
      await _db.from('erp_items').update(payload)
          .eq('id', id).eq('company_id', companyId);
    }
  }

  Future<List<Map<String, dynamic>>> listParties({
    required String companyId,
    String? kind,
    String? search,
    bool activeOnly = true,
    int limit = 100,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    if (kind != null && !const {'supplier', 'customer', 'both'}.contains(kind)) {
      throw ArgumentError('نوع الطرف غير صالح.');
    }
    var query = _db.from('erp_parties').select().eq('company_id', companyId);
    if (activeOnly) query = query.eq('is_active', true);
    if (kind != null) query = query.eq('party_kind', kind);
    if (search != null && search.trim().isNotEmpty) {
      final term = _escapeLike(search.trim());
      query = query.or('party_name.ilike.%$term%,party_code.ilike.%$term%,phone.ilike.%$term%');
    }
    final rows = await query.order('party_name').limit(limit.clamp(1, 500));
    return _maps(rows);
  }

  Future<void> saveParty({
    String? id,
    required String companyId,
    required String code,
    required String name,
    required String kind,
    String? phone,
    String? whatsapp,
    String? email,
    String? taxNumber,
    String? address,
    String? governorate,
    String? district,
    num creditLimit = 0,
    num openingBalance = 0,
    bool isActive = true,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    _require(code, 'كود الطرف مطلوب.');
    _require(name, 'اسم الطرف مطلوب.');
    if (!const {'supplier', 'customer', 'both'}.contains(kind)) {
      throw ArgumentError('نوع الطرف يجب أن يكون supplier أو customer أو both.');
    }
    if (creditLimit < 0) throw ArgumentError('حد الائتمان لا يمكن أن يكون سالبًا.');
    final payload = <String, Object?>{
      'company_id': companyId,
      'party_code': code.trim(),
      'party_name': name.trim(),
      'party_kind': kind,
      'phone': _nullable(phone),
      'whatsapp': _nullable(whatsapp),
      'email': _nullable(email),
      'tax_number': _nullable(taxNumber),
      'address': _nullable(address),
      'governorate': _nullable(governorate),
      'district': _nullable(district),
      'credit_limit': creditLimit,
      'opening_balance': openingBalance,
      'is_active': isActive,
    };
    if (id == null || id.trim().isEmpty) {
      await _db.from('erp_parties').insert(payload);
    } else {
      await _db.from('erp_parties').update(payload)
          .eq('id', id).eq('company_id', companyId);
    }
  }

  static List<Map<String, dynamic>> _maps(dynamic rows) =>
      (rows as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

  static String? _nullable(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static String _escapeLike(String value) =>
      value.replaceAll(',', r'\,').replaceAll('%', r'\%').replaceAll('_', r'\_');

  static void _require(String value, String message) {
    if (value.trim().isEmpty) throw ArgumentError(message);
  }
}
