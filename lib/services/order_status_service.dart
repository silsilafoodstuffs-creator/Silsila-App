import 'package:supabase_flutter/supabase_flutter.dart';

class OrderStatusService {
  OrderStatusService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب سجل تغييرات حالة طلب، بعد التحقق من صلاحية الوصول إليه.
  Future<List<Map<String, dynamic>>> getOrderHistory(
    String orderId,
  ) async {
    final userId = _userId;

    final order = await _client
        .from('orders')
        .select('id')
        .eq('id', orderId)
        .or('customer_id.eq.$userId,supplier_id.eq.$userId')
        .maybeSingle();

    if (order == null) {
      throw StateError('الطلب غير موجود أو لا تملك صلاحية الاطلاع عليه.');
    }

    final response = await _client
        .from('order_status_history')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب الطلبات الحالية للمستخدم مع حالاتها.
  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final userId = _userId;

    final response = await _client
        .from('orders')
        .select()
        .or('customer_id.eq.$userId,supplier_id.eq.$userId')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// تحديث حالة طلب يملكه المورد الحالي.
  ///
  /// يجب أن تسمح سياسات Supabase للمستخدم بتنفيذ التحديث.
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    final cleanStatus = status.trim();

    const allowedStatuses = {
      'pending',
      'accepted',
      'processing',
      'loading',
      'shipping',
      'delivered',
      'cancelled',
    };

    if (!allowedStatuses.contains(cleanStatus)) {
      throw ArgumentError('حالة الطلب غير معروفة.');
    }

    final userId = _userId;

    final updated = await _client
        .from('orders')
        .update({'status': cleanStatus})
        .eq('id', orderId)
        .eq('supplier_id', userId)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw StateError('تعذر تحديث الطلب؛ تحقق من وجوده وصلاحياتك.');
    }

    // تسجيل السجل منفصل عن تحديث الطلب؛ يجب تحسينه لاحقًا
    // باستخدام دالة قاعدة بيانات لضمان تنفيذ العمليتين معًا.
    await _client.from('order_status_history').insert({
      'order_id': orderId,
      'status': cleanStatus,
      'changed_by': userId,
      'note': _emptyToNull(note),
    });

    return Map<String, dynamic>.from(updated);
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
