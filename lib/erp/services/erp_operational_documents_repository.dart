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
    final columns = kind == ErpOperationalKind.purchase
      ? 'id, company_id, branch_id, warehouse_id, supplier_id, customer_id, auto_number, document_number, document_date, document_timestamp, document_type, status, subtotal, discount_total, tax_total, grand_total, paid_total, notes'
      : 'id, company_id, branch_id, warehouse_id, customer_id, sales_rep_id, is_tax_invoice, auto_number, document_number, document_date, document_timestamp, document_type, status, subtotal, discount_total, tax_total, grand_total, paid_total, notes';
    final rows = await _db.from(table)
      .select(columns)
      .eq('company_id', companyId.trim())
      .order('document_date', ascending: false)
      .limit(300);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchParties(String companyId, ErpOperationalKind kind) async {
    final rows = await _db.from('erp_parties')
      .select('id, party_code, party_name, party_kind, sales_rep_id, default_warehouse_id')
      .eq('company_id', companyId.trim()).eq('is_active', true)
      .inFilter('party_kind', kind == ErpOperationalKind.purchase ? ['supplier','both'] : ['customer','both'])
      .order('party_name').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRepresentatives(String companyId) async {
    final rows = await _db.from('erp_sales_representatives')
      .select('id, rep_code, rep_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('rep_name');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses(String companyId) async {
    final rows = await _db.from('erp_warehouses')
      .select('id, warehouse_code, warehouse_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('warehouse_name');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<String>> fetchPartyWarehouseIds({
    required String companyId,
    required String partyId,
  }) async {
    final rows = await _db.from('erp_party_warehouses')
      .select('warehouse_id')
      .eq('company_id', companyId.trim())
      .eq('party_id', partyId);
    return rows.map((row) => (row['warehouse_id'] ?? '').toString())
      .where((id) => id.isNotEmpty).toList();
  }

  Future<List<Map<String, dynamic>>> fetchItems(String companyId) async {
    final rows = await _db.from('erp_items')
      .select('id, item_code, item_name, barcode, base_unit, purchase_price, sale_price, tax_rate, discount_limit')
      .eq('company_id', companyId.trim()).eq('is_active', true).order('item_name').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchSalesCampaigns({
    required String companyId,
    required String campaignType,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await _db.from('erp_sales_campaigns')
      .select('id, company_id, campaign_type, title, start_date, end_date, owner_party_id, owner_label, is_active')
      .eq('company_id', companyId.trim())
      .eq('campaign_type', campaignType)
      .eq('is_active', true)
      .lte('start_date', today)
      .gte('end_date', today)
      .order('start_date', ascending: false);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchSalesCampaignItems({
    required String companyId,
    required String campaignId,
  }) async {
    final rows = await _db.from('erp_sales_campaign_items')
      .select('id, campaign_id, item_id, offer_price, min_quantity, max_quantity, representative_incentive, customer_incentive')
      .eq('company_id', companyId.trim())
      .eq('campaign_id', campaignId)
      .eq('is_active', true)
      .order('created_at');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCustomerShortages({
    required String companyId,
    required String customerId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.from('erp_customer_shortages')
      .select('id, item_id, source_document_id, source_document_number, source_date, requested_quantity, fulfilled_quantity, status, created_at')
      .eq('company_id', companyId.trim())
      .eq('customer_id', customerId)
      .inFilter('status', ['open', 'partial'])
      .gte('source_date', from.toIso8601String().substring(0, 10))
      .lte('source_date', to.toIso8601String().substring(0, 10))
      .order('source_date', ascending: false)
      .order('created_at', ascending: false);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> deleteCustomerShortage({
    required String companyId,
    required String shortageId,
  }) async {
    await _db.from('erp_customer_shortages')
      .delete()
      .eq('company_id', companyId.trim())
      .eq('id', shortageId);
  }

  Future<String> createDraft({
    required String companyId,
    required ErpOperationalKind kind,
    required String documentNumber,
    required String documentType,
    required String partyId,
    required String warehouseId,
    String? notes,
    DateTime? documentDate,
    String? salesRepId,
    bool isTaxInvoice = false,
  }) async {
    if (documentNumber.trim().isEmpty || partyId.isEmpty || warehouseId.isEmpty) {
      throw ArgumentError('رقم المستند والطرف والمخزن حقول إلزامية.');
    }
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'created_by': _db.auth.currentUser?.id,
      'warehouse_id': warehouseId,
      'document_number': documentNumber.trim(),
      'document_date': (documentDate ?? DateTime.now()).toIso8601String().substring(0, 10),
      'document_timestamp': DateTime.now().toUtc().toIso8601String(),
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
      payload['sales_rep_id'] = (salesRepId == null || salesRepId.isEmpty) ? null : salesRepId;
      payload['is_tax_invoice'] = isTaxInvoice;
      final row = await _db.from('erp_sales_documents').insert(payload).select('id').single();
      return row['id'].toString();
    }
  }

  Future<Map<String, dynamic>?> resolvePrice({
    required String companyId, required String itemId, required String kind,
    required double quantity, String? partyId,
  }) async {
    final result = await _db.rpc('erp_resolve_item_price', params: {
      'p_company_id': companyId.trim(),
      'p_item_id': itemId,
      'p_price_kind': kind,
      'p_quantity': quantity,
      'p_party_id': partyId,
      'p_price_date': DateTime.now().toIso8601String().substring(0, 10),
    });
    if (result is List && result.isNotEmpty) return Map<String, dynamic>.from(result.first as Map);
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchUnits({
    required String companyId,
    required List<String> itemIds,
  }) async {
    if (itemIds.isEmpty) return [];
    final rows = await _db.from('erp_item_units')
      .select('id, item_id, unit_code, unit_name, conversion_factor, is_base_unit')
      .eq('company_id', companyId.trim())
      .eq('is_active', true)
      .inFilter('item_id', itemIds)
      .order('unit_name');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchWarehouseBalances({
    required String companyId,
    required String warehouseId,
  }) async {
    final rows = await _db.from('erp_stock_balances')
      .select('item_id, quantity_on_hand')
      .eq('company_id', companyId.trim())
      .eq('warehouse_id', warehouseId);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchActiveReservations({
    required String companyId,
    required String warehouseId,
  }) async {
    final rows = await _db.from('erp_stock_reservations')
      .select('item_id, quantity_base')
      .eq('company_id', companyId.trim())
      .eq('warehouse_id', warehouseId)
      .eq('status', 'active');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<int> addLinesAtomically({
    required String documentId,
    required ErpOperationalKind kind,
    required List<Map<String, Object?>> lines,
  }) async {
    if (lines.isEmpty) throw ArgumentError('اختر صنفًا واحدًا على الأقل.');
    final result = await _db.rpc('erp_add_operational_document_lines_v2', params: {
      'p_document_id': documentId,
      'p_kind': kind == ErpOperationalKind.purchase ? 'purchase' : 'sales',
      'p_lines': lines,
    });
    if (result is num) return result.toInt();
    return int.tryParse((result ?? '').toString()) ?? lines.length;
  }

  Future<void> addLine({
    required String documentId,
    required ErpOperationalKind kind,
    required String itemId,
    required double quantity,
    required double unitPrice,
    double discount = 0,
    double tax = 0,
    String? unitId,
  }) async {
    final gross = quantity * unitPrice;
    if (itemId.isEmpty || quantity <= 0 || unitPrice < 0 || discount < 0 || tax < 0 || discount > gross) {
      throw ArgumentError('راجع الصنف والكمية والسعر والخصم والضريبة.');
    }
    await _db.rpc('erp_add_operational_document_line_v2', params: {
      'p_document_id': documentId,
      'p_kind': kind == ErpOperationalKind.purchase ? 'purchase' : 'sales',
      'p_item_id': itemId,
      'p_quantity': quantity,
      'p_unit_price': unitPrice,
      'p_discount': discount,
      'p_tax': tax,
      'p_unit_id': unitId,
    });
  }

  Future<List<Map<String, dynamic>>> fetchLines(String documentId, ErpOperationalKind kind) async {
    final table = kind == ErpOperationalKind.purchase ? 'erp_purchase_lines' : 'erp_sales_lines';
    final rows = await _db.from(table)
      .select('id, item_id, quantity, unit_price, discount_amount, tax_amount, line_total, unit_code, conversion_factor, base_quantity, batch_number, expiry_date')
      .eq('document_id', documentId).order('created_at');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> postDocument(String id, ErpOperationalKind kind) async {
    final function = kind == ErpOperationalKind.purchase
      ? 'erp_post_purchase_document' : 'erp_post_sales_document';
    await _db.rpc(function, params: {'p_document_id': id});
  }
}
