import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only integrity audit against ERP records actually present in Supabase.
class ErpMovementAuditRepository {
  ErpMovementAuditRepository({SupabaseClient? client})
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
      throw StateError('Supabase غير مهيأ؛ لا يمكن تشغيل فحص الحركات.');
    }
    return client;
  }

  Future<List<Map<String, dynamic>>> runAudit({
    required String companyId,
    required String area,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (companyId.trim().isEmpty) throw ArgumentError('معرّف الشركة مطلوب.');
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw ArgumentError('تاريخ البداية يجب ألا يتجاوز تاريخ النهاية.');
    }
    final result = await _db.rpc('erp_run_movement_audit', params: {
      'p_company_id': companyId.trim(),
      'p_start_date': startDate == null ? null : _dateOnly(startDate),
      'p_end_date': endDate == null ? null : _dateOnly(endDate),
      'p_area': area,
    });
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
