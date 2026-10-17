import 'package:supabase_flutter/supabase_flutter.dart';

class ErpCashVouchersRepository {
  ErpCashVouchersRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول إلى سندات الخزائن.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchCashboxes(String companyId) async {
    final rows = await _db.from('erp_cashboxes')
      .select('id, cashbox_code, cashbox_name, account_id, is_bank_account')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('cashbox_name');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAccounts(String companyId) async {
    final rows = await _db.from('erp_accounts')
      .select('id, account_code, account_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).eq('is_postable', true)
      .order('account_code').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchParties(String companyId) async {
    final rows = await _db.from('erp_parties')
      .select('id, party_code, party_name, party_kind')
      .eq('company_id', companyId.trim()).eq('is_active', true)
      .order('party_name').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchVouchers(String companyId) async {
    final rows = await _db.from('erp_cash_vouchers')
      .select('id, voucher_number, voucher_date, voucher_type, source_cashbox_id, destination_cashbox_id, counter_account_id, party_id, amount, description, status, journal_entry_id')
      .eq('company_id', companyId.trim()).order('voucher_date', ascending: false).limit(300);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createDraft({
    required String companyId,
    required String voucherNumber,
    required String voucherType,
    required String sourceCashboxId,
    String? destinationCashboxId,
    String? counterAccountId,
    String? partyId,
    required double amount,
    required String description,
  }) async {
    if (companyId.trim().isEmpty || voucherNumber.trim().isEmpty ||
        sourceCashboxId.isEmpty || description.trim().isEmpty || amount <= 0) {
      throw ArgumentError('أكمل الشركة ورقم السند والخزينة والقيمة والبيان.');
    }
    await _db.from('erp_cash_vouchers').insert({
      'company_id': companyId.trim(),
      'created_by': _db.auth.currentUser?.id,
      'voucher_number': voucherNumber.trim(),
      'voucher_date': DateTime.now().toIso8601String().substring(0, 10),
      'voucher_type': voucherType,
      'source_cashbox_id': sourceCashboxId,
      'destination_cashbox_id': voucherType == 'transfer' ? destinationCashboxId : null,
      'counter_account_id': voucherType == 'transfer' ? null : counterAccountId,
      'party_id': voucherType == 'transfer' ? null : partyId,
      'amount': amount,
      'description': description.trim(),
      'status': 'draft',
    });
  }

  Future<void> postVoucher(String voucherId) async {
    await _db.rpc('erp_post_cash_voucher', params: {'p_voucher_id': voucherId});
  }
}
