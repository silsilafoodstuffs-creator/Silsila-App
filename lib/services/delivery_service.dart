import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryService {
  DeliveryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب شركات الشحن النشطة.
  Future<List<Map<String, dynamic>>> getShippingCompanies({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _client
        .from('shipping_companies')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// إنشاء طلب توصيل مرتبط بطلب شراء.
  Future<Map<String, dynamic>> createDelivery({
    required String orderId,
    required String shippingCompanyId,
    required String pickupAddress,
    required String deliveryAddress,
    String? notes,
  }) async {
    final cleanOrderId = orderId.trim();
    final cleanCompanyId = shippingCompanyId.trim();
    final cleanPickup = pickupAddress.trim();
    final cleanDelivery = deliveryAddress.trim();

    if (cleanOrderId.isEmpty ||
        cleanCompanyId.isEmpty ||
        cleanPickup.isEmpty ||
        cleanDelivery.isEmpty) {
      throw ArgumentError('يرجى استكمال بيانات الشحنة والعناوين.');
    }

    final response = await _client
        .from('deliveries')
        .insert({
          'order_id': cleanOrderId,
          'shipping_company_id': cleanCompanyId,
          'requested_by': _userId,
          'pickup_address': cleanPickup,
          'delivery_address': cleanDelivery,
          'notes': _emptyToNull(notes),
          'status': 'pending',
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// جلب الشحنات التي طلبها المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyDeliveries({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _client
        .from('deliveries')
        .select()
        .eq('requested_by', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// متابعة شحنة مرتبطة بالمستخدم الحالي.
  Future<Map<String, dynamic>?> getDelivery(String deliveryId) async {
    final response = await _client
        .from('deliveries')
        .select()
        .eq('id', deliveryId)
        .eq('requested_by', _userId)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
