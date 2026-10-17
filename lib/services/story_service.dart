import 'package:supabase_flutter/supabase_flutter.dart';

class StoryService {
  StoryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب القصص التي لم تنتهِ صلاحيتها.
  Future<List<Map<String, dynamic>>> getActiveStories({
    String? activityType,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    var query = _client
        .from('stories')
        .select()
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());

    final activity = activityType?.trim();
    if (activity != null && activity.isNotEmpty) {
      query = query.eq('activity_type', activity);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب قصص المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyStories() async {
    final response = await _client
        .from('stories')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// إنشاء قصة جديدة تنتهي افتراضيًا بعد ساعة.
  Future<Map<String, dynamic>> createStory({
    required String mediaUrl,
    required String mediaType,
    String? caption,
    String? activityType,
    Duration duration = const Duration(hours: 1),
  }) async {
    final cleanUrl = mediaUrl.trim();
    final cleanType = mediaType.trim().toLowerCase();

    if (cleanUrl.isEmpty) {
      throw ArgumentError('رابط صورة أو فيديو القصة مطلوب.');
    }

    if (cleanType != 'image' && cleanType != 'video') {
      throw ArgumentError('نوع القصة يجب أن يكون image أو video.');
    }

    if (duration <= Duration.zero || duration > const Duration(hours: 1)) {
      throw ArgumentError('مدة القصة يجب أن تكون أكبر من صفر ولا تتجاوز ساعة واحدة.');
    }

    final now = DateTime.now().toUtc();

    final data = <String, dynamic>{
      'user_id': _userId,
      'media_url': cleanUrl,
      'media_type': cleanType,
      'caption': _emptyToNull(caption),
      'created_at': now.toIso8601String(),
      'expires_at': now.add(duration).toIso8601String(),
    };

    final activity = _emptyToNull(activityType);
    if (activity != null) {
      data['activity_type'] = activity;
    }

    final response = await _client
        .from('stories')
        .insert(data)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// حذف قصة يملكها المستخدم الحالي.
  Future<void> deleteStory(String storyId) async {
    await _client
        .from('stories')
        .delete()
        .eq('id', storyId)
        .eq('user_id', _userId);
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
