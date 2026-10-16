import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesService {
  FavoritesService({SupabaseClient? client})
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

  String get _userId {
    final id = _requireClient.auth.currentUser?.id;
    if (id == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return id;
  }

  /// جلب معرّفات الموردين المفضلين للمستخدم الحالي.
  Future<List<String>> getFavoriteSupplierIds() async {
    final response = await _requireClient
        .from('favorites')
        .select('supplier_id')
        .eq('user_id', _userId);

    return response
        .map<String>((row) => row['supplier_id'].toString())
        .toList();
  }

  /// التحقق مما إذا كان المورد ضمن المفضلة.
  Future<bool> isFavorite(String supplierId) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    final response = await _requireClient
        .from('favorites')
        .select('supplier_id')
        .eq('user_id', _userId)
        .eq('supplier_id', supplierId.trim())
        .maybeSingle();

    return response != null;
  }

  /// إضافة مورد إلى المفضلة.
  Future<void> addFavorite(String supplierId) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    await _requireClient.from('favorites').upsert(
      {
        'user_id': _userId,
        'supplier_id': supplierId.trim(),
      },
      onConflict: 'user_id,supplier_id',
      ignoreDuplicates: true,
    );
  }

  /// إزالة مورد من المفضلة.
  Future<void> removeFavorite(String supplierId) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    await _requireClient
        .from('favorites')
        .delete()
        .eq('user_id', _userId)
        .eq('supplier_id', supplierId.trim());
  }

  /// تبديل حالة المورد بين الإضافة والحذف.
  Future<bool> toggleFavorite(String supplierId) async {
    final favorite = await isFavorite(supplierId);

    if (favorite) {
      await removeFavorite(supplierId);
      return false;
    }

    await addFavorite(supplierId);
    return true;
  }
}
