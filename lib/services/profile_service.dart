import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService({SupabaseClient? client})
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

  /// جلب بيانات الحساب الحالي.
  Future<Map<String, dynamic>?> getMyProfile() async {
    final client = _requireClient;
    final user = client.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    final response = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  /// حفظ بيانات الملف الشخصي للحساب الحالي.
  ///
  /// يجب أن يكون مفتاح id في جدول profiles مرتبطاً بمعرّف
  /// المستخدم في Supabase Auth.
  Future<void> saveMyProfile({
    required String fullName,
    required String activityType,
    String? customerType,
    String? supplierType,
    String? delegateType,
    String? whatsappPhone,
    String? governorate,
    String? district,
    String? area,
    String? address,
  }) async {
    final client = _requireClient;
    final user = client.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    final data = <String, dynamic>{
      'full_name': fullName.trim(),
      'activity_type': activityType,
      'customer_type': customerType,
      'supplier_type': supplierType,
      'delegate_type': delegateType,
      'whatsapp_phone': _clean(whatsappPhone),
      'governorate': _clean(governorate),
      'district': _clean(district),
      'area': _clean(area),
      'address': _clean(address),
    };

    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await client.from('profiles').update(data).eq('id', user.id);
  }

  /// تحديث حالة الحساب.
  ///
  /// تتطلب صلاحيات RLS مناسبة في قاعدة البيانات.
  Future<void> updateAccountStatus({required String userId, required String status}) async {
    final client = _requireClient;
    final user = client.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    final allowedStatuses = {
      'pending', 'approved', 'active', 'rejected', 'suspended',
      'مفعل', 'معتمد', 'مرفوض', 'موقوف',
    };
    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('حالة الحساب غير مدعومة.');
    }

    await client.rpc(
      'admin_update_account_status',
      params: {
        'p_user_id': userId.trim(),
        'p_status': status,
      },
    );
  }

  /// حذف المسافات وتحويل النص الفارغ إلى null.
  String? _clean(String? value) {
    final result = value?.trim();
    if (result == null || result.isEmpty) return null;
    return result;
  }
}
