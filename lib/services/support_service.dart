import 'package:supabase_flutter/supabase_flutter.dart';

class SupportService {
  SupportService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
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
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    final cleanCategory = category.trim();

    if (cleanSubject.isEmpty || cleanMessage.isEmpty) {
      throw ArgumentError('يرجى إدخال عنوان الشكوى وتفاصيلها.');
    }

    if (cleanCategory.isEmpty) {
      throw ArgumentError('يرجى تحديد نوع الطلب.');
    }

    final data = <String, dynamic>{
      'user_id': _userId,
      'subject': cleanSubject,
      'message': cleanMessage,
      'category': cleanCategory,
      'status': 'open',
    };

    final cleanOrderId = orderId?.trim();
    if (cleanOrderId != null && cleanOrderId.isNotEmpty) {
      data['order_id'] = cleanOrderId;
    }

    final response = await _client
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
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _client
        .from('support_tickets')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب تفاصيل تذكرة تخص المستخدم الحالي.
  Future<Map<String, dynamic>?> getTicket(String ticketId) async {
    final response = await _client
        .from('support_tickets')
        .select()
        .eq('id', ticketId)
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
