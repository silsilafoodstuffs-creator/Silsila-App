import 'package:supabase_flutter/supabase_flutter.dart';

/// Tenant-scoped persistence for configurable ERP workspace records.
/// Domain-specific financial documents should continue using their dedicated repositories.
class ErpWorkspaceRecordsService {
  ErpWorkspaceRecordsService({SupabaseClient? client}) : _client = client ?? _defaultClient;

  final SupabaseClient? _client;

  static SupabaseClient? get _defaultClient {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  SupabaseClient get _db {
    final value = _client;
    if (value == null) throw StateError('Supabase غير مهيأ.');
    if (value.auth.currentUser == null) throw StateError('يجب تسجيل الدخول قبل حفظ بيانات البرنامج.');
    return value;
  }

  Future<List<Map<String, String>>> listPage({
    required String companyId,
    required String pageKey,
  }) async {
    _validate(companyId, pageKey);
    final rows = await _db.from('erp_workspace_records')
        .select('record_key, record_data')
        .eq('company_id', companyId)
        .eq('page_key', pageKey)
        .order('created_at');
    return (rows as List).whereType<Map<String, dynamic>>().map((row) {
      final payload = row['record_data'];
      final result = <String, String>{};
      if (payload is Map) {
        payload.forEach((key, value) {
          if (key.toString() != '_record_key') result[key.toString()] = value?.toString() ?? '';
        });
      }
      // Keep the stable database key even when a record has no visible fields;
      // otherwise the UI cannot reliably edit or delete an otherwise valid empty record.
      result['_مرجع داخلي'] = row['record_key']?.toString() ?? '';
      return result;
    }).toList(growable: true);
  }

  Future<void> saveRecord({
    required String companyId,
    required String pageKey,
    required Map<String, String> record,
  }) async {
    _validate(companyId, pageKey);
    final clean = Map<String, String>.from(record)..remove('_مرجع داخلي');
    final key = (record['_مرجع داخلي']?.trim().isNotEmpty == true)
        ? record['_مرجع داخلي']!.trim()
        : _recordKey(clean);
    await _db.from('erp_workspace_records').upsert({
      'company_id': companyId,
      'page_key': pageKey,
      'record_key': key,
      'record_data': clean,
      'updated_by': _db.auth.currentUser!.id,
    }, onConflict: 'company_id,page_key,record_key');
  }

  Future<void> deleteRecord({
    required String companyId,
    required String pageKey,
    required String recordKey,
  }) async {
    _validate(companyId, pageKey);
    await _db.from('erp_workspace_records').delete()
        .eq('company_id', companyId).eq('page_key', pageKey).eq('record_key', recordKey);
  }

  static String _recordKey(Map<String, String> row) {
    final preferred = row['الكود'] ?? row['الرقم'] ?? row['رقم المستند'] ?? row['رقم الحساب'] ?? row['الاسم'] ?? row['اسم الحساب'];
    final value = (preferred ?? (row.values.isEmpty ? '' : row.values.first)).trim();
    if (value.isEmpty) throw ArgumentError('يجب إدخال كود أو اسم للسجل قبل الحفظ.');
    return value;
  }

  static void _validate(String companyId, String pageKey) {
    if (companyId.trim().isEmpty) throw ArgumentError('لا توجد شركة مرتبطة بالمستخدم الحالي.');
    if (pageKey.trim().isEmpty || pageKey.length > 120) throw ArgumentError('اسم الشاشة غير صالح.');
  }
}
