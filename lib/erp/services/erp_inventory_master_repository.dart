import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErpInventoryMasterRepository {
  ErpInventoryMasterRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول إلى بيانات المخزون الأساسية.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses(String companyId) async {
    final db = _db;
    final id = companyId.trim();
    try {
      final rows = await db.from('erp_warehouses')
        .select('id, warehouse_code, warehouse_name, warehouse_name_en, parent_warehouse_id, branch_id, address, location, phone, landline, governorate_id, district_id, area_id, is_active')
        .eq('company_id', id).order('warehouse_code');
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (_) {
      // Older deployments may not yet have all optional geography/contact columns.
      final rows = await db.from('erp_warehouses')
        .select('id, warehouse_code, warehouse_name, branch_id, address, is_active')
        .eq('company_id', id).order('warehouse_code');
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    }
  }
  Future<List<Map<String, dynamic>>> fetchCategories(String companyId, {int offset = 0, int pageSize = 1000, String search = ''}) async {
    if (offset < 0 || pageSize < 1 || pageSize > 2000) throw ArgumentError('نطاق صفحة فئات الأصناف غير صالح.');
    var query = _db.from('erp_item_categories')
      .select('id, category_code, category_name, parent_id, is_active')
      .eq('company_id', companyId.trim());
    final term = search.trim();
    if (term.isNotEmpty) query = query.or('category_code.ilike.%$term%,category_name.ilike.%$term%');
    final rows = await query.order('category_code').range(offset, offset + pageSize - 1);
    return rows.map((r) { final item = Map<String, dynamic>.from(r); item['category_code'] = item['category_code']; item['category_name'] = item['category_name']; return item; }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchItems(String companyId, {int offset = 0, int pageSize = 500, String search = ''}) async {
    if (offset < 0 || pageSize < 1 || pageSize > 1000) throw ArgumentError('نطاق صفحة الأصناف غير صالح.');
    var query = _db.from('erp_items')
      .select('id, item_code, barcode, item_name, item_name_en, category_id, base_unit, purchase_price, sale_price, tax_rate, reorder_level, expiry_tracking, is_active, image_url, image_mime_type')
      .eq('company_id', companyId.trim());
    final term = search.trim();
    if (term.isNotEmpty) query = query.or('item_name.ilike.%$term%,item_code.ilike.%$term%,barcode.ilike.%$term%');
    final rows = await query.order('item_code').range(offset, offset + pageSize - 1);
    return rows.map((r) { final item = Map<String, dynamic>.from(r); item['category_id'] = item['category_id']; return item; }).toList();
  }
  Future<Uint8List?> fetchItemImage(String companyId, String itemId) async {
    final row = await _db.from('erp_items').select('image_data').eq('company_id', companyId.trim()).eq('id', itemId).maybeSingle();
    final value = row?['image_data'];
    if (value == null) return null;
    final raw = value.toString();
    final prefix = raw.startsWith(r'\\x') ? 3 : raw.startsWith(r'\x') ? 2 : 0;
    if (prefix == 0 || raw.length <= prefix || (raw.length - prefix).isOdd) return null;
    try { return Uint8List.fromList(List<int>.generate((raw.length - prefix) ~/ 2, (i) => int.parse(raw.substring(prefix + i * 2, prefix + i * 2 + 2), radix: 16))); } catch (_) { return null; }
  }

  Future<List<Map<String, dynamic>>> fetchBranches(String companyId) async {
    final rows = await _db.from('erp_branches')
      .select('id, branch_code, branch_name, is_active')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('branch_code');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createWarehouse({
    required String companyId, required String code, required String name,
    String? branchId, String? address, String? nameEn, String? parentWarehouseId,
    String? location, String? phone, String? landline, String? governorateId, String? districtId, String? areaId,
  }) async {
    if (code.trim().isEmpty || name.trim().isEmpty) throw ArgumentError('كود المخزن واسمه مطلوبان.');
    await _db.from('erp_warehouses').insert({
      'company_id': companyId.trim(), 'warehouse_code': code.trim(), 'warehouse_name': name.trim(),
      'branch_id': branchId, 'address': _blank(address), 'warehouse_name_en': _blank(nameEn),
      'parent_warehouse_id': parentWarehouseId, 'location': _blank(location), 'phone': _blank(phone), 'landline': _blank(landline),
      'governorate_id': governorateId, 'district_id': districtId, 'area_id': areaId, 'is_active': true,
    });
  }

  Future<void> createItem({
    required String companyId, required String code, required String name,
    String? barcode, String? categoryId, String unit = 'وحدة', double purchasePrice = 0,
    double salePrice = 0, double taxRate = 0, double reorderLevel = 0, bool expiryTracking = false, String? imageUrl, Uint8List? imageBytes, String? imageMimeType,
  }) async {
    if (code.trim().isEmpty || name.trim().isEmpty || unit.trim().isEmpty) {
      throw ArgumentError('كود الصنف والاسم ووحدة القياس حقول مطلوبة.');
    }
    if (purchasePrice < 0 || salePrice < 0 || reorderLevel < 0 || taxRate < 0 || taxRate > 100) throw ArgumentError('الأسعار وحد إعادة الطلب لا تقبل القيم السالبة، ونسبة الضريبة من 0 إلى 100.');
    await _db.from('erp_items').insert({
      'company_id': companyId.trim(), 'item_code': code.trim(), 'item_name': name.trim(), 'category_id': categoryId,
      'barcode': _blank(barcode), 'base_unit': unit.trim(),
      'purchase_price': purchasePrice, 'sale_price': salePrice, 'tax_rate': taxRate,
      'reorder_level': reorderLevel, 'expiry_tracking': expiryTracking,
      'image_data': imageBytes == null || imageBytes.isEmpty ? null : _byteaHex(imageBytes),
      'image_mime_type': imageBytes == null || imageBytes.isEmpty ? null : _blank(imageMimeType),
      'image_url': null, 'is_active': true,
    });
  }


  String _byteaHex(Uint8List bytes) => '\\x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

  Future<void> setWarehouseActive(String id, bool active) async {
    await _db.from('erp_warehouses').update({'is_active': active}).eq('id', id);
  }
  Future<void> setItemActive(String id, bool active) async {
    await _db.from('erp_items').update({'is_active': active}).eq('id', id);
  }

  static String? _blank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
