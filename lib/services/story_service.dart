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
  Future<List<Map<String, dynamic>>> getMyStories({
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _client
        .from('stories')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

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
    final parsedUrl = Uri.tryParse(cleanUrl);
    if (parsedUrl == null ||
        !parsedUrl.hasScheme ||
        (parsedUrl.scheme != 'https' && parsedUrl.scheme != 'http') ||
        parsedUrl.host.isEmpty) {
      throw ArgumentError('رابط القصة يجب أن يكون رابط ويب صحيحًا يبدأ بـ https أو http.');
    }
    if ((caption ?? '').trim().length > 300) {
      throw ArgumentError('وصف القصة يجب ألا يتجاوز 300 حرف.');
    }
    if (activityType != null && activityType.trim().length > 120) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
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
    final id = storyId.trim();
    if (id.isEmpty) {
      throw ArgumentError('معرّف القصة مطلوب.');
    }
    await _client
        .from('stories')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
