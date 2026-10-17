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

  /// جلب إشعارات المستخدم من الأحدث إلى الأقدم.
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
    final id = notificationId.trim();
    if (id.isEmpty) {
      throw ArgumentError('معرّف الإشعار مطلوب.');
    }

    await _requireClient
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
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

  /// حذف إشعار من حساب المستخدم الحالي.
  Future<void> deleteNotification(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) {
      throw ArgumentError('معرّف الإشعار مطلوب.');
    }

    await _requireClient
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// تسجيل إشعار للمستخدم الحالي.
  Future<Map<String, dynamic>> createMyNotification({
    required String title,
    required String body,
    String? type,
    int? orderId,
  }) async {
    return createNotification(
      userId: _userId,
      title: title,
      body: body,
      type: type,
      orderId: orderId,
    );
  }

  /// إنشاء إشعار لمستخدم محدد.
  ///
  /// استدعاء هذه الدالة لمستخدم آخر يتطلب صلاحية
  /// مناسبة في سياسات Supabase.
  Future<Map<String, dynamic>> createNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    int? orderId,
  }) async {
    final cleanUserId = userId.trim();
    final cleanTitle = title.trim();
    final cleanBody = body.trim();

    if (cleanUserId.isEmpty) {
      throw ArgumentError('معرّف المستخدم مطلوب.');
    }
    if (cleanUserId != _userId) {
      throw StateError(
        'لا يمكن إنشاء إشعار لحساب آخر من جلسة المستخدم الحالية.',
      );
    }
    if (cleanTitle.isEmpty) {
      throw ArgumentError('عنوان الإشعار مطلوب.');
    }
    if (cleanBody.isEmpty) {
      throw ArgumentError('نص الإشعار مطلوب.');
    }
    if (cleanTitle.length > 200 || cleanBody.length > 3000) {
      throw ArgumentError('عنوان الإشعار أو نصه تجاوز الحد المسموح.');
    }
    if (type != null && type.trim().length > 80) {
      throw ArgumentError('نوع الإشعار طويل أكثر من اللازم.');
    }

    final data = <String, dynamic>{
      'user_id': cleanUserId,
      'title': cleanTitle,
      'body': cleanBody,
      'is_read': false,
    };

    if (type != null && type.trim().isNotEmpty) {
      data['type'] = type.trim();
    }

    if (orderId != null) {
      if (orderId <= 0) {
        throw ArgumentError('رقم الطلب غير صحيح.');
      }
      data['order_id'] = orderId;
    }

    final response = await _requireClient
        .from('notifications')
        .insert(data)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }
}
