import 'package:supabase_flutter/supabase_flutter.dart';

import 'cart_service.dart';

class CheckoutService {
  CheckoutService({SupabaseClient? client})
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

  static const List<String> supportedPaymentMethods = [
    'cash',
    'supplier_credit',
    'wallet',
    'bank_transfer',
    'account_balance',
  ];

  /// التحقق من بيانات الطلب قبل إرساله.
  void validateCheckout({
    required List<CartItem> items,
    required String paymentMethod,
    required String deliveryAddress,
  }) {
    if (_requireClient.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول قبل إتمام الطلب.');
    }

    if (items.isEmpty) {
      throw ArgumentError('السلة فارغة.');
    }

    if (!supportedPaymentMethods.contains(paymentMethod)) {
      throw ArgumentError('طريقة الدفع غير مدعومة.');
    }

    final cleanAddress = deliveryAddress.trim();

    if (cleanAddress.isEmpty) {
      throw ArgumentError('يجب تحديد عنوان التوصيل.');
    }

    if (cleanAddress.length > 2000) {
      throw ArgumentError('عنوان التوصيل طويل أكثر من اللازم.');
    }

    for (final item in items) {
      if (item.productId.trim().isEmpty || item.productId == '0' ||
          item.supplierId.trim().isEmpty ||
          item.name.trim().isEmpty ||
          item.unit.trim().isEmpty ||
          item.minQuantity < 1 ||
          item.quantity < item.minQuantity ||
          item.quantity > CartService.maxQuantityPerProduct ||
          !item.price.isFinite ||
          item.price < 0 ||
          !item.total.isFinite ||
          item.total < 0) {
        throw ArgumentError(
          'توجد بيانات غير صحيحة في المنتج: ${item.name}.',
        );
      }
    }

    final total = calculateTotal(items);

    if (!total.isFinite || total < 0) {
      throw ArgumentError('إجمالي الطلب غير صالح.');
    }
  }

  /// حساب إجمالي عناصر السلة.
  double calculateTotal(List<CartItem> items) {
    return items.fold<double>(
      0,
      (total, item) => total + item.total,
    );
  }

  /// تحويل طريقة الدفع إلى التسمية المستخدمة في قاعدة البيانات.
  String _toDatabasePaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'نقدي';
      case 'supplier_credit':
        return 'آجل مورد';
      case 'wallet':
        return 'محفظة كاش';
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'account_balance':
        return 'من الرصيد';
      default:
        throw ArgumentError('طريقة الدفع غير مدعومة.');
    }
  }

  /// إنشاء طلبات الموردين من خلال إجراء قاعدة البيانات.
  ///
  /// يجب أن يتولى الإجراء place_multi_supplier_checkout
  /// معالجة الطلبات بصورة ذرية داخل قاعدة البيانات.
  Future<List<Map<String, dynamic>>> checkout({
    required List<CartItem> items,
    required String paymentMethod,
    required String deliveryAddress,
    String? notes,
  }) async {
    validateCheckout(
      items: items,
      paymentMethod: paymentMethod,
      deliveryAddress: deliveryAddress,
    );

    final cleanNotes = notes?.trim();

    if (cleanNotes != null && cleanNotes.length > 2000) {
      throw ArgumentError('ملاحظات الطلب يجب ألا تتجاوز 2000 حرف.');
    }

    final response = await _requireClient.rpc(
      'place_multi_supplier_checkout',
      params: {
        'p_items': items
            .map(
              (item) => {
                'supplier_id': item.supplierId,
                'product_id': item.productId,
                'quantity': item.quantity,
              },
            )
            .toList(),
        'p_payment_method':
            _toDatabasePaymentMethod(paymentMethod),
        'p_delivery_address': deliveryAddress.trim(),
        'p_notes': cleanNotes == null || cleanNotes.isEmpty
            ? null
            : cleanNotes,
      },
    );

    if (response is List) {
      return response.map((row) {
        if (row is! Map) {
          throw StateError('صيغة بيانات الطلب غير صحيحة.');
        }

        return Map<String, dynamic>.from(row);
      }).toList();
    }

    if (response is Map && response['orders'] is List) {
      return (response['orders'] as List).map((row) {
        if (row is! Map) {
          throw StateError('صيغة بيانات الطلب غير صحيحة.');
        }

        return Map<String, dynamic>.from(row);
      }).toList();
    }

    throw StateError(
      'لم تُرجع قاعدة البيانات قائمة الطلبات بصورة صحيحة.',
    );
  }
}
