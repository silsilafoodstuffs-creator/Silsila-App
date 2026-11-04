import 'package:supabase_flutter/supabase_flutter.dart';

class ErpWhatsappContactsRepository {
  ErpWhatsappContactsRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db => _client ?? (throw StateError('Supabase غير مهيأ.'));

  Future<List<Map<String, dynamic>>> fetchContacts(String companyId) async {
    final rows = await _db.from('erp_whatsapp_import_contacts').select()
        .eq('company_id', companyId).order('created_at', ascending: false).limit(5000);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<String> createBatch({
    required String companyId, required String sourceLabel,
    required String fileName, required String sourceType, required int totalContacts,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw StateError('يجب تسجيل الدخول قبل الاستيراد.');
    final row = await _db.from('erp_whatsapp_import_batches').insert({
      'company_id': companyId, 'source_label': sourceLabel,
      'source_file_name': fileName, 'source_type': sourceType,
      'total_contacts': totalContacts, 'created_by': userId,
    }).select('id').single();
    return row['id'].toString();
  }

  Future<void> insertContacts({
    required String companyId, required String batchId,
    required List<Map<String, String>> contacts,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw StateError('انتهت جلسة الدخول.');
    const chunkSize = 150;
    for (var start = 0; start < contacts.length; start += chunkSize) {
      final end = (start + chunkSize < contacts.length) ? start + chunkSize : contacts.length;
      final payload = contacts.sublist(start, end).map((contact) {
        final phone = contact['phone']!.trim();
        return <String, dynamic>{
          'company_id': companyId, 'batch_id': batchId,
          'contact_name': (contact['name'] ?? '').trim(),
          'phone': phone, 'normalized_phone': normalizePhone(phone),
          'group_name': (contact['group'] ?? '').trim(),
          'source_type': contact['source'] ?? 'uploaded_file',
          'consent_status': 'pending', 'created_by': userId,
        };
      }).toList();
      await _db.from('erp_whatsapp_import_contacts').upsert(
        payload, onConflict: 'batch_id,normalized_phone', ignoreDuplicates: true,
      );
    }
  }

  Future<void> markConsented(List<String> ids, {String? evidence}) async {
    if (ids.isEmpty) return;
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw StateError('يجب تسجيل الدخول أولًا.');
    await _db.from('erp_whatsapp_import_contacts').update({
      'consent_status': 'consented',
      'consent_evidence': _blank(evidence),
      'consented_at': DateTime.now().toUtc().toIso8601String(),
      'consented_by': userId,
    }).inFilter('id', ids);
  }

  Future<void> markDeclined(List<String> ids) async {
    if (ids.isEmpty) return;
    await _db.from('erp_whatsapp_import_contacts').update({
      'consent_status': 'declined', 'consented_at': null, 'consented_by': null,
    }).inFilter('id', ids);
  }

  Future<void> deleteContacts(List<String> ids) async {
    if (ids.isEmpty) return;
    await _db.from('erp_whatsapp_import_contacts').delete().inFilter('id', ids);
  }

  static String normalizePhone(String value) {
    final converted = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        converted.write(String.fromCharCode(0x30 + rune - 0x0660));
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        converted.write(String.fromCharCode(0x30 + rune - 0x06F0));
      } else {
        converted.write(String.fromCharCode(rune));
      }
    }
    final normalized = converted.toString().trim();
    final hasLeadingPlus = normalized.startsWith('+');
    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return (hasLeadingPlus ? '+' : '') + digits;
  }
  static String? _blank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
