/// Safe, explicit allow-list for read-only Studio data bindings.
/// Never accept table or column names supplied by an imported design.
class StudioDataSource {
  const StudioDataSource({
    required this.key,
    required this.label,
    required this.table,
    required this.columns,
    this.excludeDemo = false,
  });

  final String key;
  final String label;
  final String table;
  final List<String> columns;
  final bool excludeDemo;

  String get select => columns.join(',');
}

class StudioDataSources {
  static const all = <StudioDataSource>[
    StudioDataSource(
      key: 'items',
      label: 'الأصناف',
      table: 'erp_items',
      columns: ['id', 'item_code', 'item_name', 'base_unit', 'sale_price', 'purchase_price', 'is_active', 'brand_name'],
      excludeDemo: true,
    ),
    StudioDataSource(
      key: 'brands',
      label: 'البراندات',
      table: 'erp_brands',
      columns: ['id', 'brand_code', 'brand_name', 'is_active', 'brand_group'],
    ),
    StudioDataSource(
      key: 'categories',
      label: 'فئات الأصناف',
      table: 'erp_item_categories',
      columns: ['id', 'category_code', 'category_name', 'is_active', 'parent_id'],
    ),
    StudioDataSource(
      key: 'warehouses',
      label: 'المخازن',
      table: 'erp_warehouses',
      columns: ['id', 'warehouse_code', 'warehouse_name', 'address', 'is_active'],
    ),
    StudioDataSource(
      key: 'sales_documents',
      label: 'مستندات المبيعات',
      table: 'erp_sales_documents',
      columns: ['id', 'document_number', 'document_date', 'document_type', 'status', 'grand_total', 'paid_total'],
      excludeDemo: true,
    ),
    StudioDataSource(
      key: 'purchase_documents',
      label: 'مستندات المشتريات',
      table: 'erp_purchase_documents',
      columns: ['id', 'document_number', 'document_date', 'document_type', 'status', 'grand_total', 'paid_total'],
      excludeDemo: true,
    ),
    StudioDataSource(
      key: 'stock_balances',
      label: 'أرصدة المخزون',
      table: 'erp_stock_balances',
      columns: ['warehouse_id', 'item_id', 'quantity_on_hand', 'today_quantity_in', 'today_quantity_out', 'inventory_value', 'average_unit_cost'],
    ),
  ];

  static StudioDataSource byKey(String key) {
    return all.firstWhere(
      (source) => source.key == key,
      orElse: () => throw ArgumentError('مصدر البيانات غير مسجل: $key'),
    );
  }
}
