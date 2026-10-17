import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierProductService {
  SupplierProductService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// جلب منتجات مورد محدد.
  Future<List<Map<String, dynamic>>> getSupplierProducts(
    String supplierId, {
    bool activeOnly = true,
    String? category,
  }) async {
    var query = _client
        .from('products')
        .select()
        .eq('supplier_id', supplierId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    if (category != null && category.trim().isNotEmpty) {
      query = query.eq('category', category.trim());
    }

    final rows = await query.order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  /// جلب منتج بواسطة المعرّف.
  Future<Map<String, dynamic>?> getProductById(
    int productId,
  ) async {
    return await _client
        .from('products')
        .select()
        .eq('id', productId)
        .maybeSingle();
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
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    final cleanName = name.trim();
    final cleanCategory = category.trim();
    final cleanUnit = unit.trim();
    if (cleanName.isEmpty || cleanName.length > 200) {
      throw ArgumentError('اسم المنتج مطلوب وألا يتجاوز 200 حرفًا.');
    }

    if (cleanCategory.isEmpty || cleanCategory.length > 120) {
      throw ArgumentError('قسم المنتج مطلوب ويجب ألا يتجاوز 120 حرفًا.');
    }
    if (cleanUnit.isEmpty || cleanUnit.length > 60) {
      throw ArgumentError('وحدة المنتج مطلوبة ويجب ألا تتجاوز 60 حرفًا.');
    }

    if (!price.isFinite ||
        price < 0 ||
        !minQuantity.isFinite ||
        minQuantity <= 0 ||
        !stockQuantity.isFinite ||
        stockQuantity < 0) {
      throw ArgumentError('السعر والحد الأدنى والمخزون يجب أن تكون قيمًا صحيحة.');
    }
    if (categoryId != null && categoryId <= 0) {
      throw ArgumentError('معرّف قسم المنتج غير صالح.');
    }
    if ((description ?? '').trim().length > 5000) {
      throw ArgumentError('وصف المنتج يجب ألا يتجاوز 5000 حرف.');
    }
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(imageUrl.trim());
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty) {
        throw ArgumentError('رابط صورة المنتج غير صالح.');
      }
    }

    final result = await _client
        .from('products')
        .insert({
          'supplier_id': user.id,
          'name': cleanName,
          'category': cleanCategory,
          'category_id': categoryId,
          'description': description?.trim(),
          'price': price,
          'unit': cleanUnit,
          'min_quantity': minQuantity,
          'minimum_quantity': minQuantity,
          'image_url': imageUrl,
          'stock_quantity': stockQuantity,
          'track_inventory': trackInventory,
          'is_active': true,
          'is_available': true,
        })
        .select()
        .single();

    return result;
  }

  /// تحديث بيانات منتج.
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
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    final updates = <String, dynamic>{};

    if (name != null) {
      if (name.trim().isEmpty) {
        throw ArgumentError('اسم المنتج مطلوب.');
      }
      updates['name'] = name.trim();
    }

    if (category != null) {
      final cleanedCategory = category.trim();
      if (cleanedCategory.isEmpty || cleanedCategory.length > 120) {
        throw ArgumentError('قسم المنتج مطلوب ويجب ألا يتجاوز 120 حرفًا.');
      }
      updates['category'] = cleanedCategory;
    }

    if (description != null) {
      updates['description'] = description.trim();
    }

    if (price != null) {
      if (!price.isFinite || price < 0) {
        throw ArgumentError('السعر لا يمكن أن يكون سالبًا.');
      }
      updates['price'] = price;
    }

    if (unit != null) {
      final cleanedUnit = unit.trim();
      if (cleanedUnit.isEmpty || cleanedUnit.length > 60) {
        throw ArgumentError('وحدة المنتج مطلوبة ويجب ألا تتجاوز 60 حرفًا.');
      }
      updates['unit'] = cleanedUnit;
    }

    if (minQuantity != null) {
      if (!minQuantity.isFinite || minQuantity <= 0) {
        throw ArgumentError('الحد الأدنى للكمية يجب أن يكون أكبر من صفر.');
      }
      updates['min_quantity'] = minQuantity;
      updates['minimum_quantity'] = minQuantity;
    }

    if (stockQuantity != null) {
      if (!stockQuantity.isFinite || stockQuantity < 0) {
        throw ArgumentError('المخزون لا يمكن أن يكون سالبًا.');
      }
      updates['stock_quantity'] = stockQuantity;
    }
    if (trackInventory != null) updates['track_inventory'] = trackInventory;
    if (categoryId != null) {
      if (categoryId <= 0) {
        throw ArgumentError('معرّف قسم المنتج غير صالح.');
      }
      updates['category_id'] = categoryId;
    }
    if (imageUrl != null) {
      final cleanedImageUrl = imageUrl.trim();
      if (cleanedImageUrl.isNotEmpty) {
        final uri = Uri.tryParse(cleanedImageUrl);
        if (uri == null ||
            !uri.hasScheme ||
            (uri.scheme != 'https' && uri.scheme != 'http') ||
            uri.host.isEmpty) {
          throw ArgumentError('رابط صورة المنتج غير صالح.');
        }
      }
      updates['image_url'] = cleanedImageUrl.isEmpty ? null : cleanedImageUrl;
    }
    if (isActive != null) {
      updates['is_active'] = isActive;
      updates['is_available'] = isActive;
    }

    if (updates.isEmpty) return;

    await _client
        .from('products')
        .update(updates)
        .eq('id', productId)
        .eq('supplier_id', user.id);
  }

  /// إخفاء المنتج دون حذفه نهائيًا.
  Future<void> deactivateProduct(int productId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    await _client
        .from('products')
        .update({'is_active': false})
        .eq('id', productId)
        .eq('supplier_id', user.id);
  }

  /// إعادة تفعيل المنتج.
  Future<void> activateProduct(int productId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    await _client
        .from('products')
        .update({'is_active': true})
        .eq('id', productId)
        .eq('supplier_id', user.id);
  }
}
