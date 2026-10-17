import 'package:supabase_flutter/supabase_flutter.dart';

import 'erp_app_settings.dart';

/// Supabase persistence adapter for ERP app-management metadata.
///
/// Before use, apply the matching SQL migration and configure restrictive,
/// company-scoped RLS policies. This client service is not an authorization
/// boundary: all privileged operations must be protected by server-side policy.
class ErpAppManagementService {
  ErpAppManagementService({SupabaseClient? client}) : _client = client ?? _defaultClient;

  final SupabaseClient? _client;

  static SupabaseClient? get _defaultClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _db {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase غير مهيأ. قم بتهيئته قبل استخدام إدارة التطبيقات.');
    }
    return client;
  }

  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Lists applications for one company. RLS must independently enforce access.
  Future<List<ErpManagedApp>> listApps({required String companyId}) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    final rows = await _db
        .from('erp_managed_apps')
        .select('id, app_key, display_name, description, status, package_name, web_url')
        .eq('company_id', companyId)
        .order('display_name');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => ErpManagedApp(
              id: row['id']?.toString() ?? '',
              name: row['display_name']?.toString() ?? '',
              status: _statusFromDb(row['status']?.toString()),
              description: row['description']?.toString(),
              packageName: row['package_name']?.toString(),
              webUrl: row['web_url']?.toString(),
            ))
        .toList(growable: false);
  }

  Future<ErpAppThemeSettings?> getThemeSettings({required String appId}) async {
    _requireId(appId, 'معرّف التطبيق مطلوب.');
    final row = await _db
        .from('erp_app_theme_settings')
        .select()
        .eq('app_id', appId)
        .maybeSingle();
    if (row == null) return null;
    return ErpAppThemeSettings(
      appId: row['app_id']?.toString() ?? appId,
      displayName: row['display_name']?.toString() ?? '',
      primaryColor: row['primary_color']?.toString() ?? '#3E007D',
      accentColor: row['accent_color']?.toString() ?? '#FFA015',
      logoPath: row['logo_path']?.toString(),
      splashImagePath: row['splash_image_path']?.toString(),
      iconPath: row['icon_path']?.toString(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      updatedBy: row['updated_by']?.toString(),
    );
  }

  Future<void> saveThemeSettings(ErpAppThemeSettings settings) async {
    final errors = settings.validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join('\n'));
    final payload = settings.toJson()
      ..remove('updated_at')
      ..remove('updated_by')
      ..['updated_by'] = currentUserId;
    await _db.from('erp_app_theme_settings').upsert(
          payload,
          onConflict: 'app_id',
        );
  }

  Future<List<ErpAppAssetRecord>> listAssets({
    required String appId,
    String? assetType,
    int limit = 100,
  }) async {
    _requireId(appId, 'معرّف التطبيق مطلوب.');
    if (assetType != null && !_validAssetTypes.contains(assetType)) {
      throw ArgumentError('نوع الملف غير مدعوم.');
    }
    final safeLimit = limit.clamp(1, 500);
    var query = _db.from('erp_app_assets').select().eq('app_id', appId);
    if (assetType != null) query = query.eq('asset_type', assetType);
    final rows = await query.order('created_at', ascending: false).limit(safeLimit);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => ErpAppAssetRecord(
              appId: row['app_id']?.toString() ?? '',
              assetType: row['asset_type']?.toString() ?? 'other',
              storagePath: row['storage_path']?.toString() ?? '',
              displayName: row['display_name']?.toString() ?? '',
              entityId: row['entity_id']?.toString(),
              mimeType: row['mime_type']?.toString(),
              fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt(),
              altText: row['alt_text']?.toString(),
            ))
        .toList(growable: false);
  }

  /// Registers metadata for a file already uploaded to an appropriately
  /// configured private Storage bucket. This method does not upload file bytes.
  Future<String> registerAsset(ErpAppAssetRecord asset) async {
    final errors = asset.validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join('\n'));
    if (!_validAssetTypes.contains(asset.assetType)) {
      throw ArgumentError('نوع الملف غير مدعوم.');
    }
    final payload = asset.toJson()
      ..['uploaded_by'] = currentUserId;
    final row = await _db
        .from('erp_app_assets')
        .insert(payload)
        .select('id')
        .single();
    return row['id'].toString();
  }

  /// Deletes metadata only. Storage deletion is intentionally separate so
  /// accidental database changes cannot silently remove the underlying file.
  Future<void> deleteAssetRecord({required String assetId}) async {
    _requireId(assetId, 'معرّف الملف مطلوب.');
    await _db.from('erp_app_assets').delete().eq('id', assetId);
  }

  Future<List<ErpAppPermission>> listPermissions({required String appId}) async {
    _requireId(appId, 'معرّف التطبيق مطلوب.');
    final rows = await _db
        .from('erp_app_role_permissions')
        .select('app_id, role_key, permission_key, allowed')
        .eq('app_id', appId)
        .order('role_key')
        .order('permission_key');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => ErpAppPermission(
              appId: row['app_id']?.toString() ?? appId,
              roleKey: row['role_key']?.toString() ?? '',
              permissionKey: row['permission_key']?.toString() ?? '',
              allowed: row['allowed'] == true,
            ))
        .toList(growable: false);
  }

  Future<void> savePermission(ErpAppPermission permission) async {
    final errors = permission.validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join('\n'));
    await _db.from('erp_app_role_permissions').upsert(
      {
        ...permission.toJson(),
        'updated_by': currentUserId,
      },
      onConflict: 'app_id,role_key,permission_key',
    );
  }

  Future<List<ErpAppActivityEntry>> listActivity({
    required String companyId,
    String? appId,
    int limit = 50,
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    var query = _db
        .from('erp_app_activity_log')
        .select('action, entity_type, entity_id, created_at, actor_id, app_id, details')
        .eq('company_id', companyId);
    if (appId != null && appId.trim().isNotEmpty) {
      query = query.eq('app_id', appId);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 500));
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => ErpAppActivityEntry(
              action: row['action']?.toString() ?? '',
              entityType: row['entity_type']?.toString() ?? '',
              entityId: row['entity_id']?.toString() ?? '',
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              actorId: row['actor_id']?.toString(),
              appId: row['app_id']?.toString(),
              details: row['details'] is Map
                  ? Map<String, Object?>.from(row['details'] as Map)
                  : const <String, Object?>{},
            ))
        .toList(growable: false);
  }

  /// Activity inserts should normally be performed by a trusted server function.
  /// This client method succeeds only if a deliberate RLS policy permits it.
  Future<void> requestActivityLog({
    required String companyId,
    String? appId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?> details = const {},
  }) async {
    _requireId(companyId, 'معرّف الشركة مطلوب.');
    if (action.trim().isEmpty ||
        entityType.trim().isEmpty ||
        entityId.trim().isEmpty) {
      throw ArgumentError('بيانات سجل النشاط غير مكتملة.');
    }
    await _db.from('erp_app_activity_log').insert({
      'company_id': companyId,
      'app_id': appId,
      'actor_id': currentUserId,
      'action': action.trim(),
      'entity_type': entityType.trim(),
      'entity_id': entityId.trim(),
      'details': details,
    });
  }

  static const Set<String> _validAssetTypes = {
    'app_logo',
    'splash',
    'app_icon',
    'category',
    'item',
    'supplier',
    'customer',
    'shipping_company',
    'other',
  };

  static ErpManagedAppStatus _statusFromDb(String? value) {
    switch (value) {
      case 'active':
        return ErpManagedAppStatus.active;
      case 'paused':
        return ErpManagedAppStatus.paused;
      default:
        return ErpManagedAppStatus.inDevelopment;
    }
  }

  static void _requireId(String value, String message) {
    if (value.trim().isEmpty) throw ArgumentError(message);
  }
}
