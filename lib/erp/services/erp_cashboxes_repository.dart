import 'package:supabase_flutter/supabase_flutter.dart';

class ErpCashboxesRepository {
  ErpCashboxesRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول للخزائن والبنوك.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchCashboxes(String companyId) async {
    final rows = await _db.from('erp_cashboxes')
      .select('id, cashbox_code, cashbox_name, branch_id, account_id, is_bank_account, bank_name, account_number_masked, is_active')
      .eq('company_id', companyId.trim()).order('cashbox_code');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<List<Map<String, dynamic>>> fetchAccounts(String companyId) async {
    final rows = await _db.from('erp_accounts')
      .select('id, account_code, account_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).eq('is_postable', true)
      .order('account_code').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
  Future<List<Map<String, dynamic>>> fetchBranches(String companyId) async {
    final rows = await _db.from('erp_branches')
      .select('id, branch_code, branch_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('branch_code');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createCashbox({
    required String companyId, required String code, required String name,
    required String accountId, String? branchId, required bool isBank,
    String? bankName, String? accountNumberMasked,
  }) async {
    if (code.trim().isEmpty || name.trim().isEmpty || accountId.isEmpty) {
      throw ArgumentError('كود الخزينة واسمها وحساب الأستاذ حقول مطلوبة.');
    }
    await _db.from('erp_cashboxes').insert({
      'company_id': companyId.trim(), 'cashbox_code': code.trim(), 'cashbox_name': name.trim(),
      'account_id': accountId, 'branch_id': branchId, 'is_bank_account': isBank,
      'bank_name': _blank(bankName), 'account_number_masked': _blank(accountNumberMasked),
      'is_active': true,
    });
  }

  Future<void> setActive(String id, bool active) async {
    await _db.from('erp_cashboxes').update({'is_active': active}).eq('id', id);
  }
  static String? _blank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
