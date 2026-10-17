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

  /// جلب شركة الشحن المرتبطة بحساب المستخدم الحالي.
  Future<Map<String, dynamic>?> getMyShippingCompany() async {
    final response = await _client
        .from('shipping_companies')
        .select()
        .eq('profile_id', _userId)
        .maybeSingle();
    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }

  /// جلب الشحنات المسندة إلى شركة الشحن الحالية.
  Future<List<Map<String, dynamic>>> getAssignedDeliveries({
    int limit = 100,
  }) async {
    _validateLimit(limit);
    final company = await getMyShippingCompany();
    if (company == null) return [];
    final rows = await _client
        .from('deliveries')
        .select()
        .eq('shipping_company_id', company['id'])
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// تحديث حالة الشحنة عبر إجراء آمن يتحقق من شركة الشحن المسندة.
  Future<Map<String, dynamic>> updateDeliveryStatus({
    required String deliveryId,
    required String status,
    String? note,
  }) async {
    const allowed = {'قيد الاستلام', 'في الطريق', 'تم التسليم', 'ملغي', 'مُلغي'};
    if (!allowed.contains(status)) {
      throw ArgumentError('حالة الشحنة غير مدعومة.');
    }
    final response = await _client.rpc(
      'shipping_company_update_delivery_status',
      params: {
        'p_delivery_id': deliveryId.trim(),
        'p_new_status': status,
        'p_note': _emptyToNull(note),
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// قائمة شركات الشحن للإدارة، بما فيها غير النشطة.
  Future<List<Map<String, dynamic>>> getAllShippingCompaniesForAdmin() async {
    final response = await _client.rpc('admin_list_shipping_companies');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// إنشاء أو تحديث شركة شحن من لوحة الإدارة.
  Future<Map<String, dynamic>> saveShippingCompany({
    String? companyId,
    String? profileId,
    required String name,
    String? phone,
    required bool isActive,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('اسم شركة الشحن مطلوب.');
    final response = await _client.rpc(
      'admin_save_shipping_company',
      params: {
        'p_company_id': companyId,
        'p_profile_id': profileId,
        'p_name': name.trim(),
        'p_phone': _emptyToNull(phone),
        'p_is_active': isActive,
      },
    );
    return Map<String, dynamic>.from(response as Map);
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
