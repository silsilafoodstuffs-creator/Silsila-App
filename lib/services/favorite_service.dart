import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteService {
  FavoriteService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً لحفظ المفضلة.');
    }
    return user.id;
  }

  /// Read both product and supplier favorites as stable keys.
  Future<Set<String>> getFavoriteKeys() async {
    final userId = _userId;
    final results = await Future.wait([
      _client.from('favorites').select('product_id').eq('user_id', userId),
      _client
          .from('supplier_favorites')
          .select('supplier_id')
          .eq('user_id', userId),
    ]);

    final keys = <String>{};
    for (final row in results[0] as List) {
      if (row['product_id'] != null) {
        keys.add('product:${row['product_id']}');
      }
    }
    for (final row in results[1] as List) {
      keys.add('supplier:${row['supplier_id']}');
    }
    return keys;
  }

  Future<void> setProductFavorite({
    required int productId,
    required bool favorite,
  }) async {
    if (productId <= 0) throw ArgumentError('معرّف المنتج غير صالح.');
    final userId = _userId;
    if (favorite) {
      await _client.from('favorites').upsert(
        {'user_id': userId, 'product_id': productId},
        onConflict: 'user_id,product_id',
        ignoreDuplicates: true,
      );
    } else {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    }
  }

  Future<void> setSupplierFavorite({
    required String supplierId,
    required bool favorite,
  }) async {
    final id = supplierId.trim();
    if (id.isEmpty || id == _userId) {
      throw ArgumentError('معرّف المورد غير صالح.');
    }
    final userId = _userId;
    if (favorite) {
      await _client.from('supplier_favorites').upsert(
        {'user_id': userId, 'supplier_id': id},
        onConflict: 'user_id,supplier_id',
        ignoreDuplicates: true,
      );
    } else {
      await _client
          .from('supplier_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('supplier_id', id);
    }
  }
}
