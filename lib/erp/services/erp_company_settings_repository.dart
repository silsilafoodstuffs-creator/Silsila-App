import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists company-scoped ERP workspace configuration in Supabase.
/// These settings are configuration records, not a substitute for enforcing
/// financial/inventory restrictions inside trusted posting RPCs.
class ErpCompanySettingsRepository {
  ErpCompanySettingsRepository({SupabaseClient? client})
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
      throw StateError('Supabase غير مهيأ؛ تعذر حفظ إعدادات البرنامج.');
    }
    return client;
  }

  String? get _userId => _client?.auth.currentUser?.id;

  Future<Map<String, dynamic>?> getSetting({
    required String companyId,
    required String key,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    _require(key, 'مفتاح الإعداد مطلوب.');
    final row = await _db
        .from('erp_company_settings')
        .select('setting_value')
        .eq('company_id', companyId.trim())
        .eq('setting_key', key.trim())
        .maybeSingle();
    if (row == null || row['setting_value'] is! Map) return null;
    return Map<String, dynamic>.from(row['setting_value'] as Map);
  }

  Future<void> saveSetting({
    required String companyId,
    required String key,
    required Map<String, Object?> value,
  }) async {
    _require(companyId, 'معرّف الشركة مطلوب.');
    _require(key, 'مفتاح الإعداد مطلوب.');
    if (key.trim().length > 120) {
      throw ArgumentError('مفتاح الإعداد أطول من المسموح.');
    }
    await _db.from('erp_company_settings').upsert(
      {
        'company_id': companyId.trim(),
        'setting_key': key.trim(),
        'setting_value': value,
        'updated_by': _userId,
      },
      onConflict: 'company_id,setting_key',
    );
  }

  static void _require(String value, String message) {
    if (value.trim().isEmpty) throw ArgumentError(message);
  }
}
