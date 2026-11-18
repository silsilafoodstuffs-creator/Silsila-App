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
    {'code':'01','name':'مواد غذائية'},
    {'code':'02','name':'لوازم بناء'},
    {'code':'03','name':'ملابس واكسسوارات'},
    {'code':'04','name':'أجهزة وإلكترونيات'},
    {'code':'05','name':'سيارات ومعدات'},
    {'code':'06','name':'خدمات شحن ونقل'},
    {'code':'07','name':'أثاث وديكورات'},
    {'code':'08','name':'أدوات كهربائية'},
    {'code':'09','name':'مكتبات وقرطاسية'},
    {'code':'10','name':'مستلزمات طبية'},
    {'code':'11','name':'مستحضرات تجميل وعناية'},
    {'code':'12','name':'زراعة ومستلزمات زراعية'},
    {'code':'13','name':'قطع غيار ومستلزمات صيانة'},
    {'code':'14','name':'مستلزمات فندقية ومطاعم'},
    {'code':'15','name':'تعبئة وتغليف'},
    {'code':'16','name':'منظفات ومستلزمات نظافة'},
    {'code':'17','name':'مستلزمات حيوانات وأعلاف'},
    {'code':'18','name':'خدمات نقل وتوصيل'},
    {'code':'19','name':'أنشطة أخرى'},
    {'code':'20','name':'كتب ومطبوعات'},
  ];

  /// تحميل الأنشطة المفعّلة والمصرّح بعرضها في التطبيق من المصدر الموحد.
  /// لا نعرض قائمة ثابتة عند فشل الاتصال أو عندما تكون القائمة فارغة؛
  /// لأن ذلك قد يُظهر نشاطًا أخفاه مسؤول النظام.
  Future<List<Map<String, dynamic>>> getActivities() async {
    try {
      final response = await _requireClient
          .from('activity_types')
          .select('id,code,name,name_en,sort_order,is_active,show_in_app')
          .eq('is_active', true)
          .eq('show_in_app', true)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
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
