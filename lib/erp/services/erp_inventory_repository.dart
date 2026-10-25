import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads inventory ledger data and records movements through a validated RPC.
class ErpInventoryRepository {
  ErpInventoryRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;

  static SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _db {
    final value = _client;
    if (value == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول للمخزون.');
    return value;
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses(String companyId) async {
    final rows = await _db.from('erp_warehouses')
        .select('id, warehouse_code, warehouse_name, branch_id')
        .eq('company_id', companyId.trim()).eq('is_active', true)
        .order('warehouse_name');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchItems(String companyId) async {
    final rows = await _db.from('erp_items')
        .select('id, item_code, item_name, base_unit, purchase_price, sale_price')
        .eq('company_id', companyId.trim()).eq('is_active', true)
        .order('item_name').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchBalances(String companyId) async {
    final rows = await _db.from('erp_stock_balances')
        .select('company_id, branch_id, warehouse_id, item_id, quantity_on_hand, last_movement_at, inventory_value, average_unit_cost')
        .eq('company_id', companyId.trim())
        .order('last_movement_at', ascending: false).limit(1000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMovements(String companyId) async {
    final rows = await _db.from('erp_inventory_movements')
        .select('id, movement_date, movement_type, warehouse_id, item_id, quantity_in, quantity_out, unit_cost, notes, batch_number')
        .eq('company_id', companyId.trim())
        .order('movement_date', ascending: false).limit(100);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<bool> policyApplies(String companyId, String policyKey) async {
    final actorId = _db.auth.currentUser?.id;
    final result = await _db.rpc('erp_program_policy_applies', params: {
      'p_company_id': companyId.trim(),
      'p_policy_key': policyKey,
      'p_actor_id': actorId,
    });
    return result == true;
  }

  Future<String> recordMovement({
    required String companyId,
    required String warehouseId,
    required String itemId,
    required String movementType,
    required double quantity,
    required double unitCost,
    String? branchId,
    String? notes,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    if (companyId.trim().isEmpty || warehouseId.isEmpty || itemId.isEmpty) {
      throw ArgumentError('الشركة والمخزن والصنف حقول إلزامية.');
    }
    if (quantity <= 0 || unitCost < 0) {
      throw ArgumentError('الكمية أكبر من صفر والتكلفة لا تقل عن صفر.');
    }
    final result = await _db.rpc('erp_record_inventory_movement', params: {
      'p_company_id': companyId.trim(),
      'p_warehouse_id': warehouseId,
      'p_item_id': itemId,
      'p_movement_type': movementType,
      'p_quantity': quantity,
      'p_unit_cost': unitCost,
      'p_branch_id': branchId,
      'p_movement_date': DateTime.now().toUtc().toIso8601String(),
      'p_reference_type': 'manual',
      'p_reference_id': null,
      'p_batch_number': batchNumber,
      'p_expiry_date': expiryDate == null ? null : _dateOnly(expiryDate),
      'p_notes': notes,
    });
    return result.toString();
  }

  Future<String> transferInventory({
    required String companyId,
    required String sourceWarehouseId,
    required String targetWarehouseId,
    required String itemId,
    required double quantity,
    required double unitCost,
    String? notes,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    if (sourceWarehouseId == targetWarehouseId) {
      throw ArgumentError('يجب اختيار مخزنين مختلفين.');
    }
    if (quantity <= 0 || unitCost < 0) {
      throw ArgumentError('الكمية أكبر من صفر والتكلفة لا تقل عن صفر.');
    }
    final result = await _db.rpc('erp_transfer_inventory_between_warehouses', params: {
      'p_company_id': companyId.trim(),
      'p_source_warehouse_id': sourceWarehouseId,
      'p_target_warehouse_id': targetWarehouseId,
      'p_item_id': itemId,
      'p_quantity': quantity,
      'p_unit_cost': unitCost,
      'p_transfer_date': DateTime.now().toUtc().toIso8601String(),
      'p_batch_number': batchNumber,
      'p_expiry_date': expiryDate == null ? null : _dateOnly(expiryDate),
      'p_notes': notes,
    });
    return result.toString();
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
