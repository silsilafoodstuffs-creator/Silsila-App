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

  Future<void> postDocument(String id, ErpOperationalKind kind) async {
    final function = kind == ErpOperationalKind.purchase
      ? 'erp_post_purchase_document' : 'erp_post_sales_document';
    await _db.rpc(function, params: {'p_document_id': id});
  }
}
