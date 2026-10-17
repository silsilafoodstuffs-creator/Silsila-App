import 'package:supabase_flutter/supabase_flutter.dart';

class SupportService {
  SupportService({SupabaseClient? client})
      : _client = client ?? _defaultClient;

  final SupabaseClient? _client;

  static SupabaseClient? get _defaultClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _requireClient {
    final client = _client;

    if (client == null) {
      throw StateError('اتصال Supabase غير متاح.');
    }

    return client;
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    return user.id;
  }

  /// إنشاء تذكرة دعم فني جديدة.
  Future<Map<String, dynamic>> createTicket({
    required String subject,
    required String message,
    String category = 'general',
    String? orderId,
  }) async {
    final cleanSubject = _requiredText(subject, 'عنوان الطلب');
    final cleanMessage = _requiredText(message, 'تفاصيل الطلب');
    final cleanCategory = _requiredText(category, 'نوع الطلب');

    if (cleanSubject.length > 200) {
      throw ArgumentError('عنوان التذكرة تجاوز الحد المسموح.');
    }

    if (cleanMessage.length > 10000) {
      throw ArgumentError('تفاصيل التذكرة تجاوزت الحد المسموح.');
    }

    if (cleanCategory.length > 80) {
      throw ArgumentError('نوع التذكرة طويل أكثر من اللازم.');
    }

    final data = <String, dynamic>{
      'user_id': _userId,
      'subject': cleanSubject,
      'message': cleanMessage,
      'category': cleanCategory,
      'status': 'open',
    };

    final cleanOrderId = _emptyToNull(orderId);

    if (cleanOrderId != null) {
      final parsedOrderId = int.tryParse(cleanOrderId);

      if (parsedOrderId == null || parsedOrderId <= 0) {
        throw ArgumentError('رقم الطلب المرتبط بالتذكرة غير صحيح.');
      }

      data['order_id'] = parsedOrderId;
    }

    final response = await _requireClient
        .from('support_tickets')
        .insert(data)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// جلب تذاكر الدعم الخاصة بالمستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyTickets({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('support_tickets')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب تفاصيل تذكرة تخص المستخدم الحالي فقط.
  Future<Map<String, dynamic>?> getTicket(
    String ticketId,
  ) async {
    final id = _requiredText(ticketId, 'معرّف التذكرة');

    final response = await _requireClient
        .from('support_tickets')
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
  }

  /// إغلاق تذكرة مفتوحة تخص المستخدم الحالي.
  ///
  /// لا يسمح هذا الإجراء بتعديل التذاكر التابعة لمستخدم آخر.
  Future<void> closeMyTicket(String ticketId) async {
    final id = _requiredText(ticketId, 'معرّف التذكرة');

    await _requireClient
        .from('support_tickets')
        .update({'status': 'closed'})
        .eq('id', id)
        .eq('user_id', _userId)
        .eq('status', 'open');
  }

  /// التحقق من عدد النتائج.
  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  String _requiredText(String? value, String fieldName) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      throw ArgumentError('يرجى إدخال $fieldName.');
    }

    return cleaned;
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
