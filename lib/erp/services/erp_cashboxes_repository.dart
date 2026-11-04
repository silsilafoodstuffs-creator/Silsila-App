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
      .select('id, cashbox_code, cashbox_name, cashbox_name_en, branch_id, account_id, is_bank_account, bank_name, account_number_masked, is_active, checkbook_sheet_count')
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
    required String companyId, required String code, required String name, required String nameEn,
    required String accountId, String? branchId, required bool isBank,
    String? bankName, String? accountNumberMasked, int checkbookSheetCount = 50,
  }) async {
    if (name.trim().isEmpty || nameEn.trim().isEmpty || accountId.isEmpty) {
      throw ArgumentError('اسما الخزينة العربي والإنجليزي وحساب الأستاذ حقول مطلوبة.');
    }
    if (isBank && (checkbookSheetCount < 1 || checkbookSheetCount > 1000)) {
      throw ArgumentError('عدد أوراق دفتر الشيكات يجب أن يكون بين 1 و1000.');
    }
    final masked = _blank(accountNumberMasked);
    if (masked != null && !RegExp(r'^\d{4}$').hasMatch(masked)) {
      throw ArgumentError('أدخل آخر أربعة أرقام فقط من الحساب البنكي.');
    }
    await _db.from('erp_cashboxes').insert({
      'company_id': companyId.trim(), 'cashbox_code': '', 'cashbox_name': name.trim(), 'cashbox_name_en': nameEn.trim(),
      'account_id': accountId, 'branch_id': branchId, 'is_bank_account': isBank,
      'bank_name': _blank(bankName), 'account_number_masked': masked,
      'is_active': true,
      'checkbook_sheet_count': isBank ? checkbookSheetCount : 50,
    });
  }

  Future<void> updateCheckbookSheetCount(String id, int count) async {
    if (count < 1 || count > 1000) throw ArgumentError('عدد أوراق دفتر الشيكات يجب أن يكون بين 1 و1000.');
    await _db.from('erp_cashboxes').update({'checkbook_sheet_count': count}).eq('id', id).eq('is_bank_account', true);
  }

  Future<void> setActive(String id, bool active) async {
    await _db.from('erp_cashboxes').update({'is_active': active}).eq('id', id);
  }

  Future<void> setBranch(String id, String? branchId) async {
    await _db.from('erp_cashboxes').update({'branch_id': branchId}).eq('id', id);
  }
  static String? _blank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
