import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for the ERP chart of accounts.
/// A company id is always required; authorization is still enforced by Supabase RLS.
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
    return client;
  }

  /// Reads account nodes with their posted-ledger metrics.
  /// Returns an empty list when the company has no accounts.
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
        .eq('company_id', companyId);
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('account_code');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Creates a node in the selected company. Parent and postable rules are
  /// checked server-side too; this client check is only early feedback.
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
    if (companyId.trim().isEmpty ||
        normalizedCode.isEmpty ||
        normalizedName.isEmpty) {
      throw ArgumentError('الشركة وكود الحساب واسم الحساب حقول إلزامية.');
    }
    const types = {'asset', 'liability', 'equity', 'revenue', 'expense'};
    if (!types.contains(accountType)) {
      throw ArgumentError('نوع الحساب غير صحيح.');
    }
    if (!{'debit', 'credit'}.contains(normalBalance)) {
      throw ArgumentError('طبيعة الرصيد يجب أن تكون مدينًا أو دائنًا.');
    }
    if (parentId != null && parentId.trim().isEmpty) parentId = null;

    final client = _requireClient;
    if (parentId != null) {
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
        throw StateError('لا يمكن إضافة حساب فرعي تحت حساب تحليلي قابل للترحيل.');
      }
    }

    final inserted = await client
        .from('erp_accounts')
        .insert({
          'company_id': companyId,
          'account_code': normalizedCode,
          'account_name': normalizedName,
          'account_type': accountType,
          'normal_balance': normalBalance,
          'parent_id': parentId,
          'is_postable': isPostable,
          'is_active': true,
        })
        .select()
        .single();
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
  }) async {
    if (companyId.trim().isEmpty || accountId.trim().isEmpty) {
      throw ArgumentError('معرّف الشركة والحساب مطلوبان.');
    }
    const types = {'asset', 'liability', 'equity', 'revenue', 'expense'};
    if (!types.contains(accountType) ||
        !{'debit', 'credit'}.contains(normalBalance)) {
      throw ArgumentError('نوع الحساب أو طبيعة الرصيد غير صحيح.');
    }
    final client = _requireClient;
    if (isPostable) {
      final children = await client
          .from('erp_accounts')
          .select('id')
          .eq('company_id', companyId)
          .eq('parent_id', accountId)
          .limit(1);
      if (children.isNotEmpty) {
        throw StateError('لا يمكن تحويل حساب له حسابات فرعية إلى حساب تحليلي.');
      }
    }
    final updated = await client
        .from('erp_accounts')
        .update({
          'account_code': code.trim(),
          'account_name': name.trim(),
          'account_type': accountType,
          'normal_balance': normalBalance,
          'is_postable': isPostable,
          'is_active': isActive,
        })
        .eq('company_id', companyId)
        .eq('id', accountId)
        .select()
        .single();
    return Map<String, dynamic>.from(updated);
  }

  /// Deactivates instead of deleting, preserving references from journal lines.
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
        .eq('company_id', companyId)
        .eq('id', accountId);
  }
}
