import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteService {
  FavoriteService({SupabaseClient? client})
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
      throw StateError('خدمة قاعدة البيانات غير متاحة حالياً.');
    }
    return client;
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً لحفظ المفضلة.');
    }
    return user.id;
  }

  /// قراءة مفضلة المنتجات والموردين بمفاتيح ثابتة.
  Future<Set<String>> getFavoriteKeys() async {
    final userId = _userId;

    final results = await Future.wait([
      _requireClient
          .from('favorites')
          .select('product_id')
          .eq('user_id', userId),
      _requireClient
          .from('supplier_favorites')
          .select('supplier_id')
          .eq('user_id', userId),
    ]);

    final keys = <String>{};

    for (final item in results[0]) {
      final productId = item['product_id'];
      if (productId == null) continue;

      final normalizedId = productId.toString().trim();
      if (normalizedId.isNotEmpty) {
        keys.add('product:$normalizedId');
      }
    }

    for (final item in results[1]) {
      final supplierId = item['supplier_id'];
      if (supplierId == null) continue;

      final normalizedId = supplierId.toString().trim();
      if (normalizedId.isNotEmpty) {
        keys.add('supplier:$normalizedId');
      }
    }

    return keys;
  }

  /// إضافة منتج إلى المفضلة أو إزالته منها.
  Future<void> setProductFavorite({
    required String productId,
    required bool favorite,
  }) async {
    if (productId.trim().isEmpty || productId.trim() == '0') {
      throw ArgumentError('معرّف المنتج غير صالح.');
    }

    final client = _requireClient;
    final userId = _userId;

    if (favorite) {
      await client.from('favorites').upsert(
        {
          'user_id': userId,
          'product_id': productId.trim(),
        },
        onConflict: 'user_id,product_id',
        ignoreDuplicates: true,
      );
    } else {
      await client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId.trim());
    }
  }

  /// إضافة مورد إلى المفضلة أو إزالته منها.
  Future<void> setSupplierFavorite({
    required String supplierId,
    required bool favorite,
  }) async {
    final id = supplierId.trim();

    if (id.isEmpty) {
      throw ArgumentError('معرّف المورد غير صالح.');
    }

    final client = _requireClient;
    final userId = _userId;

    if (id == userId) {
      throw ArgumentError('لا يمكن إضافة حسابك إلى مفضلة الموردين.');
    }

    if (favorite) {
      await client.from('supplier_favorites').upsert(
        {
          'user_id': userId,
          'supplier_id': id,
        },
        onConflict: 'user_id,supplier_id',
        ignoreDuplicates: true,
      );
    } else {
      await client
          .from('supplier_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('supplier_id', id);
    }
  }
}
