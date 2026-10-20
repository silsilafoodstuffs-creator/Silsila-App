import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityService {
  ActivityService({SupabaseClient? client})
      : _client = client ?? _defaultClient;

  final SupabaseClient? _client;

  static SupabaseClient? get _defaultClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _requireClient {
    final client = _client;

    if (client == null) {
      throw StateError('اتصال Supabase غير متاح.');
    }

    return client;
  }

  /// قائمة الأنشطة الاحتياطية عند تعذر الاتصال بقاعدة البيانات.
  // Keep the offline fallback in the same order and with the same labels
  // as supabase/02_activity_classifications.sql and the app activity catalog.
  static const List<Map<String, String>> fallbackActivities = [
    {'code': 'food', 'name': 'مواد غذائية'},
    {'code': 'building', 'name': 'لوازم بناء وتشطيبات'},
    {'code': 'electronics', 'name': 'أجهزة وإلكترونيات'},
    {'code': 'furniture', 'name': 'أثاث وتجهيزات'},
    {'code': 'vehicles', 'name': 'سيارات ومعدات'},
    {'code': 'clothing', 'name': 'ملابس وأقمشة'},
    {'code': 'household', 'name': 'أدوات منزلية'},
    {'code': 'electrical_tools', 'name': 'أدوات كهربائية'},
    {'code': 'stationery', 'name': 'أدوات مكتبية'},
    {'code': 'medical', 'name': 'مستلزمات طبية'},
    {'code': 'cosmetics', 'name': 'مستحضرات تجميل'},
    {'code': 'agriculture', 'name': 'زراعة ومستلزماتها'},
    {'code': 'spare_parts', 'name': 'قطع غيار'},
    {'code': 'hospitality', 'name': 'مستلزمات مطاعم وفنادق'},
    {'code': 'paper_packaging', 'name': 'ورقيات وتعبئة وتغليف'},
    {'code': 'cleaning', 'name': 'منظفات ومطهرات'},
    {'code': 'pet_supplies', 'name': 'مستلزمات حيوانات'},
    {'code': 'shipping', 'name': 'خدمات وشحن ونقل'},
    {'code': 'other', 'name': 'أنشطة أخرى'},
  ];

  /// جلب الأنشطة النشطة من قاعدة البيانات.
  ///
  /// تعاد القائمة الاحتياطية إذا فشل الاتصال أو لم توجد نتائج.
  Future<List<Map<String, dynamic>>> getActivities() async {
    try {
      final response = await _requireClient
          .from('activity_types')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final activities =
          List<Map<String, dynamic>>.from(response);

      if (activities.isNotEmpty) {
        return activities;
      }
    } catch (_) {
      // نستخدم القائمة الاحتياطية عند تعذر جلب البيانات.
    }

    return fallbackActivities
        .map(
          (activity) => <String, dynamic>{
            'code': activity['code'],
            'name': activity['name'],
            'is_active': true,
          },
        )
        .toList(growable: false);
  }

  /// البحث عن نشاط بالاسم أو الرمز أو المعرّف.
  Future<Map<String, dynamic>?> findActivity(
    String value,
  ) async {
    final searchValue = value.trim();

    if (searchValue.isEmpty) {
      return null;
    }

    final activities = await getActivities();

    for (final activity in activities) {
      final name = activity['name']?.toString().trim() ?? '';
      final code = activity['code']?.toString().trim() ?? '';
      final id = activity['id']?.toString().trim() ?? '';

      if (name == searchValue ||
          code == searchValue ||
          id == searchValue) {
        return Map<String, dynamic>.from(activity);
      }
    }

    return null;
  }

  /// التحقق من وجود نشاط محدد.
  Future<bool> isValidActivity(String value) async {
    final activity = await findActivity(value);
    return activity != null;
  }

  /// جلب أسماء الأنشطة فقط لعرضها في القوائم.
  Future<List<String>> getActivityNames() async {
    final activities = await getActivities();

    return activities
        .map((activity) => activity['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }
}
