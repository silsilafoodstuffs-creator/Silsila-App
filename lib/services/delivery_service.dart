import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryService {
  DeliveryService({SupabaseClient? client})
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
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب شركات الشحن النشطة.
  Future<List<Map<String, dynamic>>> getShippingCompanies({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('shipping_companies')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true)
        .limit(limit);

    return _toMapList(response);
  }

  /// جلب شركة الشحن المرتبطة بحساب المستخدم الحالي.
  Future<Map<String, dynamic>?> getMyShippingCompany() async {
    final response = await _requireClient
        .from('shipping_companies')
        .select()
        .eq('profile_id', _userId)
        .maybeSingle();

    if (response == null) return null;
    return _toMap(response);
  }

  /// جلب الشحنات المسندة إلى شركة الشحن الحالية.
  Future<List<Map<String, dynamic>>> getAssignedDeliveries({
    int limit = 100,
  }) async {
    _validateLimit(limit);

    final company = await getMyShippingCompany();
    if (company == null || company['id'] == null) {
      return <Map<String, dynamic>>[];
    }

    final response = await _requireClient
        .from('deliveries')
        .select()
        .eq('shipping_company_id', company['id'])
        .order('created_at', ascending: false)
        .limit(limit);

    return _toMapList(response);
  }

  /// تحديث حالة الشحنة عبر إجراء قاعدة البيانات المخصص.
  Future<Map<String, dynamic>> updateDeliveryStatus({
    required String deliveryId,
    required String status,
    String? note,
  }) async {
    const allowedStatuses = <String>{
      'قيد الاستلام',
      'في الطريق',
      'تم التسليم',
      'ملغي',
      'مُلغي',
    };

    final cleanDeliveryId = deliveryId.trim();
    final cleanStatus = status.trim();
    final cleanNote = _emptyToNull(note);

    if (cleanDeliveryId.isEmpty) {
      throw ArgumentError('معرّف الشحنة مطلوب.');
    }

    if (!allowedStatuses.contains(cleanStatus)) {
      throw ArgumentError('حالة الشحنة غير مدعومة.');
    }

    if (cleanNote != null && cleanNote.length > 1000) {
      throw ArgumentError('ملاحظة الشحنة يجب ألا تتجاوز 1000 حرف.');
    }

    final response = await _requireClient.rpc(
      'shipping_company_update_delivery_status',
      params: {
        'p_delivery_id': cleanDeliveryId,
        'p_new_status': cleanStatus,
        'p_note': cleanNote,
      },
    );

    return _toMap(response);
  }

  /// قائمة شركات الشحن للإدارة، بما فيها غير النشطة.
  Future<List<Map<String, dynamic>>> getAllShippingCompaniesForAdmin() async {
    final response =
        await _requireClient.rpc('admin_list_shipping_companies');

    return _toMapList(response);
  }

  /// إنشاء أو تحديث شركة شحن من لوحة الإدارة.
  Future<Map<String, dynamic>> saveShippingCompany({
    String? companyId,
    String? profileId,
    required String name,
    String? phone,
    required bool isActive,
  }) async {
    final cleanName = name.trim();
    final cleanCompanyId = _emptyToNull(companyId);
    final cleanProfileId = _emptyToNull(profileId);
    final cleanPhone = _emptyToNull(phone);

    if (cleanName.isEmpty) {
      throw ArgumentError('اسم شركة الشحن مطلوب.');
    }

    if (cleanName.length > 200) {
      throw ArgumentError('اسم شركة الشحن طويل أكثر من اللازم.');
    }

    if (cleanPhone != null && cleanPhone.length > 50) {
      throw ArgumentError('رقم هاتف شركة الشحن طويل أكثر من اللازم.');
    }

    final response = await _requireClient.rpc(
      'admin_save_shipping_company',
      params: {
        'p_company_id': cleanCompanyId,
        'p_profile_id': cleanProfileId,
        'p_name': cleanName,
        'p_phone': cleanPhone,
        'p_is_active': isActive,
      },
    );

    return _toMap(response);
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
    final cleanNotes = _emptyToNull(notes);

    if (cleanOrderId.isEmpty ||
        cleanCompanyId.isEmpty ||
        cleanPickup.isEmpty ||
        cleanDelivery.isEmpty) {
      throw ArgumentError('يرجى استكمال بيانات الشحنة والعناوين.');
    }

    final parsedOrderId = int.tryParse(cleanOrderId);
    if (parsedOrderId == null || parsedOrderId <= 0) {
      throw ArgumentError('رقم الطلب المرتبط بالشحنة غير صحيح.');
    }

    if (cleanCompanyId.length > 200) {
      throw ArgumentError('معرّف شركة الشحن غير صحيح.');
    }

    if (cleanPickup.length > 2000 || cleanDelivery.length > 2000) {
      throw ArgumentError('عنوان الاستلام أو التسليم طويل أكثر من اللازم.');
    }

    if (cleanNotes != null && cleanNotes.length > 2000) {
      throw ArgumentError('ملاحظات الشحنة يجب ألا تتجاوز 2000 حرف.');
    }

    final response = await _requireClient
        .from('deliveries')
        .insert({
          'order_id': cleanOrderId,
          'shipping_company_id': cleanCompanyId,
          'requested_by': _userId,
          'pickup_address': cleanPickup,
          'delivery_address': cleanDelivery,
          'notes': cleanNotes,
          'status': 'قيد الاستلام',
        })
        .select()
        .single();

    return _toMap(response);
  }

  /// جلب الشحنات التي طلبها المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyDeliveries({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('deliveries')
        .select()
        .eq('requested_by', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _toMapList(response);
  }

  /// متابعة شحنة مرتبطة بالمستخدم الحالي.
  Future<Map<String, dynamic>?> getDelivery(String deliveryId) async {
    final cleanDeliveryId = deliveryId.trim();
    if (cleanDeliveryId.isEmpty) {
      throw ArgumentError('معرّف الشحنة مطلوب.');
    }

    final response = await _requireClient
        .from('deliveries')
        .select()
        .eq('id', cleanDeliveryId)
        .eq('requested_by', _userId)
        .maybeSingle();

    if (response == null) return null;

    return _toMap(response);
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

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw StateError('أعاد الخادم بيانات غير متوقعة.');
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) {
      throw StateError('أعاد الخادم قائمة بيانات غير متوقعة.');
    }

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
