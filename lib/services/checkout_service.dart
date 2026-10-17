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

  /// إنشاء طلب مستقل لكل مورد في السلة.
  ///
  /// يفترض هذا الكود أن:
  /// orders يحتوي على customer_id و supplier_id و total_amount
  /// و status و payment_method و delivery_address و notes.
  ///
  /// ويفترض أن order_items يحتوي على order_id و product_id
  /// و quantity و unit_price و total_price.
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

    final user = _client.auth.currentUser!;

    final groupedItems = <String, List<CartItem>>{};

    for (final item in items) {
      groupedItems
          .putIfAbsent(item.supplierId, () => [])
          .add(item);
    }

    final createdOrders = <Map<String, dynamic>>[];

    for (final entry in groupedItems.entries) {
      final supplierId = entry.key;
      final supplierItems = entry.value;

      // يتم حساب الأسعار والتحقق منها داخل PostgreSQL؛
      // لا نرسل سعر العميل باعتباره مصدرًا موثوقًا.
      final response = await _client.rpc(
        'place_supplier_order',
        params: {
          'p_supplier_id': supplierId,
          'p_items': supplierItems
              .map((item) => {
                    'product_id': item.productId,
                    'quantity': item.quantity,
                  })
              .toList(),
          'p_payment_method': paymentMethod,
          'p_delivery_address': deliveryAddress.trim(),
          'p_notes': notes?.trim(),
        },
      );

      if (response is Map) {
        createdOrders.add(Map<String, dynamic>.from(response));
      } else {
        throw StateError('لم تُرجع قاعدة البيانات بيانات الطلب بصورة صحيحة.');
      }
    }

    return createdOrders;
  }
}
