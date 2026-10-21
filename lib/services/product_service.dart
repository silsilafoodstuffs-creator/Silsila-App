import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  ProductService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client != null) {
      return client;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'اتصال Supabase غير متاح. يرجى المحاولة لاحقًا.',
      );
    }
  }

  static const String _productColumns =
      'id, supplier_id, name, category, category_id, '
      'description, price, unit, min_quantity, minimum_quantity, '
      'activity_type, is_active, image_url, subcategory, brand, '
      'package_count, small_unit, offer_price, image_data, image_mime_type, created_at';

  /// جلب المنتجات النشطة مع إمكانية التصفية.
  Future<List<Map<String, dynamic>>> getProducts({
    String? activityType,
    String? category,
    int? categoryId,
    String? supplierId,
    String? search,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    if (categoryId != null && categoryId <= 0) {
      throw ArgumentError('رقم القسم غير صالح.');
    }

    final cleanActivityType = _clean(activityType);
    final cleanCategory = _clean(category);
    final cleanSupplierId = _clean(supplierId);
    final cleanSearch = _clean(search);

    if (cleanActivityType != null && cleanActivityType.length > 100) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
    }

    if (cleanCategory != null && cleanCategory.length > 150) {
      throw ArgumentError('اسم القسم طويل أكثر من اللازم.');
    }

    if (cleanSupplierId != null && cleanSupplierId.length > 200) {
      throw ArgumentError('معرّف المورد طويل أكثر من اللازم.');
    }

    if (cleanSearch != null && cleanSearch.length > 150) {
      throw ArgumentError('عبارة البحث طويلة أكثر من اللازم.');
    }

    var query = _requireClient
        .from('products')
        .select(_productColumns)
        .eq('is_active', true);

    // Apply filters before ordering and limiting so matching products are not
    // accidentally omitted when earlier rows do not match the selected filters.
    if (cleanActivityType != null) {
      query = query.eq('activity_type', cleanActivityType);
    }
    if (cleanCategory != null) {
      query = query.eq('category', cleanCategory);
    }
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (cleanSupplierId != null) {
      query = query.eq('supplier_id', cleanSupplierId);
    }
    if (cleanSearch != null) {
      query = query.ilike('name', '%${_escapeLike(cleanSearch)}%');
    }

    final response = await query
        .order('name', ascending: true)
        .limit(limit);
    return _mapRows(response);
  }

  /// جلب تفاصيل منتج نشط باستخدام رقمه.
  Future<Map<String, dynamic>?> getProductById(
    String productId,
  ) async {
    final cleanProductId = productId.trim();
    if (cleanProductId.isEmpty) {
      throw ArgumentError('معرّف المنتج غير صالح.');
    }

    final response = await _requireClient
        .from('products')
        .select(_productColumns)
        .eq('id', cleanProductId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  /// جلب المنتجات النشطة التابعة لمورد محدد.
  Future<List<Map<String, dynamic>>> getSupplierProducts(
    String supplierId, {
    String? activityType,
    int limit = 100,
  }) async {
    final cleanSupplierId = _clean(supplierId);

    if (cleanSupplierId == null) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    if (cleanSupplierId.length > 200) {
      throw ArgumentError('معرّف المورد طويل أكثر من اللازم.');
    }

    return getProducts(
      supplierId: cleanSupplierId,
      activityType: activityType,
      limit: limit,
    );
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  String _escapeLike(String value) {
    // Escape PostgreSQL LIKE metacharacters as single-character escapes.
    // Backslash must be escaped first so later replacements remain literal.
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }

  String? _clean(String? value) {
    final result = value?.trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }

  List<Map<String, dynamic>> _mapRows(dynamic response) {
    if (response is! List) {
      throw StateError('تعذر قراءة قائمة المنتجات.');
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
