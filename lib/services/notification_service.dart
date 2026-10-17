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

    if (id == null || id.isEmpty) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    return id;
  }

  /// جلب إشعارات المستخدم من الأحدث إلى الأقدم.
  Future<List<Map<String, dynamic>>> getMyNotifications({
    int limit = 50,
  }) async {
    _validateLimit(limit);

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
    final id = _clean(notificationId);

    if (id == null) {
      throw ArgumentError('معرّف الإشعار مطلوب.');
    }

    if (id.length > 200) {
      throw ArgumentError('معرّف الإشعار طويل أكثر من اللازم.');
    }

    await _requireClient
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', _userId)
        .eq('is_read', false);
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
    final id = _clean(notificationId);

    if (id == null) {
      throw ArgumentError('معرّف الإشعار مطلوب.');
    }

    if (id.length > 200) {
      throw ArgumentError('معرّف الإشعار طويل أكثر من اللازم.');
    }

    await _requireClient
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// إنشاء إشعار للمستخدم الحالي.
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
  /// إنشاء إشعارات لمستخدمين آخرين يجب أن يتم عبر
  /// صلاحيات إدارية آمنة أو إجراء خادمي موثوق.
  Future<Map<String, dynamic>> createNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    int? orderId,
  }) async {
    final cleanUserId = _clean(userId);
    final cleanTitle = _clean(title);
    final cleanBody = _clean(body);
    final cleanType = _clean(type);

    if (cleanUserId == null) {
      throw ArgumentError('معرّف المستخدم مطلوب.');
    }

    if (cleanUserId != _userId) {
      throw StateError(
        'لا يمكن إنشاء إشعار لحساب آخر من جلسة المستخدم الحالية.',
      );
    }

    if (cleanTitle == null) {
      throw ArgumentError('عنوان الإشعار مطلوب.');
    }

    if (cleanBody == null) {
      throw ArgumentError('نص الإشعار مطلوب.');
    }

    if (cleanTitle.length > 200) {
      throw ArgumentError('عنوان الإشعار تجاوز الحد المسموح.');
    }

    if (cleanBody.length > 3000) {
      throw ArgumentError('نص الإشعار تجاوز الحد المسموح.');
    }

    if (cleanType != null && cleanType.length > 80) {
      throw ArgumentError('نوع الإشعار طويل أكثر من اللازم.');
    }

    if (orderId != null && orderId <= 0) {
      throw ArgumentError('رقم الطلب غير صحيح.');
    }

    final data = <String, dynamic>{
      'user_id': cleanUserId,
      'title': cleanTitle,
      'body': cleanBody,
      'is_read': false,
    };

    if (cleanType != null) {
      data['type'] = cleanType;
    }

    if (orderId != null) {
      data['order_id'] = orderId;
    }

    final response = await _requireClient
        .from('notifications')
        .insert(data)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// التحقق من عدد النتائج المطلوبة.
  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  /// إزالة المسافات وتحويل النص الفارغ إلى null.
  String? _clean(String? value) {
    final result = value?.trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }
}
