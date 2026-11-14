import 'package:supabase_flutter/supabase_flutter.dart';
import 'studio_document.dart';

/// Supabase persistence for Studio metadata. RLS and RPC role checks are authoritative.
class ErpStudioRepository {
  ErpStudioRepository({SupabaseClient? client}) : _providedClient = client;
  final SupabaseClient? _providedClient;
  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  void _requireCompany(String companyId) {
    if (companyId.trim().isEmpty) throw ArgumentError('معرّف الشركة مطلوب.');
    if (_client.auth.currentUser == null) throw StateError('يجب تسجيل الدخول أولاً.');
  }

  Future<List<Map<String, dynamic>>> listDesigns(String companyId) async {
    _requireCompany(companyId);
    final rows = await _client.from('erp_studio_designs')
        .select('id,design_key,name,design_kind,status,schema_version,revision,published_revision,updated_at')
        .eq('company_id', companyId)
        .order('updated_at', ascending: false)
        .limit(200);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  Future<Map<String, dynamic>> getDesign({required String companyId, required String designId}) async {
    _requireCompany(companyId);
    final row = await _client.from('erp_studio_designs').select('*')
        .eq('company_id', companyId).eq('id', designId).single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> listVersions({
    required String companyId,
    required String designId,
  }) async {
    _requireCompany(companyId);
    final rows = await _client.from('erp_studio_design_versions')
        .select('id,revision,change_note,created_by,created_at,design_json,binding_json')
        .eq('company_id', companyId)
        .eq('design_id', designId)
        .order('revision', ascending: false)
        .limit(100);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  Future<String> saveDraft({
    required String companyId,
    required StudioDocument document,
    required String designKey,
    String? remoteId,
    int? expectedRevision,
    String changeNote = 'حفظ من Silsila Studio',
  }) async {
    _requireCompany(companyId);
    final result = await _client.rpc('erp_studio_save_draft', params: {
      'p_company_id': companyId,
      'p_design_id': remoteId,
      'p_design_key': designKey,
      'p_name': document.name,
      'p_design_kind': 'screen',
      'p_schema_version': document.schemaVersion,
      'p_design_json': document.toJson(),
      'p_binding_json': {'mode': 'unbound', 'sources': []},
      'p_expected_revision': expectedRevision,
      'p_change_note': changeNote,
    });
    if (result is! String || result.isEmpty) throw StateError('لم يُرجع الخادم معرّف التصميم.');
    return result;
  }

  Future<void> approve({
    required String companyId,
    required String designId,
    required int expectedRevision,
  }) async {
    _requireCompany(companyId);
    await _client.rpc('erp_studio_approve_design', params: {
      'p_company_id': companyId,
      'p_design_id': designId,
      'p_expected_revision': expectedRevision,
    });
  }

  Future<void> publish({
    required String companyId,
    required String designId,
    required int testedRevision,
  }) async {
    _requireCompany(companyId);
    await _client.rpc('erp_studio_publish_design', params: {
      'p_company_id': companyId,
      'p_design_id': designId,
      'p_tested_revision': testedRevision,
    });
  }

  Future<int> restoreVersion({
    required String companyId,
    required String designId,
    required int targetRevision,
    required int expectedRevision,
  }) async {
    _requireCompany(companyId);
    final result = await _client.rpc('erp_studio_restore_version', params: {
      'p_company_id': companyId,
      'p_design_id': designId,
      'p_target_revision': targetRevision,
      'p_expected_revision': expectedRevision,
    });
    if (result is! int) throw StateError('تعذر استعادة الإصدار.');
    return result;
  }
}
