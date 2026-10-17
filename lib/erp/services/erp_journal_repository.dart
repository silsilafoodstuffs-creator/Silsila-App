import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase access for journal drafts and posting.
/// Database RLS and the SQL workflow functions remain the security boundary.
class ErpJournalRepository {
  ErpJournalRepository({SupabaseClient? client}) : _client = client ?? _tryClient();

  final SupabaseClient? _client;

  static SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _db {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase غير مهيأ؛ تعذر الوصول إلى القيود اليومية.');
    }
    return client;
  }

  Future<List<Map<String, dynamic>>> fetchEntries({
    required String companyId,
    int limit = 100,
  }) async {
    if (companyId.trim().isEmpty) {
      throw ArgumentError('معرّف الشركة مطلوب.');
    }
    final rows = await _db
        .from('erp_journal_entries')
        .select('id, company_id, entry_number, entry_date, description, status, source_type, posted_at, created_at')
        .eq('company_id', companyId.trim())
        .order('entry_date', ascending: false)
        .order('entry_number', ascending: false)
        .limit(limit);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchEntryLines({
    required String entryId,
  }) async {
    if (entryId.trim().isEmpty) throw ArgumentError('معرّف القيد مطلوب.');
    final rows = await _db
        .from('erp_journal_lines')
        .select('id, entry_id, account_id, description, debit, credit, erp_accounts(account_code, account_name)')
        .eq('entry_id', entryId.trim())
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPostableAccounts({
    required String companyId,
  }) async {
    final rows = await _db
        .from('erp_accounts')
        .select('id, account_code, account_name')
        .eq('company_id', companyId.trim())
        .eq('is_active', true)
        .eq('is_postable', true)
        .order('account_code');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<String> saveDraft({
    required String companyId,
    required DateTime entryDate,
    required String description,
    required List<Map<String, dynamic>> lines,
    String? entryId,
  }) async {
    if (companyId.trim().isEmpty) throw ArgumentError('معرّف الشركة مطلوب.');
    if (description.trim().isEmpty) throw ArgumentError('بيان القيد مطلوب.');
    if (lines.length < 2) throw ArgumentError('يجب إدخال سطرين على الأقل.');
    final payload = lines.map((line) => <String, dynamic>{
      'account_id': line['account_id'],
      'description': (line['description'] ?? '').toString().trim(),
      'debit': _money(line['debit']),
      'credit': _money(line['credit']),
    }).toList();
    final result = await _db.rpc('erp_save_journal_draft', params: {
      'p_company_id': companyId.trim(),
      'p_entry_date': _dateOnly(entryDate),
      'p_description': description.trim(),
      'p_lines': payload,
      'p_entry_id': entryId,
    });
    return result.toString();
  }

  Future<String> reverseEntry({
    required String entryId,
    required DateTime reversalDate,
    required String reason,
  }) async {
    if (entryId.trim().isEmpty) throw ArgumentError('معرّف القيد مطلوب.');
    if (reason.trim().isEmpty) throw ArgumentError('سبب العكس مطلوب.');
    final result = await _db.rpc('erp_reverse_journal_entry', params: {
      'p_entry_id': entryId.trim(),
      'p_reversal_date': _dateOnly(reversalDate),
      'p_reason': reason.trim(),
    });
    return result.toString();
  }

  Future<String> postEntry(String entryId) async {
    final result = await _db.rpc(
      'erp_post_journal_entry',
      params: {'p_entry_id': entryId},
    );
    return result.toString();
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static double _money(dynamic value) {
    if (value is num) return double.parse(value.toStringAsFixed(2));
    return double.tryParse((value ?? '0').toString().trim()) ?? 0;
  }
}
