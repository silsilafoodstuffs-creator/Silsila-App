import 'package:supabase_flutter/supabase_flutter.dart';

/// Company-scoped access to ERP audit records.
/// RLS and trusted server-side authorization remain mandatory.
class ErpAuditService {
  ErpAuditService({SupabaseClient? client}) : _client = client ?? _tryClient();

  final SupabaseClient? _client;

  static SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _db {
    final value = _client;
    if (value == null) throw StateError('Supabase غير مهيأ.');
    if (value.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول قبل الوصول إلى سجل الحركات.');
    }
    return value;
  }

  String? get userId => _client?.auth.currentUser?.id;

  void _check(String value, String message) {
    if (value.trim().isEmpty) throw ArgumentError(message);
  }

  Future<List<Map<String, dynamic>>> listMovementAudit({
    required String companyId,
    DateTime? from,
    DateTime? to,
    String? area,
    int limit = 100,
  }) async {
    _check(companyId, 'معرّف الشركة مطلوب.');
    if (limit < 1 || limit > 500) throw ArgumentError('الحد من 1 إلى 500.');
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('تاريخ البداية يتجاوز تاريخ النهاية.');
    }
    var request = _db.from('erp_movement_audit').select().eq('company_id', companyId);
    if (from != null) request = request.gte('created_at', from.toUtc().toIso8601String());
    if (to != null) request = request.lte('created_at', to.toUtc().toIso8601String());
    if (area != null && area.trim().isNotEmpty) request = request.eq('area_key', area.trim());
    final result = await request.order('created_at', ascending: false).limit(limit);
    return (result as List).whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<String> addMovementAudit({
    required String companyId,
    required String area,
    required String action,
    required String entityType,
    String? entityId,
    String? reference,
    String? description,
    Map<String, dynamic> details = const {},
  }) async {
    _check(companyId, 'معرّف الشركة مطلوب.');
    _check(area, 'مجال الحركة مطلوب.');
    _check(action, 'نوع العملية مطلوب.');
    _check(entityType, 'نوع السجل مطلوب.');
    final row = await _db.from('erp_movement_audit').insert({
      'company_id': companyId,
      'area_key': area.trim(),
      'action_key': action.trim(),
      'entity_type': entityType.trim(),
      'entity_id': entityId,
      'reference_code': reference,
      'description': description,
      'details': details,
      'actor_user_id': userId,
    }).select('id').single();
    return row['id'].toString();
  }
}
