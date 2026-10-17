import 'package:supabase_flutter/supabase_flutter.dart';

class OrderStatusService {
  OrderStatusService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client != null) {
      return client;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('خدمة الاتصال غير جاهزة. يرجى المحاولة لاحقًا.');
    }
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    final id = user.id.trim();

    if (id.isEmpty || id.length > 200) {
      throw StateError('معرّف المستخدم غير صالح. يرجى تسجيل الدخول مرة أخرى.');
    }

    return id;
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

  /// جلب سجل حركة طلب يخص المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getOrderHistory(
    int orderId,
  ) async {
    _validateOrderId(orderId);

    final client = _requireClient;
    final userId = _userId;

    final order = await client
        .from('orders')
        .select('id')
        .eq('id', orderId)
        .or('customer_id.eq.$userId,supplier_id.eq.$userId')
        .maybeSingle();

    if (order == null) {
      throw StateError(
        'الطلب غير موجود أو لا تملك صلاحية الوصول إليه.',
      );
    }

    final rows = await client
        .from('order_status_history')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: true);

    return _mapRows(rows);
  }

  /// جلب طلبات المستخدم الحالي من الأحدث إلى الأقدم.
  Future<List<Map<String, dynamic>>> getMyOrders({
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final client = _requireClient;
    final userId = _userId;

    final rows = await client
        .from('orders')
        .select()
        .or('customer_id.eq.$userId,supplier_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(rows);
  }

  /// جلب أصناف طلب يملكه المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getOrderItems(
    int orderId,
  ) async {
    _validateOrderId(orderId);

    // التحقق من ملكية الطلب قبل قراءة أصنافه.
    await getOrderHistory(orderId);

    final rows = await _requireClient
        .from('order_items')
        .select(
          'product_name, unit, quantity, unit_price, '
          'line_total, total_price',
        )
        .eq('order_id', orderId)
        .order('id');

    return _mapRows(rows);
  }

  /// إلغاء طلب العميل باستخدام إجراء قاعدة البيانات الحالي.
  Future<void> cancelOrder(int orderId) async {
    _validateOrderId(orderId);

    await _requireClient.rpc(
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
    _validateOrderId(orderId);

    final cleanStatus = status.trim();

    if (!allowedStatuses.contains(cleanStatus)) {
      throw ArgumentError('حالة الطلب غير صحيحة.');
    }

    final cleanNote = _clean(note);

    if (cleanNote != null && cleanNote.length > 1000) {
      throw ArgumentError(
        'ملاحظة حالة الطلب يجب ألا تتجاوز 1000 حرف.',
      );
    }

    final client = _requireClient;
    final userId = _userId;

    final current = await client
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .eq('supplier_id', userId)
        .maybeSingle();

    if (current == null) {
      throw StateError(
        'الطلب غير موجود أو لا تملك صلاحية تحديثه.',
      );
    }

    final currentStatus = current['status']?.toString().trim() ?? '';

    if (!_canMove(currentStatus, cleanStatus)) {
      throw StateError(
        'لا يمكن نقل الطلب من "$currentStatus" إلى "$cleanStatus".',
      );
    }

    final result = await client.rpc(
      'transition_supplier_order_status',
      params: {
        'p_order_id': orderId,
        'p_new_status': cleanStatus,
        'p_note': cleanNote,
      },
    );

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }

    throw StateError(
      'تم إرسال تحديث الحالة، لكن استجابة قاعدة البيانات '
      'لم تُرجع بيانات الطلب بالشكل المتوقع.',
    );
  }

  /// التحقق من انتقال حالة الطلب.
  bool _canMove(String current, String next) {
    const transitions = <String, List<String>>{
      'انتظار قبول': ['تنفيذ', 'مُلغي'],
      'تنفيذ': ['تحميل', 'مُلغي'],
      'تحميل': ['توصيل'],
      'توصيل': ['تم التسليم'],
      'تم التسليم': [],
      'مُلغي': [],
    };

    return transitions[current]?.contains(next) ?? false;
  }

  void _validateOrderId(int orderId) {
    if (orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صالح.');
    }
  }

  List<Map<String, dynamic>> _mapRows(dynamic rows) {
    if (rows is! List) {
      throw StateError('تعذر قراءة البيانات بالشكل المتوقع.');
    }

    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  String? _clean(String? value) {
    final result = value?.trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }
}
