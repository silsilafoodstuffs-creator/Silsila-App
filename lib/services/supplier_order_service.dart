import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierOrderService {
  SupplierOrderService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    if (_client != null) {
      return _client!;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'اتصال Supabase غير متاح. يرجى المحاولة لاحقًا.',
      );
    }
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    return user.id;
  }

  /// جلب الطلبات الواردة للمورد الحالي.
  Future<List<Map<String, dynamic>>> getMyOrders({
    String? status,
  }) async {
    var query = _requireClient
        .from('orders')
        .select()
        .eq('supplier_id', _userId);

    final cleanStatus = status?.trim();

    if (cleanStatus != null && cleanStatus.isNotEmpty) {
      query = query.eq('status', cleanStatus);
    }

    final rows = await query.order(
      'created_at',
      ascending: false,
    );

    return _mapRows(rows);
  }

  /// جلب عناصر طلب بعد التأكد من ملكية المورد للطلب.
  Future<List<Map<String, dynamic>>> getOrderItems(
    int orderId,
  ) async {
    _validateOrderId(orderId);

    final order = await _requireClient
        .from('orders')
        .select('id')
        .eq('id', orderId)
        .eq('supplier_id', _userId)
        .maybeSingle();

    if (order == null) {
      throw StateError(
        'الطلب غير موجود أو لا تملك صلاحية الوصول إليه.',
      );
    }

    final rows = await _requireClient
        .from('order_items')
        .select()
        .eq('order_id', orderId);

    return _mapRows(rows);
  }

  /// جلب تفاصيل الطلب مع عناصره.
  Future<Map<String, dynamic>?> getOrderDetails(
    int orderId,
  ) async {
    _validateOrderId(orderId);

    final result = await _requireClient
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', orderId)
        .eq('supplier_id', _userId)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    return Map<String, dynamic>.from(result);
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

  /// تجهيز الطلب للتحميل والتوصيل.
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
    final cleanReason = reason?.trim();

    if (cleanReason != null && cleanReason.length > 1000) {
      throw ArgumentError(
        'سبب الإلغاء يجب ألا يتجاوز 1000 حرف.',
      );
    }

    await _changeStatus(
      orderId: orderId,
      newStatus: 'مُلغي',
      allowedCurrentStatuses: {'انتظار قبول', 'تنفيذ'},
      note: cleanReason == null || cleanReason.isEmpty
          ? null
          : cleanReason,
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

  /// التحقق من الحالة الحالية ثم طلب انتقال الحالة عبر RPC.
  Future<void> _changeStatus({
    required int orderId,
    required String newStatus,
    required Set<String> allowedCurrentStatuses,
    String? note,
  }) async {
    _validateOrderId(orderId);

    final client = _requireClient;
    final userId = _userId;

    final order = await client
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .eq('supplier_id', userId)
        .maybeSingle();

    if (order == null) {
      throw StateError(
        'الطلب غير موجود أو لا تملك صلاحية الوصول إليه.',
      );
    }

    final currentStatus = order['status']?.toString() ?? '';

    if (!allowedCurrentStatuses.contains(currentStatus)) {
      throw StateError(
        'لا يمكن تغيير حالة الطلب من '
        '$currentStatus إلى $newStatus.',
      );
    }

    await client.rpc(
      'transition_supplier_order_status',
      params: {
        'p_order_id': orderId,
        'p_new_status': newStatus,
        'p_note': note,
      },
    );
  }

  void _validateOrderId(int orderId) {
    if (orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صالح.');
    }
  }

  List<Map<String, dynamic>> _mapRows(dynamic response) {
    if (response is! List) {
      throw StateError('تعذر قراءة بيانات الطلبات.');
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
