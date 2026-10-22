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
    final rows = await _db.from('erp_warehouses')
      .select('id, warehouse_code, warehouse_name, branch_id, address, is_active')
      .eq('company_id', companyId.trim()).order('warehouse_code');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<List<Map<String, dynamic>>> fetchCategories(String companyId) async {
    final rows = await _db.from('erp_item_categories')
      .select('id, category_code, category_name, parent_id, is_active')
      .eq('company_id', companyId.trim()).order('category_code').limit(2000);
    return rows.map((r) { final item = Map<String, dynamic>.from(r); item['group_code'] = item['category_code']; item['group_name'] = item['category_name']; return item; }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchItems(String companyId) async {
    final rows = await _db.from('erp_items')
      .select('id, item_code, barcode, item_name, category_id, base_unit, purchase_price, sale_price, tax_rate, reorder_level, expiry_tracking, is_active, image_url, image_data, image_mime_type')
      .eq('company_id', companyId.trim()).order('item_code').limit(2000);
    return rows.map((r) { final item = Map<String, dynamic>.from(r); item['group_id'] = item['category_id']; return item; }).toList();
  }
  Future<List<Map<String, dynamic>>> fetchBranches(String companyId) async {
    final rows = await _db.from('erp_branches')
      .select('id, branch_code, branch_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('branch_code');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createWarehouse({
    required String companyId, required String code, required String name,
    String? branchId, String? address,
  }) async {
    if (code.trim().isEmpty || name.trim().isEmpty) throw ArgumentError('كود المخزن واسمه مطلوبان.');
    await _db.from('erp_warehouses').insert({
      'company_id': companyId.trim(), 'warehouse_code': code.trim(), 'warehouse_name': name.trim(),
      'branch_id': branchId, 'address': _blank(address), 'is_active': true,
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
      'company_id': companyId.trim(), 'item_code': code.trim(), 'item_name': name.trim(), 'group_id': categoryId,
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
