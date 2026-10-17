import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierProductService {
  SupplierProductService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    if (_client != null) {
      return _client!;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'اتصال Supabase غير متاح. يرجى المحاولة لاحقًا.',
      );
    }
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    return user.id;
  }

  /// جلب منتجات مورد محدد.
  Future<List<Map<String, dynamic>>> getSupplierProducts(
    String supplierId, {
    bool activeOnly = true,
    String? category,
    int limit = 100,
  }) async {
    final cleanSupplierId = supplierId.trim();

    if (cleanSupplierId.isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    var query = _requireClient
        .from('products')
        .select()
        .eq('supplier_id', cleanSupplierId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final cleanCategory = category?.trim();

    if (cleanCategory != null && cleanCategory.isNotEmpty) {
      query = query.eq('category', cleanCategory);
    }

    final rows = await query.order('name').limit(limit);

    return _mapRows(rows);
  }

  /// جلب منتج بواسطة المعرّف.
  Future<Map<String, dynamic>?> getProductById(
    int productId,
  ) async {
    _validateProductId(productId);

    final result = await _requireClient
        .from('products')
        .select()
        .eq('id', productId)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    return Map<String, dynamic>.from(result);
  }

  /// إضافة منتج جديد للمورد الحالي.
  Future<Map<String, dynamic>> createProduct({
    required String name,
    required String category,
    required num price,
    String? description,
    String unit = 'قطعة',
    num minQuantity = 1,
    int? categoryId,
    String? imageUrl,
    num stockQuantity = 0,
    bool trackInventory = false,
  }) async {
    final cleanName = _requiredText(
      name,
      'اسم المنتج مطلوب.',
      maxLength: 200,
    );

    final cleanCategory = _requiredText(
      category,
      'قسم المنتج مطلوب.',
      maxLength: 120,
    );

    final cleanUnit = _requiredText(
      unit,
      'وحدة المنتج مطلوبة.',
      maxLength: 60,
    );

    _validatePrice(price);
    _validateMinimumQuantity(minQuantity);
    _validateStock(stockQuantity);
    _validateCategoryId(categoryId);

    final cleanDescription = _clean(description);

    if (cleanDescription != null &&
        cleanDescription.length > 5000) {
      throw ArgumentError(
        'وصف المنتج يجب ألا يتجاوز 5000 حرف.',
      );
    }

    final cleanImageUrl = _clean(imageUrl);

    if (cleanImageUrl != null) {
      _validateImageUrl(cleanImageUrl);
    }

    final result = await _requireClient
        .from('products')
        .insert({
          'supplier_id': _userId,
          'name': cleanName,
          'category': cleanCategory,
          'category_id': categoryId,
          'description': cleanDescription,
          'price': price,
          'unit': cleanUnit,
          'min_quantity': minQuantity,
          'minimum_quantity': minQuantity,
          'image_url': cleanImageUrl,
          'stock_quantity': stockQuantity,
          'track_inventory': trackInventory,
          'is_active': true,
          'is_available': true,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(result);
  }

  /// تحديث بيانات منتج يملكه المورد الحالي.
  Future<void> updateProduct({
    required int productId,
    String? name,
    String? category,
    String? description,
    num? price,
    String? unit,
    num? minQuantity,
    int? categoryId,
    String? imageUrl,
    num? stockQuantity,
    bool? trackInventory,
    bool? isActive,
  }) async {
    _validateProductId(productId);

    final userId = _userId;
    final updates = <String, dynamic>{};

    if (name != null) {
      updates['name'] = _requiredText(
        name,
        'اسم المنتج مطلوب.',
        maxLength: 200,
      );
    }

    if (category != null) {
      updates['category'] = _requiredText(
        category,
        'قسم المنتج مطلوب.',
        maxLength: 120,
      );
    }

    if (description != null) {
      final cleanedDescription = _clean(description);

      if (cleanedDescription != null &&
          cleanedDescription.length > 5000) {
        throw ArgumentError(
          'وصف المنتج يجب ألا يتجاوز 5000 حرف.',
        );
      }

      updates['description'] = cleanedDescription;
    }

    if (price != null) {
      _validatePrice(price);
      updates['price'] = price;
    }

    if (unit != null) {
      updates['unit'] = _requiredText(
        unit,
        'وحدة المنتج مطلوبة.',
        maxLength: 60,
      );
    }

    if (minQuantity != null) {
      _validateMinimumQuantity(minQuantity);
      updates['min_quantity'] = minQuantity;
      updates['minimum_quantity'] = minQuantity;
    }

    if (categoryId != null) {
      _validateCategoryId(categoryId);
      updates['category_id'] = categoryId;
    }

    if (imageUrl != null) {
      final cleanImageUrl = _clean(imageUrl);

      if (cleanImageUrl != null) {
        _validateImageUrl(cleanImageUrl);
      }

      updates['image_url'] = cleanImageUrl;
    }

    if (stockQuantity != null) {
      _validateStock(stockQuantity);
      updates['stock_quantity'] = stockQuantity;
    }

    if (trackInventory != null) {
      updates['track_inventory'] = trackInventory;
    }

    if (isActive != null) {
      updates['is_active'] = isActive;
      updates['is_available'] = isActive;
    }

    if (updates.isEmpty) {
      return;
    }

    await _requireClient
        .from('products')
        .update(updates)
        .eq('id', productId)
        .eq('supplier_id', userId);
  }

  /// إخفاء المنتج دون حذفه نهائيًا.
  Future<void> deactivateProduct(int productId) async {
    await _setProductAvailability(
      productId: productId,
      isActive: false,
    );
  }

  /// إعادة تفعيل المنتج.
  Future<void> activateProduct(int productId) async {
    await _setProductAvailability(
      productId: productId,
      isActive: true,
    );
  }

  Future<void> _setProductAvailability({
    required int productId,
    required bool isActive,
  }) async {
    _validateProductId(productId);

    await _requireClient
        .from('products')
        .update({
          'is_active': isActive,
          'is_available': isActive,
        })
        .eq('id', productId)
        .eq('supplier_id', _userId);
  }

  void _validateProductId(int productId) {
    if (productId <= 0) {
      throw ArgumentError('معرّف المنتج غير صالح.');
    }
  }

  void _validateCategoryId(int? categoryId) {
    if (categoryId != null && categoryId <= 0) {
      throw ArgumentError('معرّف قسم المنتج غير صالح.');
    }
  }

  void _validatePrice(num price) {
    if (!price.isFinite || price < 0) {
      throw ArgumentError(
        'السعر يجب أن يكون رقمًا صالحًا وغير سالب.',
      );
    }
  }

  void _validateMinimumQuantity(num quantity) {
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError(
        'الحد الأدنى للكمية يجب أن يكون أكبر من صفر.',
      );
    }
  }

  void _validateStock(num quantity) {
    if (!quantity.isFinite || quantity < 0) {
      throw ArgumentError(
        'كمية المخزون يجب ألا تكون سالبة.',
      );
    }
  }

  String _requiredText(
    String value,
    String message, {
    required int maxLength,
  }) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.length > maxLength) {
      throw ArgumentError(
        '$message يجب ألا يتجاوز $maxLength حرفًا.',
      );
    }

    return cleaned;
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  void _validateImageUrl(String value) {
    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw ArgumentError('رابط صورة المنتج غير صالح.');
    }
  }

  List<Map<String, dynamic>> _mapRows(dynamic response) {
    if (response is! List) {
      throw StateError('تعذر قراءة بيانات المنتجات.');
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
