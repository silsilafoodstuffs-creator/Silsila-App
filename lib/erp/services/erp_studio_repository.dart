import 'package:supabase_flutter/supabase_flutter.dart';
import 'studio_data_sources.dart';
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

  Future<Map<String, dynamic>> getDesign({
    required String companyId,
    required String designId,
  }) async {
    _requireCompany(companyId);
    final row = await _client.from('erp_studio_designs')
        .select('id,design_key,name,design_kind,status,schema_version,revision,published_revision,design_json,binding_json,updated_at')
        .eq('company_id', companyId)
        .eq('id', designId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> listVersions({
    required String companyId,
    required String designId,
  }) async {
    _requireCompany(companyId);
    final rows = await _client.from('erp_studio_design_versions')
        .select('id,revision,change_note,created_by,created_at')
        .eq('company_id', companyId)
        .eq('design_id', designId)
        .order('revision', ascending: false)
        .limit(100);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  Future<Map<String, dynamic>> getVersion({
    required String companyId,
    required String designId,
    required int revision,
  }) async {
    _requireCompany(companyId);
    final row = await _client.from('erp_studio_design_versions')
        .select('revision,design_json,binding_json,change_note,created_at')
        .eq('company_id', companyId)
        .eq('design_id', designId)
        .eq('revision', revision)
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> previewSource({
    required String companyId,
    required String sourceKey,
    int limit = 50,
  }) async {
    _requireCompany(companyId);
    final source = StudioDataSources.byKey(sourceKey);
    final safeLimit = limit.clamp(1, 100);
    var request = _client.from(source.table).select(source.select).eq('company_id', companyId);
    if (source.excludeDemo) {
      request = request.eq('is_demo_data', false);
    }
    final rows = await request.limit(safeLimit);
    return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList(growable: false);
  }

  Future<Map<String, List<Map<String, dynamic>>>> previewBindings({
    required String companyId,
    required StudioDocument document,
    int limit = 50,
  }) async {
    final keys = <String>{};
    for (final node in document.nodes) {
      final binding = node.props['binding'];
      if (binding is Map && binding['source'] is String) {
        keys.add(binding['source'] as String);
      }
    }
    final result = <String, List<Map<String, dynamic>>>{};
    for (final key in keys) {
      result[key] = await previewSource(companyId: companyId, sourceKey: key, limit: limit);
    }
    return result;
  }


  Future<Map<String, Map<String, dynamic>>> loadLayoutProfiles(String companyId) async {
    _requireCompany(companyId);
    final rows = await _client.from('erp_studio_layout_profiles')
        .select('profile_key,profile_json')
        .eq('company_id', companyId)
        .limit(100);
    final result = <String, Map<String, dynamic>>{};
    for (final row in rows as List) {
      final data = Map<String, dynamic>.from(row as Map);
      final raw = data['profile_json'];
      if (raw is Map) {
        result[data['profile_key'].toString()] = Map<String, dynamic>.from(raw);
      }
    }
    return result;
  }

  Future<void> saveLayoutProfile({
    required String companyId,
    required String profileKey,
    required Map<String, dynamic> profile,
  }) async {
    _requireCompany(companyId);
    final userId = _client.auth.currentUser!.id;
    await _client.from('erp_studio_layout_profiles').upsert({
      'company_id': companyId,
      'profile_key': profileKey,
      'profile_json': profile,
      'updated_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'company_id,profile_key');
  }

  Future<void> deleteLayoutProfile({
    required String companyId,
    required String profileKey,
  }) async {
    _requireCompany(companyId);
    await _client.from('erp_studio_layout_profiles')
        .delete()
        .eq('company_id', companyId)
        .eq('profile_key', profileKey);
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
      'p_design_kind': document.designKind,
      'p_schema_version': document.schemaVersion,
      'p_design_json': document.toJson(),
      'p_binding_json': {
        'mode': document.bindings.isEmpty ? 'unbound' : 'allowlisted',
        'bindings': document.bindings,
      },
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
