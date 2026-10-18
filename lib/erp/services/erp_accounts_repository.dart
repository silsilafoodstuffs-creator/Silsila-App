import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for the ERP chart of accounts.
/// Company authorization remains enforced by Supabase RLS.
class ErpAccountsRepository {
  ErpAccountsRepository({SupabaseClient? client})
      : _client = client ?? _tryGetClient();

  final SupabaseClient? _client;

  static SupabaseClient? _tryGetClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase غير مهيأ؛ لا يمكن تحميل شجرة الحسابات.');
    }
    if (client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول قبل الوصول إلى شجرة الحسابات.');
    }
    return client;
  }

  Future<List<Map<String, dynamic>>> fetchAccountMetrics({
    required String companyId,
    bool activeOnly = false,
  }) async {
    if (companyId.trim().isEmpty) {
      throw ArgumentError('يجب تحديد الشركة قبل تحميل الحسابات.');
    }
    var query = _requireClient
        .from('erp_account_tree_metrics')
        .select()
        .eq('company_id', companyId.trim());
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('account_code');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> createAccount({
    required String companyId,
    required String code,
    required String name,
    required String accountType,
    required String normalBalance,
    String? parentId,
    bool isPostable = false,
  }) async {
    final normalizedCode = code.trim();
    final normalizedName = name.trim();
    final normalizedCompany = companyId.trim();
    if (normalizedCompany.isEmpty ||
        normalizedCode.isEmpty ||
        normalizedName.isEmpty) {
      throw ArgumentError('الشركة وكود الحساب واسم الحساب حقول إلزامية.');
    }
    _validateTypeAndBalance(accountType, normalBalance);
    parentId = _normalizeParent(parentId);
    final client = _requireClient;
    await _validateParent(
      client,
      companyId: normalizedCompany,
      parentId: parentId,
    );
    final inserted = await client.from('erp_accounts').insert({
      'company_id': normalizedCompany,
      'account_code': normalizedCode,
      'account_name': normalizedName,
      'account_type': accountType,
      'normal_balance': normalBalance,
      'parent_id': parentId,
      'is_postable': isPostable,
      'is_active': true,
    }).select().single();
    return Map<String, dynamic>.from(inserted);
  }

  Future<Map<String, dynamic>> updateAccount({
    required String companyId,
    required String accountId,
    required String code,
    required String name,
    required String accountType,
    required String normalBalance,
    required bool isPostable,
    required bool isActive,
    String? parentId,
  }) async {
    final normalizedCompany = companyId.trim();
    final normalizedId = accountId.trim();
    final normalizedCode = code.trim();
    final normalizedName = name.trim();
    if (normalizedCompany.isEmpty || normalizedId.isEmpty) {
      throw ArgumentError('معرّف الشركة والحساب مطلوبان.');
    }
    if (normalizedCode.isEmpty || normalizedName.isEmpty) {
      throw ArgumentError('كود الحساب واسم الحساب حقول إلزامية.');
    }
    _validateTypeAndBalance(accountType, normalBalance);
    final normalizedParent = _normalizeParent(parentId);
    if (normalizedParent == normalizedId) {
      throw StateError('لا يمكن اختيار الحساب نفسه كحساب أب.');
    }

    final client = _requireClient;
    await _validateParent(
      client,
      companyId: normalizedCompany,
      parentId: normalizedParent,
    );

    // Reject a parent anywhere below this account to prevent hierarchy cycles.
    if (normalizedParent != null) {
      final records = await client
          .from('erp_accounts')
          .select('id,parent_id')
          .eq('company_id', normalizedCompany);
      final childrenByParent = <String, List<String>>{};
      for (final record in records) {
        final id = (record['id'] ?? '').toString();
        final parent = (record['parent_id'] ?? '').toString();
        if (id.isNotEmpty && parent.isNotEmpty) {
          childrenByParent.putIfAbsent(parent, () => <String>[]).add(id);
        }
      }
      final descendants = <String>{};
      final pending = <String>[normalizedId];
      while (pending.isNotEmpty) {
        final current = pending.removeLast();
        for (final child in childrenByParent[current] ?? const <String>[]) {
          if (descendants.add(child)) pending.add(child);
        }
      }
      if (descendants.contains(normalizedParent)) {
        throw StateError('لا يمكن نقل الحساب أسفل أحد الحسابات التابعة له.');
      }
    }

    if (isPostable) {
      final children = await client
          .from('erp_accounts')
          .select('id')
          .eq('company_id', normalizedCompany)
          .eq('parent_id', normalizedId)
          .limit(1);
      if (children.isNotEmpty) {
        throw StateError('لا يمكن تحويل حساب له حسابات فرعية إلى حساب تحليلي.');
      }
    }

    final updated = await client.from('erp_accounts').update({
      'account_code': normalizedCode,
      'account_name': normalizedName,
      'account_type': accountType,
      'normal_balance': normalBalance,
      'parent_id': normalizedParent,
      'is_postable': isPostable,
      'is_active': isActive,
    }).eq('company_id', normalizedCompany).eq('id', normalizedId).select().single();
    return Map<String, dynamic>.from(updated);
  }

  Future<void> deactivateAccount({
    required String companyId,
    required String accountId,
  }) async {
    if (companyId.trim().isEmpty || accountId.trim().isEmpty) {
      throw ArgumentError('معرّف الشركة والحساب مطلوبان.');
    }
    await _requireClient
        .from('erp_accounts')
        .update({'is_active': false})
        .eq('company_id', companyId.trim())
        .eq('id', accountId.trim());
  }

  static String? _normalizeParent(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  static void _validateTypeAndBalance(String type, String balance) {
    const types = {'asset', 'liability', 'equity', 'revenue', 'expense'};
    if (!types.contains(type)) throw ArgumentError('نوع الحساب غير صحيح.');
    if (!{'debit', 'credit'}.contains(balance)) {
      throw ArgumentError('طبيعة الرصيد يجب أن تكون مدينًا أو دائنًا.');
    }
  }

  static Future<void> _validateParent(
    SupabaseClient client, {
    required String companyId,
    required String? parentId,
  }) async {
    if (parentId == null) return;
    final parent = await client
        .from('erp_accounts')
        .select('id, company_id, is_postable')
        .eq('id', parentId)
        .eq('company_id', companyId)
        .maybeSingle();
    if (parent == null) {
      throw StateError('الحساب الأب غير موجود داخل الشركة المحددة.');
    }
    if (parent['is_postable'] == true) {
      throw StateError('لا يمكن وضع حساب فرعي تحت حساب تحليلي قابل للترحيل.');
    }
  }
}
