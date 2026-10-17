import 'package:supabase_flutter/supabase_flutter.dart';

class ClassificationService {
  ClassificationService({SupabaseClient? client})
      : _client = client ?? _defaultClient;

  final SupabaseClient? _client;

  static SupabaseClient? get _defaultClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static const List<String> defaultActivityTypes = [
    'مواد غذائية',
    'لوازم بناء وتشطيبات',
    'أجهزة وإلكترونيات',
    'أثاث وتجهيزات',
    'سيارات ومعدات',
    'ملابس وأقمشة',
    'أدوات منزلية',
    'أدوات كهربائية',
    'أدوات مكتبية',
    'مستلزمات طبية',
    'مستحضرات تجميل',
    'زراعة ومستلزماتها',
    'قطع غيار',
    'مستلزمات مطاعم وفنادق',
    'ورقيات وتعبئة وتغليف',
    'منظفات ومطهرات',
    'مستلزمات حيوانات',
    'خدمات وشحن ونقل',
    'أنشطة أخرى',
  ];

  static const List<String> defaultCustomerTypes = [
    'سوبر ماركت',
    'بقالة',
    'تاجر نصف جملة',
    'تاجر جملة',
    'مطعم أو كافيه',
    'جهة أخرى',
  ];

  static const List<String> defaultSupplierTypes = [
    'تاجر جملة جملة',
    'تاجر جملة',
    'شركة تصنيع',
    'موزع معتمد',
    'مندوب شركة',
    'مستورد',
  ];

  static const List<String> defaultDelegateTypes = [
    'مندوب مبيعات',
    'مندوب تسليم',
    'مندوب تنسيق رفوف',
    'مشرف مبيعات',
    'قائد فريق',
    'مندوب داخلي',
    'مندوب خارجي',
    'مندوب من المنزل',
    'مندوب جوكر',
  ];

  static const Map<String, List<String>> _fallbackByRole = {
    'customer': defaultCustomerTypes,
    'supplier': defaultSupplierTypes,
    'delegate': defaultDelegateTypes,
  };

  /// جلب أنواع الأنشطة من قاعدة البيانات،
  /// مع استخدام القائمة الافتراضية عند تعذر الجلب.
  Future<List<String>> getActivityTypes() {
    return _loadNames(
      table: 'activity_types',
      fallback: defaultActivityTypes,
    );
  }

  /// جلب تصنيفات الحساب حسب الدور.
  ///
  /// الأدوار المدعومة:
  /// customer, supplier, delegate
  Future<List<String>> getAccountClassifications(
    String accountRole,
  ) async {
    final role = accountRole.trim().toLowerCase();
    final fallback = _fallbackByRole[role];

    if (fallback == null) {
      throw ArgumentError.value(
        accountRole,
        'accountRole',
        'يجب أن يكون customer أو supplier أو delegate',
      );
    }

    final client = _client;
    if (client == null) {
      return List<String>.unmodifiable(fallback);
    }

    try {
      final response = await client
          .from('account_classifications')
          .select('classification_name')
          .eq('account_role', role)
          .eq('is_active', true)
          .order('sort_order');

      final names = _extractNames(
        response,
        field: 'classification_name',
      );

      return names.isEmpty
          ? List<String>.unmodifiable(fallback)
          : names;
    } catch (_) {
      return List<String>.unmodifiable(fallback);
    }
  }

  /// تحميل أسماء من جدول يحتوي على حقل name.
  Future<List<String>> _loadNames({
    required String table,
    required List<String> fallback,
  }) async {
    final client = _client;

    if (client == null) {
      return List<String>.unmodifiable(fallback);
    }

    try {
      final response = await client
          .from(table)
          .select('name')
          .eq('is_active', true)
          .order('sort_order');

      final names = _extractNames(
        response,
        field: 'name',
      );

      return names.isEmpty
          ? List<String>.unmodifiable(fallback)
          : names;
    } catch (_) {
      return List<String>.unmodifiable(fallback);
    }
  }

  /// تنظيف الأسماء وإزالة القيم الفارغة والتكرارات،
  /// مع الحفاظ على ترتيب النتائج القادمة من قاعدة البيانات.
  List<String> _extractNames(
    List<dynamic> rows, {
    required String field,
  }) {
    final names = <String>[];
    final seen = <String>{};

    for (final item in rows) {
      if (item is! Map) continue;

      final rawValue = item[field];
      if (rawValue == null) continue;

      final name = rawValue.toString().trim();
      if (name.isEmpty) continue;

      if (seen.add(name)) {
        names.add(name);
      }
    }

    return List<String>.unmodifiable(names);
  }
}
