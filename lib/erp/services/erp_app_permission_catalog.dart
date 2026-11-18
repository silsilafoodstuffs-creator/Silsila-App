import 'erp_app_settings.dart';

/// Canonical permission keys used by the Silsila ERP app-management UI.
///
/// These definitions describe the permission vocabulary only. They do not
/// enforce access; the backend must validate the same keys and the user's
/// company membership before allowing sensitive operations.
class ErpAppPermissionCatalog {
  ErpAppPermissionCatalog._();

  static const Map<String, String> roles = {
    'owner': 'مالك النشاط',
    'admin': 'مدير النظام',
    'manager': 'مدير',
    'accountant': 'محاسب',
    'warehouse': 'مسؤول مخزن',
    'sales': 'مبيعات',
    'purchasing': 'مشتريات',
    'viewer': 'عرض فقط',
  };

  static const Map<String, String> permissions = {
    'app.settings.read': 'عرض إعدادات التطبيق',
    'app.settings.update': 'تعديل اسم التطبيق وألوانه',
    'app.assets.read': 'عرض ملفات وصور التطبيق',
    'app.assets.upload': 'رفع ملفات وصور',
    'app.assets.delete': 'حذف مراجع الملفات',
    'data.export.excel': 'تصدير بيانات Excel',
    'app.permissions.read': 'عرض صلاحيات المستخدمين',
    'app.permissions.manage': 'إدارة صلاحيات المستخدمين',
    'app.activity.read': 'عرض سجل النشاطات',
    'app.registry.manage': 'إدارة سجل التطبيقات',
  };

  /// Conservative defaults: viewers can only read settings/assets/activity.
  /// No role receives permission management by default.
  static const Map<String, Set<String>> defaultAllowList = {
    'owner': {
      'app.settings.read',
      'app.settings.update',
      'app.assets.read',
      'app.assets.upload',
      'app.assets.delete',
      'data.export.excel',
      'app.permissions.read',
      'app.permissions.manage',
      'app.activity.read',
      'app.registry.manage',
    },
    'admin': {
      'app.settings.read',
      'app.settings.update',
      'app.assets.read',
      'app.assets.upload',
      'app.assets.delete',
      'data.export.excel',
      'app.permissions.read',
      'app.permissions.manage',
      'app.activity.read',
      'app.registry.manage',
    },
    'manager': {
      'app.settings.read',
      'app.settings.update',
      'app.assets.read',
      'app.assets.upload',
      'data.export.excel',
      'app.permissions.read',
      'app.activity.read',
    },
    'accountant': {'app.settings.read', 'data.export.excel', 'app.activity.read'},
    'warehouse': {'app.settings.read', 'app.assets.read', 'data.export.excel'},
    'sales': {'app.settings.read', 'app.assets.read', 'data.export.excel'},
    'purchasing': {'app.settings.read', 'app.assets.read', 'data.export.excel'},
    'viewer': {'app.settings.read', 'app.assets.read', 'app.activity.read'},
  };

  static bool isKnownRole(String roleKey) => roles.containsKey(roleKey);

  static bool isKnownPermission(String permissionKey) =>
      permissions.containsKey(permissionKey);

  static List<ErpAppPermission> createDefaults({required String appId}) {
    return [
      for (final roleKey in roles.keys)
        for (final permissionKey in permissions.keys)
          ErpAppPermission(
            appId: appId,
            roleKey: roleKey,
            permissionKey: permissionKey,
            allowed: defaultAllowList[roleKey]?.contains(permissionKey) ?? false,
          ),
    ];
  }

  static List<String> validate(ErpAppPermission permission) {
    final errors = permission.validate();
    if (!isKnownRole(permission.roleKey)) {
      errors.add('الدور الوظيفي غير معروف: ${permission.roleKey}');
    }
    if (!isKnownPermission(permission.permissionKey)) {
      errors.add('مفتاح الصلاحية غير معروف: ${permission.permissionKey}');
    }
    return errors;
  }
}
