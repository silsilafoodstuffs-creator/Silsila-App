import 'package:supabase_flutter/supabase_flutter.dart';

import 'cart_service.dart';

class CheckoutService {
  CheckoutService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
    if (_client.auth.currentUser == null) {
      throw Exception('يجب تسجيل الدخول قبل إتمام الطلب.');
    }

    if (items.isEmpty) {
      throw ArgumentError('السلة فارغة.');
    }

    if (!supportedPaymentMethods.contains(paymentMethod)) {
      throw ArgumentError('طريقة الدفع غير مدعومة.');
    }

    if (deliveryAddress.trim().isEmpty) {
      throw ArgumentError('يجب تحديد عنوان التوصيل.');
    }

    for (final item in items) {
      if (item.productId <= 0 ||
          item.supplierId.trim().isEmpty ||
          item.name.trim().isEmpty ||
          item.quantity < item.minQuantity ||
          item.minQuantity < 1 ||
          item.price < 0) {
        throw ArgumentError(
          'توجد بيانات غير صحيحة في المنتج: ${item.name}.',
        );
      }
    }
  }

  /// حساب إجمالي عناصر السلة.
  double calculateTotal(List<CartItem> items) {
    return items.fold<double>(
      0,
      (total, item) => total + item.total,
    );
  }

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

  /// إنشاء طلبات الموردين في معاملة واحدة؛ تفشل السلة كاملة إذا تعذر أي جزء.
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

    final response = await _client.rpc(
      'place_multi_supplier_checkout',
      params: {
        'p_items': items
            .map((item) => {
                  'supplier_id': item.supplierId,
                  'product_id': item.productId,
                  'quantity': item.quantity,
                })
            .toList(),
        'p_payment_method': _toDatabasePaymentMethod(paymentMethod),
        'p_delivery_address': deliveryAddress.trim(),
        'p_notes': notes?.trim(),
      },
    );

    if (response is List) {
      return response
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    }

    if (response is Map && response['orders'] is List) {
      return (response['orders'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    }

    throw StateError('لم تُرجع قاعدة البيانات قائمة الطلبات بصورة صحيحة.');
  }
}
