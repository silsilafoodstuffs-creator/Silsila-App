import 'package:supabase_flutter/supabase_flutter.dart';

class SearchService {
  SearchService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// البحث عن الموردين بالاسم.
  Future<List<Map<String, dynamic>>> searchSuppliers({
    String? query,
    String? activityType,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    var request = _client
        .from('supplier_directory')
        .select('id, full_name, activity_type, supplier_type, governorate, district, account_status');

    final term = query?.trim();
    if (term != null && term.isNotEmpty) {
      request = request.ilike('full_name', '%${_escapeLike(term)}%');
    }

    final activity = activityType?.trim();
    if (activity != null && activity.isNotEmpty) {
      request = request.eq('activity_type', activity);
    }

    final response = await request
        .order('full_name', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// البحث عن المنتجات بالاسم.
  Future<List<Map<String, dynamic>>> searchProducts({
    String? query,
    String? activityType,
    String? category,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    var request = _client
        .from('products')
        .select()
        .eq('is_active', true);

    final term = query?.trim();
    if (term != null && term.isNotEmpty) {
      request = request.ilike('name', '%${_escapeLike(term)}%');
    }

    final activity = activityType?.trim();
    if (activity != null && activity.isNotEmpty) {
      request = request.eq('activity_type', activity);
    }

    final categoryName = category?.trim();
    if (categoryName != null && categoryName.isNotEmpty) {
      request = request.eq('category', categoryName);
    }

    final response = await request
        .order('name', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// البحث داخل تصنيفات الأقسام.
  Future<List<Map<String, dynamic>>> searchCategories({
    String? query,
    String? activityType,
    int limit = 100,
  }) async {
    _validateLimit(limit);

    var request = _client
        .from('categories')
        .select()
        .eq('is_active', true);

    final term = query?.trim();
    if (term != null && term.isNotEmpty) {
      request = request.ilike('name', '%${_escapeLike(term)}%');
    }

    final activity = activityType?.trim();
    if (activity != null && activity.isNotEmpty) {
      request = request.eq('activity_type', activity);
    }

    final response = await request
        .order('sort_order', ascending: true)
        .order('name', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
