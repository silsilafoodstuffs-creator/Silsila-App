import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/services/cart_service.dart';
import 'package:silsila_app/services/checkout_service.dart';

CartItem _item({
  required String id,
  required double price,
  required int quantity,
  String supplierId = 'supplier-1',
}) {
  return CartItem(
    productId: id,
    name: 'منتج اختبار',
    supplierId: supplierId,
    category: 'مواد غذائية',
    unit: 'كرتونة',
    price: price,
    minQuantity: 1,
    quantity: quantity,
  );
}

void main() {
  group('CheckoutService.calculateTotal', () {
    final service = CheckoutService();

    test('returns zero for an empty checkout', () {
      expect(service.calculateTotal(const <CartItem>[]), 0);
    });

    test('sums line totals using quantity and decimal prices', () {
      final items = <CartItem>[
        _item(id: 'product-1', price: 12.50, quantity: 2),
        _item(id: 'product-2', price: 7.25, quantity: 3),
        _item(
          id: 'product-3',
          price: 100.00,
          quantity: 1,
          supplierId: 'supplier-2',
        ),
      ];

      expect(service.calculateTotal(items), closeTo(146.75, 0.000001));
    });

    test('handles a single item and its minimum quantity', () {
      final item = _item(id: 'product-uuid', price: 9.75, quantity: 4);
      expect(service.calculateTotal([item]), closeTo(39.00, 0.000001));
    });
  });
}
