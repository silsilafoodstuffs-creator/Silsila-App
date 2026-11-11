/// Silsila ERP external API integration primitives.
///
/// This catalog describes the deployed read-only API gateway. API credentials are
/// issued and revoked through authenticated Supabase RPCs; secret values are never
/// embedded in this client or persisted by this model.
class ErpApiEndpoint {
  const ErpApiEndpoint({
    required this.name,
    required this.path,
    required this.method,
    required this.description,
    required this.requiredScope,
  });

  final String name;
  final String path;
  final String method;
  final String description;
  final String requiredScope;
}

class ErpApiIntegration {
  const ErpApiIntegration({
    required this.clientName,
    required this.clientCode,
    required this.baseUrl,
    required this.scopes,
    required this.active,
  });

  final String clientName;
  final String clientCode;
  final String baseUrl;
  final Set<String> scopes;
  final bool active;

  /// Returns validation errors suitable for displaying in the API settings UI.
  List<String> validate() {
    final errors = <String>[];
    if (clientName.trim().isEmpty) {
      errors.add('اسم النظام المتصل مطلوب.');
    }
    if (clientCode.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{3,40}$').hasMatch(clientCode)) {
      errors.add('رمز الربط يجب أن يتكون من 3 إلى 40 حرفًا أو رقمًا أو - أو _.');
    }
    final uri = Uri.tryParse(baseUrl.trim());
    if (baseUrl.trim().isNotEmpty &&
        (uri == null ||
            !uri.hasScheme ||
            !{'https', 'http'}.contains(uri.scheme) ||
            uri.host.isEmpty)) {
      errors.add('عنوان الخدمة غير صالح.');
    }
    if (uri != null && uri.scheme == 'http' && uri.host != 'localhost') {
      errors.add('استخدم HTTPS للاتصالات خارج بيئة التطوير المحلية.');
    }
    if (scopes.isEmpty) {
      errors.add('اختر صلاحية واحدة على الأقل للنظام المتصل.');
    }
    return errors;
  }

  Map<String, Object?> toSafeJson() => {
        'client_name': clientName.trim(),
        'client_code': clientCode.trim(),
        'base_url': baseUrl.trim(),
        'scopes': scopes.toList()..sort(),
        'is_active': active,
      };
}

/// Read-only routes currently deployed by the Silsila API v1 gateway.
const List<ErpApiEndpoint> erpApiCatalog = [
  ErpApiEndpoint(
    name: 'بيانات الشركة',
    path: '/v1/company',
    method: 'GET',
    description: 'قراءة بيانات الشركة المصرح بها فقط.',
    requiredScope: 'company:read',
  ),
  ErpApiEndpoint(
    name: 'الأصناف',
    path: '/v1/items',
    method: 'GET',
    description: 'قراءة الأصناف النشطة مع الترقيم.',
    requiredScope: 'items:read',
  ),
  ErpApiEndpoint(
    name: 'العملاء',
    path: '/v1/customers',
    method: 'GET',
    description: 'قراءة دليل العملاء المسموح به.',
    requiredScope: 'customers:read',
  ),
  ErpApiEndpoint(
    name: 'الموردون',
    path: '/v1/suppliers',
    method: 'GET',
    description: 'قراءة دليل الموردين المسموح به.',
    requiredScope: 'suppliers:read',
  ),
  ErpApiEndpoint(
    name: 'المخزون',
    path: '/v1/inventory/balances',
    method: 'GET',
    description: 'قراءة أرصدة المخزون حسب الفرع والمخزن.',
    requiredScope: 'inventory:read',
  ),
  ErpApiEndpoint(
    name: 'الطلبات',
    path: '/v1/orders',
    method: 'GET',
    description: 'قراءة الطلبات المسموح بها مع الترقيم.',
    requiredScope: 'orders:read',
  ),
];
