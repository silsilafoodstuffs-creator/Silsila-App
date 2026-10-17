import 'package:supabase_flutter/supabase_flutter.dart';

/// Company-scoped persistence for ERP permissions, pricing and transaction controls.
///
/// This service deliberately requires a real company ID on every operation.
/// Database RLS must independently enforce membership and authorization.
/// Do not use this client service as the sole security boundary.
class ErpControlsService {
  ErpControlsService({SupabaseClient? client}) : _client = client ?? _defaultClient;

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
      throw StateError('Supabase غير مهيأ. لا يمكن حفظ إعدادات ERP.');
    }
    return client;
  }

  String? get currentUserId => _client?.auth.currentUser?.id;

  void _requireId(String value, String message) {
    if (value.trim().isEmpty) throw ArgumentError(message);
  }

  /// Returns permission rows for one company and role.
  Future<List<Map<String, dynamic>>> listPermissions({
    required String companyId,
    String? roleKey,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    var query = _db.from('erp_role_permissions').select().eq('company_id', companyId);
    if (roleKey != null && roleKey.trim().isNotEmpty) {
      query = query.eq('role_key', roleKey.trim());
    }
    final rows = await query.order('role_key').order('module_key').order('permission_key');
    return (rows as List).whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Upserts a single permission. Server-side RLS must validate the acting user.
  Future<void> savePermission({
    required String companyId,
    required String roleKey,
    required String moduleKey,
    required String permissionKey,
    required bool enabled,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    _requireId(roleKey, 'تصنيف المستخدم مطلوب.');
    _requireId(moduleKey, 'القسم مطلوب.');
    _requireId(permissionKey, 'الصلاحية مطلوبة.');
    await _db.from('erp_role_permissions').upsert({
      'company_id': companyId,
      'role_key': roleKey.trim(),
      'module_key': moduleKey.trim(),
      'permission_key': permissionKey.trim(),
      'is_enabled': enabled,
      'updated_by': currentUserId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'company_id,role_key,module_key,permission_key');
  }

  Future<List<Map<String, dynamic>>> listPricingPolicies({
    required String companyId,
    String? itemId,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    var query = _db.from('erp_pricing_policies').select().eq('company_id', companyId);
    if (itemId != null && itemId.trim().isNotEmpty) query = query.eq('item_id', itemId.trim());
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Saves a pricing rule; validates direction and numeric limits before writing.
  Future<String> savePricingPolicy({
    required String companyId,
    required String name,
    required String adjustmentType,
    required String adjustmentDirection,
    required double adjustmentValue,
    required double maxInvoiceDiscountPercent,
    required double maxItemDiscountPercent,
    String? itemId,
    double? basePrice,
    double? priceFloor,
    bool isActive = true,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    _requireId(name, 'اسم سياسة التسعير مطلوب.');
    if (!const ['percent', 'amount'].contains(adjustmentType)) {
      throw ArgumentError('نوع تعديل السعر يجب أن يكون percent أو amount.');
    }
    if (!const ['increase', 'decrease'].contains(adjustmentDirection)) {
      throw ArgumentError('اتجاه تعديل السعر يجب أن يكون increase أو decrease.');
    }
    if (adjustmentValue < 0 || maxInvoiceDiscountPercent < 0 ||
        maxInvoiceDiscountPercent > 100 || maxItemDiscountPercent < 0 ||
        maxItemDiscountPercent > 100 || (basePrice != null && basePrice < 0) ||
        (priceFloor != null && priceFloor < 0)) {
      throw ArgumentError('قيمة السعر أو نسبة الخصم خارج النطاق المسموح.');
    }
    final row = <String, dynamic>{
      'company_id': companyId,
      'policy_name': name.trim(),
      'item_id': itemId,
      'adjustment_type': adjustmentType,
      'adjustment_direction': adjustmentDirection,
      'adjustment_value': adjustmentValue,
      'base_price': basePrice,
      'price_floor': priceFloor,
      'max_invoice_discount_percent': maxInvoiceDiscountPercent,
      'max_item_discount_percent': maxItemDiscountPercent,
      'is_active': isActive,
      'updated_by': currentUserId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final result = await _db.from('erp_pricing_policies').insert(row).select('id').single();
    return result['id'].toString();
  }

  Future<List<Map<String, dynamic>>> listItemDelegateAssignments({
    required String companyId,
    String? delegateId,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    var query = _db.from('erp_item_delegate_assignments').select().eq('company_id', companyId);
    if (delegateId != null && delegateId.trim().isNotEmpty) {
      query = query.eq('delegate_id', delegateId.trim());
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<void> setItemDelegateAssignment({
    required String companyId,
    required String itemId,
    required String delegateId,
    required bool allowed,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    _requireId(itemId, 'معرّف الصنف مطلوب.');
    _requireId(delegateId, 'معرّف المندوب مطلوب.');
    if (allowed) {
      await _db.from('erp_item_delegate_assignments').upsert({
        'company_id': companyId,
        'item_id': itemId,
        'delegate_id': delegateId,
        'is_allowed': true,
        'updated_by': currentUserId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'company_id,item_id,delegate_id');
    } else {
      await _db.from('erp_item_delegate_assignments')
          .delete()
          .eq('company_id', companyId)
          .eq('item_id', itemId)
          .eq('delegate_id', delegateId);
    }
  }

  Future<List<Map<String, dynamic>>> listTransactionRestrictions({
    required String companyId,
    bool activeOnly = true,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    var query = _db.from('erp_transaction_restrictions').select().eq('company_id', companyId);
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<String> saveTransactionRestriction({
    required String companyId,
    required String action,
    required String targetType,
    String? itemId,
    String? customerId,
    String? delegateId,
    String? documentId,
    double? maximumQuantity,
    bool isActive = true,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    if (!const ['stop_sale', 'stop_purchase', 'sale_limit'].contains(action)) {
      throw ArgumentError('نوع القيد غير معروف.');
    }
    if (!const ['item', 'invoice', 'customer', 'delegate'].contains(targetType)) {
      throw ArgumentError('مستوى تطبيق القيد غير معروف.');
    }
    if (maximumQuantity != null && maximumQuantity < 0) {
      throw ArgumentError('حد البيع لا يمكن أن يكون سالبًا.');
    }
    final row = await _db.from('erp_transaction_restrictions').insert({
      'company_id': companyId,
      'action_key': action,
      'target_type': targetType,
      'item_id': itemId,
      'customer_id': customerId,
      'delegate_id': delegateId,
      'document_id': documentId,
      'maximum_quantity': maximumQuantity,
      'is_active': isActive,
      'created_by': currentUserId,
      'updated_by': currentUserId,
    }).select('id').single();
    return row['id'].toString();
  }
}
