import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  ProductService({SupabaseClient? client})
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

  /// جلب المنتجات النشطة مع إمكانية التصفية.
  Future<List<Map<String, dynamic>>> getProducts({
    String? activityType,
    String? category,
    int? categoryId,
    String? supplierId,
    String? search,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    var query = _requireClient
        .from('products')
        .select(
          'id, supplier_id, name, category, category_id, '
          'description, price, unit, min_quantity, '
          'activity_type, is_active, created_at',
        )
        .eq('is_active', true)
        .order('name')
        .limit(limit);

    if (activityType != null && activityType.trim().isNotEmpty) {
      query = query.eq('activity_type', activityType.trim());
    }

    if (category != null && category.trim().isNotEmpty) {
      query = query.eq('category', category.trim());
    }

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    if (supplierId != null && supplierId.trim().isNotEmpty) {
      query = query.eq('supplier_id', supplierId.trim());
    }

    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('name', '%${search.trim()}%');
    }

    final response = await query;

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب تفاصيل منتج واحد.
  Future<Map<String, dynamic>?> getProductById(
    int productId,
  ) async {
    final response = await _requireClient
        .from('products')
        .select(
          'id, supplier_id, name, category, category_id, '
          'description, price, unit, min_quantity, '
          'activity_type, is_active, created_at',
        )
        .eq('id', productId)
        .eq('is_active', true)
        .maybeSingle();

    return response;
  }

  /// جلب المنتجات التابعة لمورد محدد.
  Future<List<Map<String, dynamic>>> getSupplierProducts(
    String supplierId, {
    String? activityType,
    int limit = 100,
  }) async {
    return getProducts(
      supplierId: supplierId,
      activityType: activityType,
      limit: limit,
    );
  }
}
