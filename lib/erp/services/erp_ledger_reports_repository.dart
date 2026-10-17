import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only financial reports. All figures are sourced from posted journal entries.
class ErpLedgerReportsRepository {
  ErpLedgerReportsRepository({SupabaseClient? client})
      : _client = client ?? _tryClient();

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
      throw StateError('Supabase غير مهيأ؛ تعذر تحميل التقارير المالية.');
    }
    return client;
  }

  Future<List<Map<String, dynamic>>> fetchTrialBalance({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _validate(companyId, startDate, endDate);
    final rows = await _db.rpc('erp_get_trial_balance', params: {
      'p_company_id': companyId.trim(),
      'p_start_date': startDate == null ? null : _dateOnly(startDate),
      'p_end_date': endDate == null ? null : _dateOnly(endDate),
    });
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchGeneralLedger({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
    int limit = 1000,
  }) async {
    _validate(companyId, startDate, endDate);
    var query = _db
        .from('erp_general_ledger')
        .select()
        .eq('company_id', companyId.trim());
    if (startDate != null) query = query.gte('entry_date', _dateOnly(startDate));
    if (endDate != null) query = query.lte('entry_date', _dateOnly(endDate));
    if (accountId != null && accountId.trim().isNotEmpty) {
      query = query.eq('account_id', accountId.trim());
    }
    final rows = await query
        .order('entry_date', ascending: true)
        .order('entry_number', ascending: true)
        .limit(limit);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static void _validate(String companyId, DateTime? start, DateTime? end) {
    if (companyId.trim().isEmpty) throw ArgumentError('معرّف الشركة مطلوب.');
    if (start != null && end != null && start.isAfter(end)) {
      throw ArgumentError('تاريخ البداية يجب ألا يتجاوز تاريخ النهاية.');
    }
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
