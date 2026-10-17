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
      throw StateError('اتصال Supabase غير متاح حالياً.');
    }
    return client;
  }

  String get _userId {
    final id = _requireClient.auth.currentUser?.id;
    if (id == null || id.trim().isEmpty) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return id;
  }

  String _normalizeSupplierId(String supplierId) {
    final id = supplierId.trim();

    if (id.isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    if (id.length > 200) {
      throw ArgumentError('معرّف المورد طويل أكثر من اللازم.');
    }

    return id;
  }

  /// جلب معرّفات الموردين المفضلين للمستخدم الحالي.
  Future<List<String>> getFavoriteSupplierIds() async {
    final response = await _requireClient
        .from('supplier_favorites')
        .select('supplier_id')
        .eq('user_id', _userId);

    final ids = <String>[];
    final seen = <String>{};

    for (final row in response) {
      final value = row['supplier_id'];
      if (value == null) continue;

      final id = value.toString().trim();
      if (id.isNotEmpty && id.length <= 200 && seen.add(id)) {
        ids.add(id);
      }
    }

    return ids;
  }

  /// التحقق مما إذا كان المورد ضمن المفضلة.
  Future<bool> isFavorite(String supplierId) async {
    final id = _normalizeSupplierId(supplierId);
    final userId = _userId;

    final response = await _requireClient
        .from('supplier_favorites')
        .select('supplier_id')
        .eq('user_id', userId)
        .eq('supplier_id', id)
        .maybeSingle();

    return response != null;
  }

  /// إضافة مورد إلى المفضلة.
  Future<void> addFavorite(String supplierId) async {
    final id = _normalizeSupplierId(supplierId);
    final userId = _userId;

    await _requireClient.from('supplier_favorites').upsert(
      {
        'user_id': userId,
        'supplier_id': id,
      },
      onConflict: 'user_id,supplier_id',
      ignoreDuplicates: true,
    );
  }

  /// إزالة مورد من المفضلة.
  Future<void> removeFavorite(String supplierId) async {
    final id = _normalizeSupplierId(supplierId);
    final userId = _userId;

    await _requireClient
        .from('supplier_favorites')
        .delete()
        .eq('user_id', userId)
        .eq('supplier_id', id);
  }

  /// تبديل حالة المورد بين الإضافة والحذف.
  ///
  /// تعيد true إذا أُضيف المورد، وfalse إذا أُزيل.
  Future<bool> toggleFavorite(String supplierId) async {
    final id = _normalizeSupplierId(supplierId);

    if (await isFavorite(id)) {
      await removeFavorite(id);
      return false;
    }

    await addFavorite(id);
    return true;
  }
}
