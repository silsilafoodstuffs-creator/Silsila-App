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


    test('merges repeated additions of the same UUID product', () {
      const id = 'a8f6e4b2-2b2a-4e67-8e11-1f03e3b6b4c9';
      cart.addProduct(product(id: id), quantity: 2);
      cart.addProduct(product(id: id), quantity: 3);

      expect(cart.uniqueProductCount, 1);
      expect(cart.getItem(id)?.quantity, 5);
      expect(cart.subtotal, 62.5);
    });

    test('quantity changes respect the minimum order quantity', () {
      const id = 'a8f6e4b2-2b2a-4e67-8e11-1f03e3b6b4c9';
      cart.addProduct(product(id: id, minQuantity: 3));

      expect(cart.getItem(id)?.quantity, 3);
      expect(() => cart.setQuantity(id, 2), throwsArgumentError);
      cart.setQuantity(id, 7);
      expect(cart.getItem(id)?.quantity, 7);
      cart.decreaseQuantity(id);
      expect(cart.getItem(id)?.quantity, 6);
    });

    test('rejects a price change for an existing cart product', () {
      const id = 'a8f6e4b2-2b2a-4e67-8e11-1f03e3b6b4c9';
      cart.addProduct(product(id: id));
      expect(
        () => cart.addProduct(product(id: id, price: 13)),
        throwsStateError,
      );
      expect(cart.getItem(id)?.price, 12.5);
    });


    test('rejects negative and non-finite prices', () {
      expect(() => cart.addProduct(product(price: -1)), throwsArgumentError);
      expect(() => cart.addProduct(product(price: double.infinity)), throwsArgumentError);
      expect(() => cart.addProduct(product(price: double.nan)), throwsArgumentError);
    });

    test('rejects invalid minimum quantity', () {
      expect(() => cart.addProduct(product(minQuantity: 0)), throwsArgumentError);
      expect(
        () => cart.addProduct(
          product(minQuantity: CartService.maxQuantityPerProduct + 1),
        ),
        throwsArgumentError,
      );
    });

    test('does not merge the same product when its supplier changes', () {
      const id = 'a8f6e4b2-2b2a-4e67-8e11-1f03e3b6b4c9';
      cart.addProduct(product(id: id, supplierId: 'supplier-1'));
      expect(
        () => cart.addProduct(product(id: id, supplierId: 'supplier-2')),
        throwsStateError,
      );
      expect(cart.items.single.supplierId, 'supplier-1');
      expect(cart.items.single.quantity, 1);
    });

    test('groups cart totals by supplier', () {
      cart.addProduct(product(id: 'uuid-product-1', supplierId: 'supplier-1'), quantity: 2);
      cart.addProduct(product(id: 'uuid-product-2', supplierId: 'supplier-2'), quantity: 3);

      expect(cart.itemsBySupplier.keys.toSet(), {'supplier-1', 'supplier-2'});
      expect(cart.supplierProductCount('supplier-1'), 1);
      expect(cart.supplierItemCount('supplier-2'), 3);
      expect(cart.supplierSubtotal('supplier-1'), 25);
      expect(cart.supplierSubtotal('supplier-2'), 37.5);
    });

    test('clearing the cart removes every UUID item', () {
      cart.addProduct(product(id: 'uuid-product-1'));
      cart.addProduct(product(id: 'uuid-product-2'));
      cart.clear();

      expect(cart.isEmpty, isTrue);
      expect(cart.uniqueProductCount, 0);
      expect(cart.subtotal, 0);
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
