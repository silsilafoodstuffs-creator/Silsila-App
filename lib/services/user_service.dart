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

    final updates = <String, dynamic>{
      'full_name': fullName.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (whatsappPhone != null) {
      updates['whatsapp_phone'] = whatsappPhone.trim();
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
    await _client.rpc(
      'admin_review_wallet_topup',
      params: {
        'p_request_id': requestId.trim(),
        'p_approve': approve,
        'p_note': note?.trim(),
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
