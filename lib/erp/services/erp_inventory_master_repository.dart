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
  Future<List<Map<String, dynamic>>> fetchGroups(String companyId) async {
    final rows = await _db.from('erp_item_groups')
      .select('id, group_code, group_name, parent_id, is_active')
      .eq('company_id', companyId.trim()).order('group_code').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createGroup({
    required String companyId, required String code, required String name, String? parentId,
  }) async {
    if (code.trim().isEmpty || name.trim().isEmpty) throw ArgumentError('كود المجموعة واسمها مطلوبان.');
    if (parentId != null) {
      final parent = await _db.from('erp_item_groups').select('company_id, is_active').eq('id', parentId).maybeSingle();
      if (parent == null || parent['company_id'] != companyId.trim() || parent['is_active'] != true) {
        throw ArgumentError('المجموعة الأب غير نشطة أو لا تتبع الشركة.');
      }
    }
    await _db.from('erp_item_groups').insert({
      'company_id': companyId.trim(), 'group_code': code.trim(), 'group_name': name.trim(),
      'parent_id': parentId, 'is_active': true,
    });
  }

  Future<void> setGroupActive(String id, bool active) async {
    await _db.from('erp_item_groups').update({'is_active': active}).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchItems(String companyId) async {
    final rows = await _db.from('erp_items')
      .select('id, item_code, barcode, item_name, base_unit, purchase_price, sale_price, reorder_level, expiry_tracking, is_active')
      .eq('company_id', companyId.trim()).order('item_code').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
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
    String? barcode, String? groupId, String unit = 'وحدة', double purchasePrice = 0,
    double salePrice = 0, double reorderLevel = 0, bool expiryTracking = false,
  }) async {
    if (code.trim().isEmpty || name.trim().isEmpty || unit.trim().isEmpty) {
      throw ArgumentError('كود الصنف والاسم ووحدة القياس حقول مطلوبة.');
    }
    if (purchasePrice < 0 || salePrice < 0 || reorderLevel < 0) throw ArgumentError('الأسعار وحد إعادة الطلب لا تقبل القيم السالبة.');
    await _db.from('erp_items').insert({
      'company_id': companyId.trim(), 'item_code': code.trim(), 'item_name': name.trim(), 'group_id': groupId,
      'barcode': _blank(barcode), 'base_unit': unit.trim(),
      'purchase_price': purchasePrice, 'sale_price': salePrice,
      'reorder_level': reorderLevel, 'expiry_tracking': expiryTracking, 'is_active': true,
    });
  }

  Future<void> setWarehouseActive(String id, bool active) async {
    await _db.from('erp_warehouses').update({'is_active': active}).eq('id', id);
  }
  Future<void> setItemActive(String id, bool active) async {
    await _db.from('erp_items').update({'is_active': active}).eq('id', id);
  }

  static String? _blank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
