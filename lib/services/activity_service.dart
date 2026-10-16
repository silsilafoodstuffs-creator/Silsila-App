import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityService {
  ActivityService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const List<Map<String, String>> fallbackActivities = [
    {
      'code': 'food',
      'name': 'مواد غذائية',
    },
    {
      'code': 'building',
      'name': 'لوازم بناء وتشطيبات',
    },
    {
      'code': 'electronics',
      'name': 'أجهزة وإلكترونيات',
    },
    {
      'code': 'furniture',
      'name': 'أثاث وتجهيزات',
    },
    {
      'code': 'vehicles',
      'name': 'سيارات ومعدات',
    },
    {
      'code': 'clothing',
      'name': 'ملابس وأقمشة',
    },
    {
      'code': 'household',
      'name': 'أدوات منزلية',
    },
    {
      'code': 'stationery',
      'name': 'أدوات مكتبية وقرطاسية',
    },
    {
      'code': 'medical',
      'name': 'مستلزمات طبية',
    },
    {
      'code': 'agriculture',
      'name': 'مستلزمات زراعية',
    },
    {
      'code': 'packaging',
      'name': 'خامات ومواد تعبئة وتغليف',
    },
    {
      'code': 'other',
      'name': 'أنشطة أخرى',
    },
  ];

  /// جلب الأنشطة المسجلة في قاعدة البيانات.
  /// يستخدم القائمة الاحتياطية إذا تعذر الاتصال أو القراءة.
  Future<List<Map<String, dynamic>>> getActivities() async {
    try {
      final response = await _client
          .from('activity_types')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final activities = List<Map<String, dynamic>>.from(response);

      if (activities.isNotEmpty) {
        return activities;
      }
    } catch (_) {
      // استخدام القائمة الاحتياطية عند تعذر جلب البيانات.
    }

    return fallbackActivities
        .map((activity) => <String, dynamic>{
              'code': activity['code'],
              'name': activity['name'],
              'is_active': true,
            })
        .toList();
  }

  /// البحث عن نشاط بالاسم أو الرمز.
  Future<Map<String, dynamic>?> findActivity(String value) async {
    final searchValue = value.trim();

    if (searchValue.isEmpty) return null;

    final activities = await getActivities();

    for (final activity in activities) {
      final name = activity['name']?.toString() ?? '';
      final code = activity['code']?.toString() ?? '';
      final id = activity['id']?.toString() ?? '';

      if (name == searchValue ||
          code == searchValue ||
          id == searchValue) {
        return activity;
      }
    }

    return null;
  }

  /// التحقق من وجود نشاط محدد.
  Future<bool> isValidActivity(String value) async {
    return await findActivity(value) != null;
  }
}
