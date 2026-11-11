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

  Future<String> importBatchAtomically({
    required String companyId,
    required String sourceLabel,
    required String fileName,
    required String sourceType,
    required List<Map<String, String>> contacts,
  }) async {
    final normalizedCompany = companyId.trim();
    if (normalizedCompany.isEmpty) throw ArgumentError('الشركة مطلوبة قبل الاستيراد.');
    if (!['csv', 'vcard', 'manual', 'official_api'].contains(sourceType)) {
      throw ArgumentError('مصدر الاستيراد غير معتمد.');
    }
    if (contacts.isEmpty || contacts.length > 5000) {
      throw ArgumentError('عدد جهات الاتصال يجب أن يكون من 1 إلى 5000 في الدفعة الواحدة.');
    }
    if (_db.auth.currentUser?.id == null) {
      throw StateError('يجب تسجيل الدخول قبل الاستيراد.');
    }

    final payload = <Map<String, dynamic>>[];
    final seenPhones = <String>{};
    for (final contact in contacts) {
      final phone = (contact['phone'] ?? '').trim();
      final normalized = normalizePhone(phone);
      if (normalized.replaceAll('+', '').length < 7) {
        throw ArgumentError('يوجد رقم هاتف غير صالح داخل ملف الاستيراد.');
      }
      if (!seenPhones.add(normalized)) {
        throw ArgumentError('يوجد رقم مكرر بعد توحيد صيغة الهاتف.');
      }
      final contactSource = (contact['source'] ?? 'uploaded_file').trim();
      if (!['uploaded_file', 'csv', 'vcard', 'official_api', 'manual'].contains(contactSource)) {
        throw ArgumentError('مصدر إحدى جهات الاتصال غير معتمد.');
      }
      payload.add({
        'name': (contact['name'] ?? '').trim(),
        'phone': phone,
        'normalized_phone': normalized,
        'group': (contact['group'] ?? '').trim(),
        'source': contactSource,
      });
    }

    final result = await _db.rpc('erp_import_whatsapp_contacts_atomic', params: {
      'p_company_id': normalizedCompany,
      'p_source_label': sourceLabel.trim().isEmpty ? 'استيراد ملف' : sourceLabel.trim(),
      'p_source_file_name': fileName.trim(),
      'p_source_type': sourceType,
      'p_contacts': payload,
    });
    if (result is! Map) {
      throw StateError('لم يرجع الخادم نتيجة دفعة الاستيراد الذري.');
    }
    final response = Map<String, dynamic>.from(result);
    final batchId = (response['batch_id'] ?? '').toString();
    final inserted = int.tryParse((response['inserted_count'] ?? '').toString()) ?? -1;
    if (batchId.isEmpty || inserted != payload.length) {
      throw StateError('لم يتطابق عدد جهات الاتصال المحفوظة مع عدد السجلات المستوردة.');
    }
    return batchId;
  }

  Future<void> updateContact({
    required String id,
    required String contactName,
    required String phone,
    required String groupName,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized.replaceAll('+', '').length < 7) {
      throw ArgumentError('رقم الموبايل غير صحيح.');
    }
    await _db.from('erp_whatsapp_import_contacts').update({
      'contact_name': contactName.trim(),
      'phone': phone.trim(),
      'normalized_phone': normalized,
      'group_name': groupName.trim(),
    }).eq('id', id);
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
