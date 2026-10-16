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

  Future<List<String>> getActivityTypes() async {
    return _loadNames(
      table: 'activity_types',
      fallback: defaultActivityTypes,
    );
  }

  Future<List<String>> getAccountClassifications(
    String accountRole,
  ) async {
    final Map<String, List<String>> fallbackByRole = {
      'customer': defaultCustomerTypes,
      'supplier': defaultSupplierTypes,
      'delegate': defaultDelegateTypes,
    };

    final fallback = fallbackByRole[accountRole];

    if (fallback == null) {
      throw ArgumentError.value(
        accountRole,
        'accountRole',
        'يجب أن يكون customer أو supplier أو delegate',
      );
    }

    final client = _client;
    if (client == null) return fallback;

    try {
      final response = await client
          .from('account_classifications')
          .select('classification_name')
          .eq('account_role', accountRole)
          .eq('is_active', true)
          .order('sort_order');

      final names = response
          .map<String>(
            (row) => row['classification_name'].toString(),
          )
          .where((name) => name.isNotEmpty)
          .toList();

      return names.isEmpty ? fallback : names;
    } catch (_) {
      return fallback;
    }
  }

  Future<List<String>> _loadNames({
    required String table,
    required List<String> fallback,
  }) async {
    final client = _client;
    if (client == null) return fallback;

    try {
      final response = await client
          .from(table)
          .select('name')
          .eq('is_active', true)
          .order('sort_order');

      final names = response
          .map<String>((row) => row['name'].toString())
          .where((name) => name.isNotEmpty)
          .toList();

      return names.isEmpty ? fallback : names;
    } catch (_) {
      return fallback;
    }
  }
}
