import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/services/cart_service.dart';

void main() {
  group('CartService validation', () {
    late CartService cart;

    setUp(() {
      cart = CartService();
    });

    tearDown(() {
      cart.dispose();
    });

    Map<String, dynamic> product({
      dynamic id = 1,
      dynamic supplierId = 'supplier-1',
      dynamic price = 12.5,
      dynamic minQuantity = 1,
      dynamic unit = 'كرتونة',
    }) {
      return {
        'id': id,
        'supplier_id': supplierId,
        'name': 'منتج تجريبي',
        'category': 'مواد غذائية',
        'unit': unit,
        'price': price,
        'min_quantity': minQuantity,
      };
    }

    test('rejects a missing or malformed price', () {
      expect(
        () => cart.addProduct(product(price: null)),
        throwsArgumentError,
      );
      expect(
        () => cart.addProduct(product(price: 'not-a-price')),
        throwsArgumentError,
      );
    });

    test('rejects a product without a supplier', () {
      expect(
        () => cart.addProduct(product(supplierId: '  ')),
        throwsArgumentError,
      );
    });

    test('rejects a product without a unit', () {
      expect(
        () => cart.addProduct(product(unit: '  ')),
        throwsArgumentError,
      );
    });

    test('starts at the product minimum quantity', () {
      cart.addProduct(product(minQuantity: 6));

      expect(cart.items.single.quantity, 6);
      expect(cart.subtotal, 75);
    });

    test('accepts UUID product IDs and preserves them in the cart', () {
      const id = 'a8f6e4b2-2b2a-4e67-8e11-1f03e3b6b4c9';
      cart.addProduct(product(id: id));

      expect(cart.items.single.productId, id);
      expect(cart.containsProduct(id), isTrue);
      expect(cart.getItem(id)?.name, 'منتج تجريبي');
      cart.increaseQuantity(id);
      expect(cart.getItem(id)?.quantity, 2);
      cart.removeProduct(id);
      expect(cart.isEmpty, isTrue);
    });

    test('rejects an empty product identifier', () {
      expect(() => cart.addProduct(product(id: '  ')), throwsArgumentError);
    });

    test('rejects quantities outside supported bounds', () {
      expect(
        () => cart.addProduct(product(), quantity: 0),
        throwsArgumentError,
      );
      expect(
        () => cart.addProduct(
          product(),
          quantity: CartService.maxQuantityPerProduct + 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
