import 'package:flutter/foundation.dart';

class CartItem {
  final int productId;
  final String name;
  final String supplierId;
  final String category;
  final String unit;
  final double price;
  final int minQuantity;
  final int quantity;

  const CartItem({
    required this.productId,
    required this.name,
    required this.supplierId,
    required this.category,
    required this.unit,
    required this.price,
    required this.minQuantity,
    required this.quantity,
  });

  double get total => price * quantity;

  CartItem copyWith({
    String? name,
    String? supplierId,
    String? category,
    String? unit,
    double? price,
    int? minQuantity,
    int? quantity,
  }) {
    return CartItem(
      productId: productId,
      name: name ?? this.name,
      supplierId: supplierId ?? this.supplierId,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      minQuantity: minQuantity ?? this.minQuantity,
      quantity: quantity ?? this.quantity,
    );
  }

  factory CartItem.fromProduct(
    Map<String, dynamic> product, {
    int quantity = 1,
  }) {
    return CartItem(
      productId: _toInt(product['id']),
      name: (product['name'] ?? '').toString().trim(),
      supplierId: (product['supplier_id'] ?? '').toString().trim(),
      category: (product['category'] ?? '').toString().trim(),
      unit: (product['unit'] ?? 'وحدة').toString().trim(),
      price: _toDouble(product['price']),
      minQuantity: _toInt(
        product['min_quantity'],
        fallback: 1,
      ),
      quantity: quantity,
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    final raw = value?.toString().trim() ?? '';

    if (raw.isEmpty) return double.nan;

    return double.tryParse(raw) ?? double.nan;
  }
}

class CartService extends ChangeNotifier {
  static const int maxQuantityPerProduct = 1000000;

  final Map<int, CartItem> _items = {};

  List<CartItem> get items =>
      List<CartItem>.unmodifiable(_items.values);

  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + item.total);

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  int get uniqueProductCount => _items.length;

  /// إضافة منتج جديد أو زيادة كمية منتج موجود.
  void addProduct(
    Map<String, dynamic> product, {
    int quantity = 1,
  }) {
    final newItem = CartItem.fromProduct(
      product,
      quantity: quantity,
    );

    if (newItem.productId <= 0) {
      throw ArgumentError('معرّف المنتج غير صالح.');
    }

    if (newItem.name.isEmpty) {
      throw ArgumentError('اسم المنتج مطلوب.');
    }

    if (newItem.supplierId.isEmpty) {
      throw ArgumentError(
        'يجب ربط المنتج بمورد صالح قبل إضافته إلى السلة.',
      );
    }

    if (newItem.unit.isEmpty) {
      throw ArgumentError('وحدة قياس المنتج مطلوبة.');
    }

    if (!newItem.price.isFinite || newItem.price < 0) {
      throw ArgumentError('سعر المنتج غير صالح.');
    }

    if (newItem.minQuantity < 1 ||
        newItem.minQuantity > maxQuantityPerProduct) {
      throw ArgumentError('الحد الأدنى لكمية المنتج غير صالح.');
    }

    if (quantity < 1 || quantity > maxQuantityPerProduct) {
      throw ArgumentError(
        'الكمية يجب أن تكون بين 1 والحد الأقصى المسموح.',
      );
    }

    final existing = _items[newItem.productId];

    if (existing == null) {
      final initialQuantity = quantity < newItem.minQuantity
          ? newItem.minQuantity
          : quantity;

      _validateLineTotal(newItem.price, initialQuantity);

      _items[newItem.productId] = newItem.copyWith(
        quantity: initialQuantity,
      );
    } else {
      if (existing.supplierId != newItem.supplierId) {
        throw StateError(
          'تغيّر المورد المرتبط بهذا المنتج. '
          'احذف المنتج من السلة وأضفه من جديد.',
        );
      }

      if (existing.price != newItem.price ||
          existing.minQuantity != newItem.minQuantity) {
        throw StateError(
          'تغيّر سعر المنتج أو الحد الأدنى للطلب. '
          'احذف المنتج من السلة وأضفه من جديد لتحديث بياناته.',
        );
      }

      final nextQuantity = existing.quantity + quantity;

      if (nextQuantity > maxQuantityPerProduct) {
        throw ArgumentError(
          'تجاوزت الحد الأقصى لكمية هذا المنتج.',
        );
      }

      _validateLineTotal(existing.price, nextQuantity);

      _items[newItem.productId] = existing.copyWith(
        quantity: nextQuantity,
      );
    }

    notifyListeners();
  }

  /// تعيين كمية المنتج مع احترام الحد الأدنى للطلب.
  void setQuantity(int productId, int quantity) {
    final existing = _items[productId];

    if (existing == null) return;

    if (quantity < existing.minQuantity) {
      throw ArgumentError(
        'الحد الأدنى للطلب هو ${existing.minQuantity}.',
      );
    }

    if (quantity > maxQuantityPerProduct) {
      throw ArgumentError(
        'تجاوزت الحد الأقصى لكمية هذا المنتج.',
      );
    }

    if (quantity == existing.quantity) return;

    _validateLineTotal(existing.price, quantity);

    _items[productId] = existing.copyWith(
      quantity: quantity,
    );

    notifyListeners();
  }

  /// زيادة كمية منتج موجود.
  void increaseQuantity(int productId) {
    final existing = _items[productId];

    if (existing == null) return;

    if (existing.quantity >= maxQuantityPerProduct) {
      throw ArgumentError(
        'تجاوزت الحد الأقصى لكمية هذا المنتج.',
      );
    }

    final nextQuantity = existing.quantity + 1;
    _validateLineTotal(existing.price, nextQuantity);

    _items[productId] = existing.copyWith(
      quantity: nextQuantity,
    );

    notifyListeners();
  }

  /// تقليل الكمية دون النزول عن الحد الأدنى.
  void decreaseQuantity(int productId) {
    final existing = _items[productId];

    if (existing == null) return;

    if (existing.quantity <= existing.minQuantity) return;

    _items[productId] = existing.copyWith(
      quantity: existing.quantity - 1,
    );

    notifyListeners();
  }

  /// حذف منتج من السلة.
  void removeProduct(int productId) {
    if (_items.remove(productId) != null) {
      notifyListeners();
    }
  }

  /// إفراغ السلة بالكامل.
  void clear() {
    if (_items.isEmpty) return;

    _items.clear();
    notifyListeners();
  }

  /// منع تجاوز إجمالي السطر لقيمة رقمية قابلة للتمثيل.
  void _validateLineTotal(double price, int quantity) {
    final total = price * quantity;

    if (!total.isFinite) {
      throw ArgumentError(
        'إجمالي المنتج أكبر من القيمة التي يمكن حسابها بأمان.',
      );
    }
  }

  /// التحقق من وجود منتج في السلة.
  bool containsProduct(int productId) {
    return _items.containsKey(productId);
  }

  /// الحصول على منتج محدد من السلة.
  CartItem? getItem(int productId) {
    return _items[productId];
  }

  /// تقسيم عناصر السلة حسب المورد.
  Map<String, List<CartItem>> get itemsBySupplier {
    final result = <String, List<CartItem>>{};

    for (final item in _items.values) {
      result.putIfAbsent(item.supplierId, () => []).add(item);
    }

    return Map<String, List<CartItem>>.unmodifiable(
      result.map(
        (key, value) => MapEntry(
          key,
          List<CartItem>.unmodifiable(value),
        ),
      ),
    );
  }

  /// عدد المنتجات المختلفة التابعة لمورد معين.
  int supplierProductCount(String supplierId) {
    return _items.values
        .where((item) => item.supplierId == supplierId)
        .length;
  }

  /// إجمالي عدد الوحدات التابعة لمورد معين.
  int supplierItemCount(String supplierId) {
    return _items.values
        .where((item) => item.supplierId == supplierId)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  /// حساب إجمالي منتجات مورد معين.
  double supplierSubtotal(String supplierId) {
    return _items.values
        .where((item) => item.supplierId == supplierId)
        .fold(0.0, (sum, item) => sum + item.total);
  }
}
