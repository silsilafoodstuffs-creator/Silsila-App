import 'dart:convert';

/// Application configuration models for the Silsila ERP admin workspace.
/// This layer validates and serializes settings; persistence and file uploads
/// must be supplied by a trusted repository/backend implementation.

enum ErpManagedAppStatus { active, inDevelopment, paused }

class ErpManagedApp {
  const ErpManagedApp({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.packageName,
    this.webUrl,
    this.logoPath,
  });

  final String id;
  final String name;
  final ErpManagedAppStatus status;
  final String? description;
  final String? packageName;
  final String? webUrl;
  final String? logoPath;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'description': _clean(description),
        'package_name': _clean(packageName),
        'web_url': _clean(webUrl),
        'logo_path': _clean(logoPath),
      };

  factory ErpManagedApp.fromJson(Map<String, Object?> json) {
    final rawStatus = json['status']?.toString();
    return ErpManagedApp(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: ErpManagedAppStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => ErpManagedAppStatus.inDevelopment,
      ),
      description: json['description']?.toString(),
      packageName: json['package_name']?.toString(),
      webUrl: json['web_url']?.toString(),
      logoPath: json['logo_path']?.toString(),
    );
  }

  static String? _clean(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }
}

class ErpAppThemeSettings {
  const ErpAppThemeSettings({
    required this.appId,
    required this.displayName,
    required this.primaryColor,
    required this.accentColor,
    this.logoPath,
    this.splashImagePath,
    this.iconPath,
    this.updatedAt,
    this.updatedBy,
  });

  final String appId;
  final String displayName;
  /// HTML hex color such as #3E007D.
  final String primaryColor;
  /// HTML hex color such as #FFA015.
  final String accentColor;
  final String? logoPath;
  final String? splashImagePath;
  final String? iconPath;
  final DateTime? updatedAt;
  final String? updatedBy;

  List<String> validate() {
    final errors = <String>[];
    if (appId.trim().isEmpty) errors.add('معرّف التطبيق مطلوب.');
    if (displayName.trim().isEmpty) errors.add('اسم التطبيق مطلوب.');
    if (!_isHexColor(primaryColor)) errors.add('اللون الأساسي غير صالح.');
    if (!_isHexColor(accentColor)) errors.add('اللون المميز غير صالح.');
    return errors;
  }

  Map<String, Object?> toJson() => {
        'app_id': appId,
        'display_name': displayName.trim(),
        'primary_color': primaryColor.toUpperCase(),
        'accent_color': accentColor.toUpperCase(),
        'logo_path': _clean(logoPath),
        'splash_image_path': _clean(splashImagePath),
        'icon_path': _clean(iconPath),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'updated_by': _clean(updatedBy),
      };

  static bool _isHexColor(String value) =>
      RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$')
          .hasMatch(value.trim());

  static String? _clean(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }
}

class ErpAppAssetRecord {
  const ErpAppAssetRecord({
    required this.appId,
    required this.assetType,
    required this.storagePath,
    required this.displayName,
    this.id,
    this.entityId,
    this.mimeType,
    this.fileSizeBytes,
    this.altText,
  });

  final String appId;
  final String assetType;
  final String storagePath;
  final String displayName;
  final String? id;
  final String? entityId;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? altText;

  List<String> validate() {
    final errors = <String>[];
    if (appId.trim().isEmpty) errors.add('التطبيق مطلوب.');
    if (!const {
      'app_logo',
      'splash',
      'app_icon',
      'category',
      'item',
      'supplier',
      'customer',
      'shipping_company',
      'other',
    }.contains(assetType)) {
      errors.add('نوع الملف غير مدعوم.');
    }
    if (storagePath.trim().isEmpty) errors.add('مسار الملف مطلوب.');
    if (displayName.trim().isEmpty) errors.add('اسم الملف مطلوب.');
    if (fileSizeBytes != null && fileSizeBytes! < 0) {
      errors.add('حجم الملف غير صالح.');
    }
    return errors;
  }

  Map<String, Object?> toJson() => {
        'app_id': appId,
        'asset_type': assetType,
        'storage_path': storagePath,
        'display_name': displayName.trim(),
        'entity_id': entityId,
        'mime_type': mimeType,
        'file_size_bytes': fileSizeBytes,
        'alt_text': altText,
      };
}

class ErpAppPermission {
  const ErpAppPermission({
    required this.appId,
    required this.roleKey,
    required this.permissionKey,
    this.allowed = false,
  });

  final String appId;
  final String roleKey;
  final String permissionKey;
  final bool allowed;

  List<String> validate() {
    final errors = <String>[];
    if (appId.trim().isEmpty) errors.add('التطبيق مطلوب.');
    if (roleKey.trim().isEmpty) errors.add('الدور الوظيفي مطلوب.');
    if (permissionKey.trim().isEmpty) errors.add('مفتاح الصلاحية مطلوب.');
    return errors;
  }

  Map<String, Object?> toJson() => {
        'app_id': appId,
        'role_key': roleKey,
        'permission_key': permissionKey,
        'allowed': allowed,
      };
}

class ErpAppActivityEntry {
  const ErpAppActivityEntry({
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.actorId,
    this.appId,
    this.details = const {},
  });

  final String action;
  final String entityType;
  final String entityId;
  final DateTime createdAt;
  final String? actorId;
  final String? appId;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => {
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'created_at': createdAt.toUtc().toIso8601String(),
        'actor_id': actorId,
        'app_id': appId,
        'details': details,
      };

  String toJsonString() => jsonEncode(toJson());
}
