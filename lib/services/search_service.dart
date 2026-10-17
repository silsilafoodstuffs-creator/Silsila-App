import 'package:supabase_flutter/supabase_flutter.dart';

class SearchService {
  SearchService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client != null) {
      return client;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('اتصال Supabase غير متاح. يرجى المحاولة لاحقًا.');
    }
  }

  /// البحث عن الموردين بالاسم ونوع النشاط.
  Future<List<Map<String, dynamic>>> searchSuppliers({
    String? query,
    String? activityType,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    var request = _requireClient
        .from('supplier_directory')
        .select(
          'id, full_name, activity_type, supplier_type, '
          'governorate, district, account_status',
        );

    final term = _cleanSearch(query);

    if (term != null) {
      request = request.ilike(
        'full_name',
        '%${_escapeLike(term)}%',
      );
    }

    final activity = _clean(activityType);

    if (activity != null && activity.length > 100) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
    }

    if (activity != null) {
      request = request.eq('activity_type', activity);
    }

    final response = await request
        .order('full_name', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// البحث عن المنتجات بالاسم والنشاط والقسم.
  Future<List<Map<String, dynamic>>> searchProducts({
    String? query,
    String? activityType,
    String? category,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    var request = _requireClient
        .from('products')
        .select()
        .eq('is_active', true);

    final term = _cleanSearch(query);

    if (term != null) {
      request = request.ilike(
        'name',
        '%${_escapeLike(term)}%',
      );
    }

    final activity = _clean(activityType);

    if (activity != null) {
      request = request.eq('activity_type', activity);
    }

    final categoryName = _clean(category);

    if (categoryName != null) {
      request = request.eq('category', categoryName);
    }

    final response = await request
        .order('name', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// البحث داخل تصنيفات الأقسام النشطة.
  Future<List<Map<String, dynamic>>> searchCategories({
    String? query,
    String? activityType,
    int limit = 100,
  }) async {
    _validateLimit(limit);

    var request = _requireClient
        .from('categories')
        .select()
        .eq('is_active', true);

    final term = _cleanSearch(query);

    if (term != null) {
      request = request.ilike(
        'name',
        '%${_escapeLike(term)}%',
      );
    }

    final activity = _clean(activityType);

    if (activity != null) {
      request = request.eq('activity_type', activity);
    }

    final response = await request
        .order('sort_order', ascending: true)
        .order('name', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// البحث عن الموردين حسب المحافظة.
  Future<List<Map<String, dynamic>>> searchSuppliersByGovernorate({
    required String governorate,
    String? query,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final cleanGovernorate = _clean(governorate);

    if (cleanGovernorate == null) {
      throw ArgumentError('يرجى تحديد المحافظة.');
    }

    if (cleanGovernorate.length > 100) {
      throw ArgumentError('اسم المحافظة طويل أكثر من اللازم.');
    }

    var request = _requireClient
        .from('supplier_directory')
        .select(
          'id, full_name, activity_type, supplier_type, '
          'governorate, district, account_status',
        )
        .eq('governorate', cleanGovernorate);

    final term = _cleanSearch(query);

    if (term != null) {
      request = request.ilike(
        'full_name',
        '%${_escapeLike(term)}%',
      );
    }

    final response = await request
        .order('full_name', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// التحقق من الحد الأقصى لعدد النتائج.
  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  /// تنظيف عبارة البحث والتحقق من طولها.
  String? _cleanSearch(String? value) {
    final term = _clean(value);

    if (term != null && term.length > 150) {
      throw ArgumentError('عبارة البحث طويلة أكثر من اللازم.');
    }

    return term;
  }

  /// تنظيف النصوص الفارغة.
  String? _clean(String? value) {
    final result = value?.trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }

  /// تهريب الرموز الخاصة بأنماط البحث.
  String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
