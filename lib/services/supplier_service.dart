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

  /// جلب الموردين النشطين مع بياناتهم الأساسية.
  ///
  /// يفترض أن profiles يحتوي على role وfull_name،
  /// وأن supplier_details يحتوي على supplier_id.
  Future<List<Map<String, dynamic>>> getSuppliers({
    String? activityType,
    String? supplierType,
    String? search,
    int limit = 50,
  }) async {
    final client = _requireClient;

    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    var query = client
        .from('supplier_directory')
        .select(
          'id, full_name, activity_type, supplier_type, '
          'governorate, district, address, account_status',
        )
        .order('full_name')
        .limit(limit);

    if (activityType != null && activityType.trim().isNotEmpty) {
      query = query.eq('activity_type', activityType.trim());
    }

    if (supplierType != null && supplierType.trim().isNotEmpty) {
      query = query.eq('supplier_type', supplierType.trim());
    }

    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('full_name', '%${search.trim()}%');
    }

    final response = await query;

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب بيانات مورد واحد باستخدام معرّف حسابه.
  Future<Map<String, dynamic>?> getSupplierById(
    String supplierId,
  ) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    final response = await _requireClient
        .from('supplier_directory')
        .select(
          'id, full_name, activity_type, supplier_type, '
          'governorate, district, address, account_status',
        )
        .eq('id', supplierId.trim())
        .eq('role', 'supplier')
        .maybeSingle();

    return response;
  }

  /// جلب تفاصيل المورد من جدول supplier_details.
  Future<Map<String, dynamic>?> getSupplierDetails(
    String supplierId,
  ) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    final response = await _requireClient
        .from('supplier_details')
        .select()
        .eq('supplier_id', supplierId.trim())
        .maybeSingle();

    return response;
  }
}
