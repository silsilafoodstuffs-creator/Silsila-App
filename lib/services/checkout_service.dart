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
      final total = calculateTotal(supplierItems);

      final order = await _client
          .from('orders')
          .insert({
            'customer_id': user.id,
            'supplier_id': supplierId,
            'total_amount': total,
            'status': 'pending',
            'payment_method': paymentMethod,
            'delivery_address': deliveryAddress.trim(),
            'notes': notes?.trim(),
          })
          .select()
          .single();

      final orderId = order['id'];

      try {
        final orderItems = supplierItems.map((item) {
          return {
            'order_id': orderId,
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.price,
            'total_price': item.total,
          };
        }).toList();

        await _client
            .from('order_items')
            .insert(orderItems);

        createdOrders.add(order);
      } catch (_) {
        // حذف الطلب الحالي إذا تعذر حفظ تفاصيله.
        // يتطلب ذلك أن تسمح سياسات قاعدة البيانات بالحذف.
        try {
          await _client
              .from('orders')
              .delete()
              .eq('id', orderId)
              .eq('customer_id', user.id);
        } catch (_) {
          // الاحتفاظ بالخطأ الأصلي.
        }

        rethrow;
      }
    }

    return createdOrders;
  }
}
