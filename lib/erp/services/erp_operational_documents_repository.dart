import 'package:supabase_flutter/supabase_flutter.dart';

enum ErpOperationalKind { purchase, sales }

class ErpOperationalDocumentsRepository {
  ErpOperationalDocumentsRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول إلى المستندات.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchDocuments({
    required String companyId,
    required ErpOperationalKind kind,
  }) async {
    final table = kind == ErpOperationalKind.purchase
      ? 'erp_purchase_documents' : 'erp_sales_documents';
    final rows = await _db.from(table)
      .select('id, company_id, branch_id, warehouse_id, document_number, document_date, document_type, status, subtotal, discount_total, tax_total, grand_total, paid_total, notes')
      .eq('company_id', companyId.trim())
      .order('document_date', ascending: false)
      .limit(300);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchParties(String companyId, ErpOperationalKind kind) async {
    final rows = await _db.from('erp_parties')
      .select('id, party_code, party_name, party_kind')
      .eq('company_id', companyId.trim()).eq('is_active', true)
      .inFilter('party_kind', kind == ErpOperationalKind.purchase ? ['supplier','both'] : ['customer','both'])
      .order('party_name').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses(String companyId) async {
    final rows = await _db.from('erp_warehouses')
      .select('id, warehouse_code, warehouse_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('warehouse_name');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchItems(String companyId) async {
    final rows = await _db.from('erp_items')
      .select('id, item_code, item_name, base_unit, purchase_price, sale_price')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('item_name').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<String> createDraft({
    required String companyId,
    required ErpOperationalKind kind,
    required String documentNumber,
    required String documentType,
    required String partyId,
    required String warehouseId,
    String? notes,
  }) async {
    if (documentNumber.trim().isEmpty || partyId.isEmpty || warehouseId.isEmpty) {
      throw ArgumentError('رقم المستند والطرف والمخزن حقول إلزامية.');
    }
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'warehouse_id': warehouseId,
      'document_number': documentNumber.trim(),
      'document_date': DateTime.now().toIso8601String().substring(0, 10),
      'document_type': documentType,
      'status': 'draft',
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'subtotal': 0,
      'discount_total': 0,
      'tax_total': 0,
      'grand_total': 0,
      'paid_total': 0,
    };
    if (kind == ErpOperationalKind.purchase) {
      payload['supplier_id'] = partyId;
      final row = await _db.from('erp_purchase_documents').insert(payload).select('id').single();
      return row['id'].toString();
    } else {
      payload['customer_id'] = partyId;
      final row = await _db.from('erp_sales_documents').insert(payload).select('id').single();
      return row['id'].toString();
    }
  }

  Future<void> addLine({
    required String documentId,
    required ErpOperationalKind kind,
    required String itemId,
    required double quantity,
    required double unitPrice,
    double discount = 0,
    double tax = 0,
  }) async {
    final gross = quantity * unitPrice;
    if (itemId.isEmpty || quantity <= 0 || unitPrice < 0 || discount < 0 || tax < 0 || discount > gross) {
      throw ArgumentError('راجع الصنف والكمية والسعر والخصم والضريبة.');
    }
    final total = gross - discount + tax;
    final payload = <String, dynamic>{
      'document_id': documentId, 'item_id': itemId, 'quantity': quantity,
      'unit_price': unitPrice, 'discount_amount': discount, 'tax_amount': tax,
      'line_total': total,
    };
    final table = kind == ErpOperationalKind.purchase ? 'erp_purchase_lines' : 'erp_sales_lines';
    await _db.from(table).insert(payload);
    final headerTable = kind == ErpOperationalKind.purchase ? 'erp_purchase_documents' : 'erp_sales_documents';
    final lines = await _db.from(table).select('quantity, unit_price, discount_amount, tax_amount')
      .eq('document_id', documentId);
    var subtotal = 0.0;
    var discounts = 0.0;
    var taxes = 0.0;
    for (final line in lines) {
      final q = _num(line['quantity']);
      subtotal += q * _num(line['unit_price']);
      discounts += _num(line['discount_amount']);
      taxes += _num(line['tax_amount']);
    }
    await _db.from(headerTable).update({
      'subtotal': subtotal,
      'discount_total': discounts,
      'tax_total': taxes,
      'grand_total': subtotal - discounts + taxes,
    }).eq('id', documentId).eq('status', 'draft');
  }

  static double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse((value ?? '0').toString()) ?? 0;

  Future<void> postDocument(String id, ErpOperationalKind kind) async {
    final function = kind == ErpOperationalKind.purchase
      ? 'erp_post_purchase_document' : 'erp_post_sales_document';
    await _db.rpc(function, params: {'p_document_id': id});
  }
}
