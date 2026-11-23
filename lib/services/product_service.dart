import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  ProductService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client != null) {
      return client;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'اتصال Supabase غير متاح. يرجى المحاولة لاحقًا.',
      );
    }
  }

  static const String _productColumns =
      'id, supplier_id, name, category, category_id, '
      'description, price, unit, min_quantity, minimum_quantity, '
      'activity_type, is_active, image_url, subcategory, brand, '
      'package_count, small_unit, offer_price, image_data, image_mime_type, created_at';

  /// جلب المنتجات النشطة مع إمكانية التصفية.
  Future<List<Map<String, dynamic>>> getProducts({
    String? activityType,
    String? category,
    int? categoryId,
    String? supplierId,
    String? search,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    if (categoryId != null && categoryId <= 0) {
      throw ArgumentError('رقم القسم غير صالح.');
    }

    final cleanActivityType = _clean(activityType);
    final cleanCategory = _clean(category);
    final cleanSupplierId = _clean(supplierId);
    final cleanSearch = _clean(search);

    if (cleanActivityType != null && cleanActivityType.length > 100) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
    }

    if (cleanCategory != null && cleanCategory.length > 150) {
      throw ArgumentError('اسم القسم طويل أكثر من اللازم.');
    }

    if (cleanSupplierId != null && cleanSupplierId.length > 200) {
      throw ArgumentError('معرّف المورد طويل أكثر من اللازم.');
    }

    if (cleanSearch != null && cleanSearch.length > 150) {
      throw ArgumentError('عبارة البحث طويلة أكثر من اللازم.');
    }

    var query = _requireClient
        .from('products')
        .select(_productColumns)
        .eq('is_active', true);

    // Apply filters before ordering and limiting so matching products are not
    // accidentally omitted when earlier rows do not match the selected filters.
    if (cleanActivityType != null) {
      query = query.eq('activity_type', cleanActivityType);
    }
    if (cleanCategory != null) {
      query = query.eq('category', cleanCategory);
    }
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (cleanSupplierId != null) {
      query = query.eq('supplier_id', cleanSupplierId);
    }
    if (cleanSearch != null) {
      query = query.ilike('name', '%${_escapeLike(cleanSearch)}%');
    }

    final response = await query
        .order('name', ascending: true)
        .limit(limit);
    final marketplaceRows = _mapRows(response);
    try {
      final masterRows = await _getErpMasterProducts(
        activityType: cleanActivityType,
        category: cleanCategory,
        search: cleanSearch,
        enabled: supplierId == null && categoryId == null,
      );
      final merged = _mergeMasterCatalog(marketplaceRows, masterRows, limit);
      await _attachErpMasterImages(merged);
      return merged;
    } catch (_) {
      // Existing supplier listings remain available if ERP catalog access is
      // temporarily unavailable or the shared-catalog migration is pending.
      return marketplaceRows;
    }
  }

  Future<List<Map<String, dynamic>>> _getErpMasterProducts({
    required String? activityType,
    required String? category,
    required String? search,
    required bool enabled,
  }) async {
    if (!enabled) return const <Map<String, dynamic>>[];
    final db = _requireClient;
    String? activityCode;
    if (activityType != null) {
      final activityRow = await db.from('activity_types')
          .select('code')
          .eq('name', activityType)
          .eq('is_active', true)
          .maybeSingle();
      activityCode = _normalizeActivityCode(
        activityRow?['code']?.toString() ?? activityType,
      );
    }

    var categoryQuery = db.from('erp_item_categories')
        .select('id,parent_id,category_name:category_name,category_name_en:category_name_en,activity_code')
        .eq('is_active', true)
        .eq('show_in_app', true);
    if (activityCode != null && activityCode.isNotEmpty) {
      categoryQuery = categoryQuery.eq('activity_code', activityCode);
    }
    final categoryRows = await categoryQuery.order('category_name').limit(3000);
    final categories = (categoryRows as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList(growable: false);
    if (categories.isEmpty) return const <Map<String, dynamic>>[];
    final categoriesById = <String, Map<String, dynamic>>{
      for (final category in categories) (category['id'] ?? '').toString(): category,
    };

    List<Map<String, dynamic>> categoryPath(Map<String, dynamic> leaf) {
      final path = <Map<String, dynamic>>[leaf];
      var current = leaf;
      var parentId = current['parent_id']?.toString();
      var guard = 0;
      while (parentId != null && parentId.isNotEmpty && guard++ < 4) {
        final parent = categoriesById[parentId];
        if (parent == null) break;
        path.insert(0, parent);
        current = parent;
        parentId = current['parent_id']?.toString();
      }
      return path;
    }

    // The database's public-catalog RLS policy already restricts rows to active,
    // app-visible items in active, app-visible categories. Do not add a client-side
    // IN filter based on the category query: category visibility and pagination can
    // differ, and that filter silently drops otherwise valid item rows.
    var itemQuery = db.from('erp_items')
        .select('id,category_id:category_id,item_code,item_name,base_unit,sale_price,is_active,show_in_app,brand_name,package_description')
        .eq('is_active', true)
        .eq('show_in_app', true);
    if (search != null) itemQuery = itemQuery.ilike('item_name', '%${_escapeLike(search)}%');
    final itemRows = await itemQuery.order('item_name').limit(500);
    final results = <Map<String, dynamic>>[];
    for (final raw in (itemRows as List)) {
      final item = Map<String, dynamic>.from(raw as Map);
      final itemCategory = categoriesById[(item['category_id'] ?? '').toString()];
      // Keep the item visible even if its category row is temporarily hidden or
      // missing from the category response. Missing category metadata must never
      // make the product (and its stored image) disappear from the catalog.
      final path = itemCategory == null ? <Map<String, dynamic>>[] : categoryPath(itemCategory);
      final categoryName = (itemCategory?['category_name'] ?? 'غير مصنف').toString();
      final rootName = path.isEmpty ? categoryName : (path.first['category_name'] ?? categoryName).toString();
      if (category != null &&
          (itemCategory == null || (category != rootName && category != categoryName &&
          !path.any((node) => (node['category_name'] ?? '').toString() == category)))) {
        continue;
      }
      final subcategoryName = path.length > 1 ? (path[1]['category_name'] ?? '').toString() : '';
      results.add(<String, dynamic>{
        'id': item['id'],
        'supplier_id': null,
        'name': item['item_name'],
        'category': rootName,
        'category_id': null,
        'description': item['package_description'],
        'price': item['sale_price'],
        'unit': item['base_unit'] ?? 'وحدة',
        'min_quantity': 1,
        'minimum_quantity': 1,
        'activity_type': activityType,
        'is_active': item['is_active'],
        'image_url': null,
        'subcategory': subcategoryName.isEmpty ? null : subcategoryName,
        'brand': item['brand_name'],
        'package_count': 1,
        'small_unit': null,
        'offer_price': null,
        'image_data': null,
        'image_mime_type': null,
        // Binary image data is fetched only for the final, visible result page.
        '_erp_master_item_id': item['id'],
      });
    }
    return results;
  }

  List<Map<String, dynamic>> _mergeMasterCatalog(
    List<Map<String, dynamic>> marketplaceRows,
    List<Map<String, dynamic>> masterRows,
    int limit,
  ) {
    final merged = <Map<String, dynamic>>[];
    final marketplaceByName = <String, int>{};
    String normalize(dynamic value) => (value ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    for (final row in marketplaceRows) {
      final copy = Map<String, dynamic>.from(row);
      final key = normalize(copy['name']);
      if (key.isNotEmpty) marketplaceByName[key] = merged.length;
      merged.add(copy);
    }
    for (final master in masterRows) {
      final key = normalize(master['name']);
      if (key.isEmpty) continue;
      final existingIndex = marketplaceByName[key];
      if (existingIndex != null) {
        final existing = merged[existingIndex];
        existing['_erp_master_item_id'] = master['_erp_master_item_id'];
        if ((master['category'] ?? '').toString().isNotEmpty) existing['category'] = master['category'];
        if ((master['brand'] ?? '').toString().isNotEmpty) existing['brand'] = master['brand'];
        if ((master['subcategory'] ?? '').toString().isNotEmpty) existing['subcategory'] = master['subcategory'];
        continue;
      }
      marketplaceByName[key] = merged.length;
      merged.add(Map<String, dynamic>.from(master));
    }
    merged.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return merged.take(limit).toList(growable: true);
  }

  /// Fetch ERP image bytes only for products that survive catalog filtering,
  /// sorting, and page limiting. This avoids transferring every image in the
  /// 500-row metadata window on each catalog request.
  Future<void> _attachErpMasterImages(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = rows
        .map((row) => row['_erp_master_item_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    for (final row in rows) {
      row.remove('_erp_master_item_id');
    }
    if (ids.isEmpty) return;

    try {
      final imageRows = await _requireClient
          .from('erp_items')
          .select('id,image_data,image_mime_type')
          .inFilter('id', ids);
      final imagesById = <String, Map<String, dynamic>>{
        for (final raw in imageRows.whereType<Map>())
          raw['id'].toString(): Map<String, dynamic>.from(raw),
      };
      for (final row in rows) {
        final image = imagesById[row['id']?.toString()];
        final imageData = image?['image_data'];
        if (imageData != null && imageData.toString().isNotEmpty) {
          row['image_data'] = imageData;
          row['image_mime_type'] = image?['image_mime_type'];
          row['image_url'] = null;
        }
      }
    } catch (_) {
      // Catalog metadata remains usable if optional image retrieval fails.
    }
  }

  /// جلب تفاصيل منتج نشط باستخدام رقمه.
  Future<Map<String, dynamic>?> getProductById(
    String productId,
  ) async {
    final cleanProductId = productId.trim();
    if (cleanProductId.isEmpty) {
      throw ArgumentError('معرّف المنتج غير صالح.');
    }

    final response = await _requireClient
        .from('products')
        .select(_productColumns)
        .eq('id', cleanProductId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  /// جلب المنتجات النشطة التابعة لمورد محدد.
  Future<List<Map<String, dynamic>>> getSupplierProducts(
    String supplierId, {
    String? activityType,
    int limit = 100,
  }) async {
    final cleanSupplierId = _clean(supplierId);

    if (cleanSupplierId == null) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    if (cleanSupplierId.length > 200) {
      throw ArgumentError('معرّف المورد طويل أكثر من اللازم.');
    }

    return getProducts(
      supplierId: cleanSupplierId,
      activityType: activityType,
      limit: limit,
    );
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 500) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و500.');
    }
  }

  String _escapeLike(String value) {
    // Escape PostgreSQL LIKE metacharacters as single-character escapes.
    // Backslash must be escaped first so later replacements remain literal.
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }

  String? _normalizeActivityCode(String? value) {
    final clean = value?.trim().toUpperCase();
    if (clean == null || clean.isEmpty) return null;
    final legacy = RegExp(r'^ACT([0-9]{3})$').firstMatch(clean);
    if (legacy != null) {
      final number = int.tryParse(legacy.group(1)!);
      return number == null ? clean : number.toString().padLeft(2, '0');
    }
    if (RegExp(r'^[0-9]{1,2}$').hasMatch(clean)) {
      return int.parse(clean).toString().padLeft(2, '0');
    }
    const aliases = <String, String>{
      'FOOD': '01', 'مواد غذائية': '01', 'FOODSTUFFS': '01',
      'BUILDING': '02', 'لوازم بناء': '02',
      'CLOTHING': '03', 'ملابس واكسسوارات': '03',
      'ELECTRONICS': '04', 'أجهزة وإلكترونيات': '04',
      'VEHICLES': '05', 'سيارات ومعدات': '05',
      'SHIPPING': '06', 'خدمات شحن ونقل': '06',
      'FURNITURE': '07', 'أثاث وديكورات': '07',
    };
    return aliases[clean] ?? clean;
  }

  String? _clean(String? value) {
    final result = value?.trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }

  List<Map<String, dynamic>> _mapRows(dynamic response) {
    if (response is! List) {
      throw StateError('تعذر قراءة قائمة المنتجات.');
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
