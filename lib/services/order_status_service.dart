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

  /// حالات الطلب الموحدة في تطبيق سلسلة.
  static const List<String> allowedStatuses = [
    'انتظار قبول',
    'تنفيذ',
    'تحميل',
    'توصيل',
    'تم التسليم',
    'مُلغي',
  ];

  /// جلب سجل حركة الطلب.
  Future<List<Map<String, dynamic>>> getOrderHistory(
    int orderId,
  ) async {
    if (orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صالح.');
    }
    final userId = _userId;

    final order = await _client
        .from('orders')
        .select('id')
        .eq('id', orderId)
        .or('customer_id.eq.$userId,supplier_id.eq.$userId')
        .maybeSingle();

    if (order == null) {
      throw StateError('الطلب غير موجود أو لا تملك صلاحية الوصول إليه.');
    }

    final rows = await _client
        .from('order_status_history')
        .select()
        .eq('order_id', orderId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(rows);
  }

  /// طلبات المستخدم الحالية، من الأحدث إلى الأقدم.
  Future<List<Map<String, dynamic>>> getMyOrders({
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final userId = _userId;

    final rows = await _client
        .from('orders')
        .select()
        .or('customer_id.eq.$userId,supplier_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// جلب أصناف طلب يملكه المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    if (orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صالح.');
    }
    await getOrderHistory(orderId);
    final rows = await _client
        .from('order_items')
        .select('product_name, unit, quantity, unit_price, line_total, total_price')
        .eq('order_id', orderId)
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// إلغاء طلب العميل قبل بدء التنفيذ.
  Future<void> cancelOrder(int orderId) async {
    if (orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صالح.');
    }
    await _client.rpc(
      'cancel_customer_order',
      params: {'p_order_id': orderId},
    );
  }

  /// تحديث حالة الطلب بواسطة المورد.
  Future<Map<String, dynamic>> updateOrderStatus({
    required int orderId,
    required String status,
    String? note,
  }) async {
    final cleanStatus = status.trim();

    if (orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صالح.');
    }
    if (!allowedStatuses.contains(cleanStatus)) {
      throw ArgumentError('حالة الطلب غير صحيحة.');
    }
    if (note != null && note.trim().length > 1000) {
      throw ArgumentError('ملاحظة حالة الطلب يجب ألا تتجاوز 1000 حرف.');
    }

    final userId = _userId;

    final current = await _client
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .eq('supplier_id', userId)
        .maybeSingle();

    if (current == null) {
      throw StateError('الطلب غير موجود أو لا تملك صلاحية تحديثه.');
    }

    final currentStatus = current['status']?.toString() ?? '';

    if (!_canMove(currentStatus, cleanStatus)) {
      throw StateError(
        'لا يمكن نقل الطلب من "$currentStatus" إلى "$cleanStatus".',
      );
    }

    final updated = await _client.rpc(
      'transition_supplier_order_status',
      params: {
        'p_order_id': orderId,
        'p_new_status': cleanStatus,
        'p_note': _clean(note),
      },
    );

    return Map<String, dynamic>.from(updated as Map);
  }

  bool _canMove(String current, String next) {
    const transitions = {
      'انتظار قبول': ['تنفيذ', 'مُلغي'],
      'تنفيذ': ['تحميل', 'مُلغي'],
      'تحميل': ['توصيل'],
      'توصيل': ['تم التسليم'],
      'تم التسليم': [],
      'مُلغي': [],
    };

    return transitions[current]?.contains(next) ?? false;
  }

  String? _clean(String? value) {
    final result = value?.trim();
    if (result == null || result.isEmpty) return null;
    return result;
  }
}
