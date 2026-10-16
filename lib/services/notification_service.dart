import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService({SupabaseClient? client})
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
    final id = _requireClient.auth.currentUser?.id;
    if (id == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return id;
  }

  /// جلب إشعارات المستخدم الحالي من الأحدث إلى الأقدم.
  Future<List<Map<String, dynamic>>> getMyNotifications({
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _requireClient
        .from('notifications')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// عدد الإشعارات غير المقروءة.
  Future<int> getUnreadCount() async {
    final response = await _requireClient
        .from('notifications')
        .select('id')
        .eq('user_id', _userId)
        .eq('is_read', false);

    return response.length;
  }

  /// تعليم إشعار واحد كمقروء.
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) {
      throw ArgumentError('معرّف الإشعار مطلوب.');
    }

    await _requireClient
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId.trim())
        .eq('user_id', _userId);
  }

  /// تعليم جميع إشعارات المستخدم كمقروءة.
  Future<void> markAllAsRead() async {
    await _requireClient
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId)
        .eq('is_read', false);
  }

  /// حذف إشعار واحد من حساب المستخدم الحالي.
  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.trim().isEmpty) {
      throw ArgumentError('معرّف الإشعار مطلوب.');
    }

    await _requireClient
        .from('notifications')
        .delete()
        .eq('id', notificationId.trim())
        .eq('user_id', _userId);
  }
}
