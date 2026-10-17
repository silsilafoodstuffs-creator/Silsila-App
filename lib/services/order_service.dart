import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  OrderService({SupabaseClient? client})
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

  String get _userId {
    final id = _requireClient.auth.currentUser?.id;
    if (id == null) {
      throw StateError('يجب تسجيل الدخول قبل إنشاء الطلب.');
    }
    return id;
  }

  static const List<String> orderStatuses = [
    'انتظار قبول',
    'تنفيذ',
    'تحميل',
    'توصيل',
    'تم التسليم',
    'مُلغي',
  ];

  static const List<String> paymentMethods = [
    'نقدي',
    'آجل مورد',
    'محفظة كاش',
    'تحويل بنكي',
    'من الرصيد',
  ];

  /// إنشاء طلب لمورد واحد مع حفظ تفاصيل المنتجات.
  ///
  /// يفترض أن orders تحتوي على:
  /// customer_id, supplier_id, total_amount,
  /// status, payment_method.
  ///
  /// ويفترض أن order_items تحتوي على:
  /// order_id, product_id, quantity, unit_price, total_price.
  Future<int> createOrder({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? deliveryAddress,
    String? notes,
  }) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('يجب تحديد المورد.');
    }

    if (items.isEmpty) {
      throw ArgumentError('لا يمكن إنشاء طلب دون منتجات.');
    }

    if (!paymentMethods.contains(paymentMethod)) {
      throw ArgumentError('طريقة الدفع غير صحيحة.');
    }

    final client = _requireClient;

    final preparedItems = <Map<String, dynamic>>[];

    for (final item in items) {
      final productId = _toInt(item['product_id']);
      final quantity = _toInt(item['quantity']);
      final price = _toDouble(item['unit_price']);

      if (productId <= 0 || quantity <= 0 || price < 0) {
        throw ArgumentError('بيانات أحد المنتجات غير صحيحة.');
      }

      preparedItems.add({
        'product_id': productId,
        'quantity': quantity,
      });
    }

    final cleanAddress = _clean(deliveryAddress);
    if (cleanAddress == null) {
      throw ArgumentError('يجب تحديد عنوان التوصيل.');
    }

    final response = await client.rpc(
      'place_supplier_order',
      params: {
        'p_supplier_id': supplierId.trim(),
        'p_items': preparedItems,
        'p_payment_method': paymentMethod,
        'p_delivery_address': cleanAddress,
        'p_notes': _clean(notes),
      },
    );

    if (response is! Map) {
      throw StateError('لم تُرجع قاعدة البيانات بيانات الطلب بصورة صحيحة.');
    }

    return _toInt(response['id']);
  }

  /// جلب طلبات المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyOrders({
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _requireClient
        .from('orders')
        .select()
        .eq('customer_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب عناصر طلب معين.
  Future<List<Map<String, dynamic>>> getOrderItems(
    int orderId,
  ) async {
    final response = await _requireClient
        .from('order_items')
        .select()
        .eq('order_id', orderId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// إلغاء طلب ما زال في انتظار القبول.
  Future<void> cancelPendingOrder(int orderId) async {
    await _requireClient.rpc(
      'cancel_customer_order',
      params: {'p_order_id': orderId},
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _clean(String? value) {
    final result = value?.trim();
    if (result == null || result.isEmpty) return null;
    return result;
  }
}
