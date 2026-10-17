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
  /// يتم احتساب الأسعار النهائية والتحقق منها داخل قاعدة البيانات.
  /// يفترض أن إجراء place_supplier_order يدعم المعاملات المرسلة أدناه.
  Future<int> createOrder({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? deliveryAddress,
    String? notes,
  }) async {
    final client = _requireClient;

    // التأكد من وجود مستخدم مسجل الدخول.
    _userId;

    final cleanSupplierId = supplierId.trim();

    if (cleanSupplierId.isEmpty) {
      throw ArgumentError('يجب تحديد المورد.');
    }

    if (items.isEmpty) {
      throw ArgumentError('لا يمكن إنشاء طلب دون منتجات.');
    }

    if (!paymentMethods.contains(paymentMethod.trim())) {
      throw ArgumentError('طريقة الدفع غير صحيحة.');
    }

    final cleanAddress = _clean(deliveryAddress);

    if (cleanAddress == null) {
      throw ArgumentError('يجب تحديد عنوان التوصيل.');
    }

    if (cleanAddress.length > 2000) {
      throw ArgumentError('عنوان التوصيل طويل أكثر من اللازم.');
    }

    if (notes != null && notes.trim().length > 2000) {
      throw ArgumentError('ملاحظات الطلب طويلة أكثر من اللازم.');
    }

    final preparedItems = <Map<String, dynamic>>[];
    final seenProducts = <int>{};

    for (final item in items) {
      final productId = _toInt(item['product_id']);
      final quantity = _toInt(item['quantity']);

      if (productId <= 0 || quantity <= 0) {
        throw ArgumentError('بيانات أحد المنتجات غير صحيحة.');
      }

      // منع تكرار المنتج نفسه في تفاصيل الطلب.
      if (!seenProducts.add(productId)) {
        throw ArgumentError(
          'يوجد منتج مكرر في الطلب. يرجى جمع كمياته أولًا.',
        );
      }

      preparedItems.add({
        'product_id': productId,
        'quantity': quantity,
      });
    }

    final response = await client.rpc(
      'place_supplier_order',
      params: {
        'p_supplier_id': cleanSupplierId,
        'p_items': preparedItems,
        'p_payment_method': paymentMethod.trim(),
        'p_delivery_address': cleanAddress,
        'p_notes': _clean(notes),
      },
    );

    final orderId = _extractOrderId(response);

    if (orderId <= 0) {
      throw StateError(
        'لم تُرجع قاعدة البيانات رقم طلب صالحًا.',
      );
    }

    return orderId;
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

  /// جلب عناصر طلب يملكه العميل الحالي فقط.
  Future<List<Map<String, dynamic>>> getOrderItems(
    int orderId,
  ) async {
    if (orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صالح.');
    }

    final client = _requireClient;

    final order = await client
        .from('orders')
        .select('id')
        .eq('id', orderId)
        .eq('customer_id', _userId)
        .maybeSingle();

    if (order == null) {
      throw StateError(
        'الطلب غير موجود أو لا تملك صلاحية الوصول إليه.',
      );
    }

    final response = await client
        .from('order_items')
        .select()
        .eq('order_id', orderId)
        .order('id');

    return List<Map<String, dynamic>>.from(response);
  }

  /// إلغاء طلب العميل عبر إجراء قاعدة البيانات الآمن.
  Future<void> cancelPendingOrder(int orderId) async {
    if (orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صالح.');
    }

    await _requireClient.rpc(
      'cancel_customer_order',
      params: {
        'p_order_id': orderId,
      },
    );
  }

  /// استخراج رقم الطلب من صيغ الاستجابة الشائعة.
  int _extractOrderId(dynamic response) {
    if (response is int) {
      return response;
    }

    if (response is num) {
      return response.toInt();
    }

    if (response is Map) {
      return _toInt(
        response['id'] ??
            response['order_id'] ??
            response['orderId'],
      );
    }

    if (response is List && response.isNotEmpty) {
      return _extractOrderId(response.first);
    }

    return 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _clean(String? value) {
    final result = value?.trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }
}
