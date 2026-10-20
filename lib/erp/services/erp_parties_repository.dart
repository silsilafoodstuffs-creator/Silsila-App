import 'package:supabase_flutter/supabase_flutter.dart';

class ErpPartiesRepository {
  ErpPartiesRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول للعملاء والموردين.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchParties(String companyId, {String kind = 'both'}) async {
    var query = _db.from('erp_parties')
      .select('id, party_code, party_name, party_kind, phone, whatsapp, email, address, governorate, district, center, area, customer_type, credit_limit, opening_balance, is_active')
      .eq('company_id', companyId.trim());
    if (kind != 'both') query = query.inFilter('party_kind', [kind, 'both']);
    final rows = await query.order('party_name').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createParty({
    required String companyId,
    required String code,
    required String name,
    required String kind,
    String? phone,
    String? whatsapp,
    String? email,
    String? address,
    String? governorate,
    String? district,
    String? center,
    String? area,
    String? customerType,
    double creditLimit = 0,
    double openingBalance = 0,
  }) async {
    if (companyId.trim().isEmpty || code.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('الشركة وكود الطرف والاسم حقول إلزامية.');
    }
    if (!['supplier','customer','both'].contains(kind)) throw ArgumentError('نوع الطرف غير صحيح.');
    if (creditLimit < 0) throw ArgumentError('حد الائتمان لا يمكن أن يكون سالبًا.');
    await _db.from('erp_parties').insert({
      'company_id': companyId.trim(),
      'party_code': code.trim(),
      'party_name': name.trim(),
      'party_kind': kind,
      'phone': _blank(phone),
      'whatsapp': _blank(whatsapp),
      'email': _blank(email),
      'address': _blank(address),
      'governorate': _blank(governorate),
      'district': _blank(district),
      'center': _blank(center),
      'area': _blank(area),
      'customer_type': _blank(customerType),
      'credit_limit': creditLimit,
      'opening_balance': openingBalance,
      'is_active': true,
    });
  }

  Future<void> setActive(String id, bool active) async {
    await _db.from('erp_parties').update({'is_active': active}).eq('id', id);
  }

  static String? _blank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
