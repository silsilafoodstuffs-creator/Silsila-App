import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierService {
  SupplierService({SupabaseClient? client})
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

  /// جلب الموردين مع بياناتهم الأساسية.
  Future<List<Map<String, dynamic>>> getSuppliers({
    String? activityType,
    String? supplierType,
    String? search,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _requireClient
        .from('supplier_directory')
        .select(
          'id, full_name, activity_type, supplier_type, '
          'governorate, district, account_status',
        )
        .order('full_name', ascending: true)
        .limit(limit);

    var rows = List<Map<String, dynamic>>.from(response);
    final activity = activityType?.trim();
    final type = supplierType?.trim();
    final term = search?.trim();

    if (activity != null && activity.isNotEmpty) {
      rows = rows
          .where((row) => row['activity_type']?.toString() == activity)
          .toList();
    }
    if (type != null && type.isNotEmpty) {
      rows = rows
          .where((row) => row['supplier_type']?.toString() == type)
          .toList();
    }
    if (term != null && term.isNotEmpty) {
      final needle = term.toLowerCase();
      rows = rows
          .where((row) => (row['full_name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(needle))
          .toList();
    }
    return rows;
  }

  /// جلب بيانات مورد واحد باستخدام معرّف حسابه.
  Future<Map<String, dynamic>?> getSupplierById(
    String supplierId,
  ) async {
    final cleanId = _clean(supplierId);

    if (cleanId == null) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    if (cleanId.length > 200) {
      throw ArgumentError('معرّف المورد طويل أكثر من اللازم.');
    }

    final response = await _requireClient
        .from('supplier_directory')
        .select(
          'id, full_name, activity_type, supplier_type, '
          'governorate, district, account_status',
        )
        .eq('id', cleanId)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
  }

  /// جلب التفاصيل العامة لمورد واحد.
  Future<Map<String, dynamic>?> getSupplierDetails(
    String supplierId,
  ) async {
    final cleanId = _clean(supplierId);

    if (cleanId == null) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    if (cleanId.length > 200) {
      throw ArgumentError('معرّف المورد طويل أكثر من اللازم.');
    }

    final response = await _requireClient
        .from('supplier_public_details')
        .select()
        .eq('supplier_id', cleanId)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
  }

  /// تنظيف النصوص وتحويل الفارغ إلى null.
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
