import 'package:supabase_flutter/supabase_flutter.dart';

class ErpFiscalPeriodRepository {
  ErpFiscalPeriodRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول للفترات المالية.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchPeriods(String companyId) async {
    final rows = await _db.from('erp_fiscal_periods')
      .select('id, company_id, period_name, starts_on, ends_on, status')
      .eq('company_id', companyId.trim()).order('starts_on', ascending: false);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createPeriod({
    required String companyId,
    required String name,
    required DateTime start,
    required DateTime end,
  }) async {
    if (name.trim().isEmpty || start.isAfter(end)) {
      throw ArgumentError('راجع اسم الفترة وتاريخ البداية والنهاية.');
    }
    await _db.from('erp_fiscal_periods').insert({
      'company_id': companyId.trim(),
      'period_name': name.trim(),
      'starts_on': _dateOnly(start),
      'ends_on': _dateOnly(end),
      'status': 'open',
    });
  }

  Future<void> closePeriod(String id) async {
    await _db.from('erp_fiscal_periods').update({'status': 'closed'}).eq('id', id).eq('status', 'open');
  }

  static String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
}
