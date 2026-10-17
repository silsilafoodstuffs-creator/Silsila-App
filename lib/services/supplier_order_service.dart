import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierOrderService {
  SupplierOrderService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// جلب الطلبات الواردة للمورد الحالي.
  Future<List<Map<String, dynamic>>> getMyOrders({
    String? status,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    var query = _client
        .from('orders')
        .select()
        .eq('supplier_id', user.id);

    if (status != null && status.trim().isNotEmpty) {
      query = query.eq('status', status.trim());
    }

    final rows = await query.order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// جلب عناصر طلب محدد.
  Future<List<Map<String, dynamic>>> getOrderItems(
    int orderId,
  ) async {
    final rows = await _client
        .from('order_items')
        .select()
        .eq('order_id', orderId);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// جلب تفاصيل الطلب مع عناصره.
  Future<Map<String, dynamic>?> getOrderDetails(
    int orderId,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    return await _client
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', orderId)
        .eq('supplier_id', user.id)
        .maybeSingle();
  }

  /// قبول طلب جديد.
  Future<void> acceptOrder(int orderId) async {
    await _changeStatus(
      orderId: orderId,
      newStatus: 'تنفيذ',
      allowedCurrentStatuses: {'انتظار قبول'},
    );
  }

  /// بدء تجهيز الطلب.
  Future<void> startPreparingOrder(int orderId) async {
    await _changeStatus(
      orderId: orderId,
      newStatus: 'تحميل',
      allowedCurrentStatuses: {'تنفيذ'},
    );
  }

  /// تجهيز الطلب للتحميل.
  Future<void> markReadyForDelivery(int orderId) async {
    await _changeStatus(
      orderId: orderId,
      newStatus: 'توصيل',
      allowedCurrentStatuses: {'تحميل'},
    );
  }

  /// إلغاء الطلب من جانب المورد.
  Future<void> cancelOrder(
    int orderId, {
    String? reason,
  }) async {
    await _changeStatus(
      orderId: orderId,
      newStatus: 'مُلغي',
      note: reason,
      allowedCurrentStatuses: {'انتظار قبول', 'تنفيذ'},
    );
  }

  /// تأكيد إتمام التسليم.
  Future<void> markDelivered(int orderId) async {
    await _changeStatus(
      orderId: orderId,
      newStatus: 'تم التسليم',
      allowedCurrentStatuses: {'توصيل'},
    );
  }

  Future<void> _changeStatus({
    required int orderId,
    required String newStatus,
    required Set<String> allowedCurrentStatuses,
    String? note,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    final order = await _client
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .eq('supplier_id', user.id)
        .maybeSingle();

    if (order == null) {
      throw Exception('الطلب غير موجود أو لا تملك صلاحية الوصول إليه.');
    }

    final currentStatus = order['status']?.toString() ?? '';

    if (!allowedCurrentStatuses.contains(currentStatus)) {
      throw Exception('لا يمكن تغيير حالة الطلب من $currentStatus إلى $newStatus.');
    }

    await _client
        .from('orders')
        .update({'status': newStatus})
        .eq('id', orderId)
        .eq('supplier_id', user.id);

    await _client.from('order_status_history').insert({
      'order_id': orderId,
      'status': newStatus,
      'changed_by': user.id,
      'note': note,
    });
  }
}
