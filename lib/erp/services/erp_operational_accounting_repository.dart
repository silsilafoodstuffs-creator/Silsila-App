import 'package:supabase_flutter/supabase_flutter.dart';

class ErpOperationalAccountingRepository {
  ErpOperationalAccountingRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول إلى خريطة الحسابات التشغيلية.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchAccounts(String companyId) async {
    final rows = await _db.from('erp_accounts')
      .select('id, account_code, account_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).eq('is_postable', true)
      .order('account_code').limit(3000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, dynamic>?> fetchMapping(String companyId) async {
    final row = await _db.from('erp_operational_account_mappings').select()
      .eq('company_id', companyId.trim()).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> saveMapping({
    required String companyId,
    required Map<String, String?> accountIds,
  }) async {
    if (companyId.trim().isEmpty) throw ArgumentError('معرّف الشركة مطلوب.');
    const requiredKeys = [
      'accounts_receivable_account_id','accounts_payable_account_id',
      'sales_revenue_account_id','sales_returns_account_id','inventory_account_id',
      'cost_of_goods_sold_account_id','purchase_return_variance_account_id',
    ];
    for (final key in requiredKeys) {
      if ((accountIds[key] ?? '').isEmpty) throw ArgumentError('أكمل جميع الحسابات الأساسية.');
    }
    await _db.from('erp_operational_account_mappings').upsert({
      'company_id': companyId.trim(),
      ...accountIds,
      'created_by': _db.auth.currentUser?.id,
    }, onConflict: 'company_id');
  }

  Future<String> postDocumentAccounting(String documentId, String kind) async {
    final result = await _db.rpc('erp_post_operational_document_accounting', params: {
      'p_document_id': documentId, 'p_kind': kind,
    });
    return result.toString();
  }
}
