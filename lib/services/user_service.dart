import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  UserService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// جلب بيانات المستخدم الحالي من جدول profiles.
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final result = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return result;
  }

  /// جلب بيانات مستخدم بواسطة المعرّف.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final result = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return result;
  }

  /// تحديث اسم المستخدم ورقم واتساب.
  Future<void> updateBasicInfo({
    required String fullName,
    String? whatsappPhone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    final cleanName = fullName.trim();
    if (cleanName.isEmpty || cleanName.length > 120) {
      throw ArgumentError('الاسم مطلوب ويجب ألا يتجاوز 120 حرفًا.');
    }

    final cleanWhatsapp = whatsappPhone?.trim();
    if (cleanWhatsapp != null && cleanWhatsapp.length > 30) {
      throw ArgumentError('رقم واتساب طويل أكثر من اللازم.');
    }

    final updates = <String, dynamic>{
      'full_name': cleanName,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (cleanWhatsapp != null) {
      updates['whatsapp_phone'] =
          cleanWhatsapp.isEmpty ? null : cleanWhatsapp;
    }

    await _client.from('profiles').update(updates).eq('id', user.id);
  }

  /// تحديث حالة الحساب إذا كانت الصلاحيات تسمح بذلك.
  Future<void> updateAccountStatus({
    required String userId,
    required String status,
  }) async {
    const allowedStatuses = {
      'pending',
      'approved',
      'active',
      'suspended',
      'rejected',
    };

    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('حالة الحساب غير صحيحة.');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError('معرّف المستخدم مطلوب.');
    }

    if (_client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    await _client.rpc(
      'admin_update_account_status',
      params: {
        'p_user_id': userId.trim(),
        'p_status': status,
      },
    );
  }

  /// جلب الحسابات المعلقة للمسؤول المعتمد فقط.
  Future<List<Map<String, dynamic>>> getPendingAccounts() async {
    if (_client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    final response = await _client.rpc('admin_list_pending_accounts');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// جلب طلبات شحن المحفظة التي تنتظر مراجعة المسؤول.
  Future<List<Map<String, dynamic>>> getPendingTopUps() async {
    if (_client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    final response = await _client.rpc('admin_list_pending_topups');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// اعتماد طلب شحن أو رفضه من خلال إجراء إداري آمن.
  Future<void> reviewTopUp({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    if (_client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    if (requestId.trim().isEmpty) {
      throw ArgumentError('معرّف طلب شحن المحفظة مطلوب.');
    }
    if (note != null && note.trim().length > 1000) {
      throw ArgumentError('ملاحظة المراجعة يجب ألا تتجاوز 1000 حرف.');
    }
    await _client.rpc(
      'admin_review_wallet_topup',
      params: {
        'p_request_id': requestId.trim(),
        'p_approve': approve,
        'p_note': note?.trim(),
      },
    );
  }

  /// جلب تذاكر الدعم المفتوحة للمسؤول المعتمد.
  Future<List<Map<String, dynamic>>> getPendingSupportTickets() async {
    if (_client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    final response = await _client.rpc('admin_list_support_tickets');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// تحديث حالة تذكرة الدعم وإرسال رد للمستخدم عند الحاجة.
  Future<void> updateSupportTicket({
    required String ticketId,
    required String status,
    String? reply,
  }) async {
    if (_client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    if (ticketId.trim().isEmpty) {
      throw ArgumentError('معرّف تذكرة الدعم مطلوب.');
    }
    if (reply != null && reply.trim().length > 5000) {
      throw ArgumentError('الرد يجب ألا يتجاوز 5000 حرف.');
    }
    await _client.rpc(
      'admin_update_support_ticket',
      params: {
        'p_ticket_id': ticketId.trim(),
        'p_status': status,
        'p_reply': reply?.trim(),
      },
    );
  }

  /// هل يوجد مستخدم مسجل الدخول؟
  bool get isLoggedIn => _client.auth.currentUser != null;

  /// معرّف المستخدم الحالي.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// تسجيل الخروج.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
