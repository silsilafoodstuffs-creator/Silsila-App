import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// التحقق من بيانات الطلب قبل الإرسال.
  void validateCheckout({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String deliveryAddress,
  }) {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('يجب تحديد المورد.');
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
      final productId = item['product_id'];
      final quantity = item['quantity'];
      final price = item['unit_price'];

      if (productId == null ||
          quantity is! num ||
          price is! num ||
          quantity <= 0 ||
          price < 0) {
        throw ArgumentError('توجد بيانات غير صحيحة في أحد المنتجات.');
      }
    }
  }

  /// حساب إجمالي الطلب.
  double calculateTotal(List<Map<String, dynamic>> items) {
    var total = 0.0;

    for (final item in items) {
      final quantity = item['quantity'] as num;
      final price = item['unit_price'] as num;

      total += quantity * price;
    }

    return total;
  }

  /// إنشاء طلب لمورد واحد مع عناصره.
  ///
  /// ملاحظة: يجب مراجعة أسماء الأعمدة وأنواع المعرّفات
  /// مع مخطط قاعدة البيانات قبل استخدام هذه الدالة.
  Future<Map<String, dynamic>> checkout({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String deliveryAddress,
    String? notes,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('يجب تسجيل الدخول قبل إتمام الطلب.');
    }

    validateCheckout(
      supplierId: supplierId,
      items: items,
      paymentMethod: paymentMethod,
      deliveryAddress: deliveryAddress,
    );

    final total = calculateTotal(items);

    // إنشاء الطلب الرئيسي.
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
      // تجهيز عناصر الطلب.
      final orderItems = items.map((item) {
        final quantity = item['quantity'] as num;
        final unitPrice = item['unit_price'] as num;

        return {
          'order_id': orderId,
          'product_id': item['product_id'],
          'quantity': quantity,
          'unit_price': unitPrice,
          'total_price': quantity * unitPrice,
        };
      }).toList();

      await _client.from('order_items').insert(orderItems);

      return order;
    } catch (_) {
      // محاولة تنظيف الطلب إذا فشل إدخال عناصره.
      // الأفضل لاحقًا تنفيذ العملية كلها داخل RPC
      // لضمان المعاملة الذرية في قاعدة البيانات.
      try {
        await _client
            .from('orders')
            .delete()
            .eq('id', orderId)
            .eq('customer_id', user.id);
      } catch (_) {
        // لا نخفي الخطأ الأصلي إذا فشل التنظيف.
      }

      rethrow;
    }
  }
}
