import 'package:supabase_flutter/supabase_flutter.dart';

class StoryService {
  StoryService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client != null) {
      return client;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError(
        'اتصال Supabase غير متاح. يرجى المحاولة لاحقًا.',
      );
    }
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;

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
    _validateLimit(limit);

    var query = _requireClient
        .from('stories')
        .select()
        .gt(
          'expires_at',
          DateTime.now().toUtc().toIso8601String(),
        );

    final activity = _clean(activityType);

    if (activity != null) {
      query = query.eq('activity_type', activity);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    final stories = _mapRows(response);
    final userIds = stories
        .map((story) => story['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (userIds.isNotEmpty) {
      try {
        final profiles = await _requireClient
            .from('profile_public_directory')
            .select('id, full_name, avatar_url, role, account_type')
            .inFilter('id', userIds);
        final byId = <String, Map<String, dynamic>>{
          for (final profile in profiles.whereType<Map>())
            profile['id'].toString(): Map<String, dynamic>.from(profile),
        };
        for (final story in stories) {
          final profile = byId[story['user_id']?.toString()];
          if (profile == null) continue;
          story['display_name'] = profile['full_name'];
          story['avatar_url'] = profile['avatar_url'];
          story['user_role'] = profile['role'] ?? profile['account_type'];
        }
      } catch (_) {
        // Keep the story feed available even if profile visibility is restricted.
      }
    }
    return stories;
  }

  /// جلب قصص المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyStories({
    int limit = 100,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('stories')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(response);
  }


  /// سجل جميع قصص المستخدم، بما فيها المنتهية والمؤرشفة.
  Future<List<Map<String, dynamic>>> getMyStoryHistory({int limit = 200}) async {
    _validateLimit(limit);
    final rows = await _requireClient.from('stories').select()
      .eq('user_id', _userId).order('created_at', ascending: false).limit(limit);
    return _mapRows(rows);
  }

  Future<Map<String, dynamic>> updateStory({
    required String storyId, String? caption, Duration? duration,
  }) async {
    final id = int.tryParse(storyId);
    if (id == null) throw ArgumentError('معرّف القصة غير صالح.');
    if (duration != null && (duration <= Duration.zero || duration > const Duration(hours: 24))) {
      throw ArgumentError('مدة القصة يجب أن تكون من دقيقة إلى 24 ساعة.');
    }
    final data = <String,dynamic>{'caption': _clean(caption), 'updated_at': DateTime.now().toUtc().toIso8601String()};
    if (duration != null) {
      data['duration_minutes'] = duration.inMinutes.clamp(1,1440);
      data['expires_at'] = DateTime.now().toUtc().add(duration).toIso8601String();
      data['archived_at'] = null;
    }
    final row = await _requireClient.from('stories').update(data)
      .eq('id', id).eq('user_id', _userId).select().maybeSingle();
    if (row == null) throw StateError('القصة غير موجودة أو لا تملك صلاحية تعديلها.');
    return Map<String,dynamic>.from(row);
  }

  Future<Map<String, dynamic>> republishStory(String storyId, {int durationMinutes = 60}) async {
    if (durationMinutes < 1 || durationMinutes > 1440) throw ArgumentError('مدة القصة من دقيقة إلى 24 ساعة.');
    final id = int.tryParse(storyId);
    if (id == null) throw ArgumentError('معرّف القصة غير صالح.');
    final row = await _requireClient.from('stories').update({
      'expires_at': DateTime.now().toUtc().add(Duration(minutes: durationMinutes)).toIso8601String(),
      'duration_minutes': durationMinutes, 'archived_at': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', _userId).select().maybeSingle();
    if (row == null) throw StateError('القصة غير موجودة أو لا تملك صلاحية إعادة نشرها.');
    return Map<String,dynamic>.from(row);
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
    final cleanCaption = _clean(caption);
    final cleanActivity = _clean(activityType);

    if (cleanType != 'text') _validateMediaUrl(cleanUrl);

    if (cleanType != 'image' && cleanType != 'video' && cleanType != 'text') {
      throw ArgumentError(
        'نوع القصة يجب أن يكون image أو video أو text.',
      );
    }

    if (cleanCaption != null && cleanCaption.length > 300) {
      throw ArgumentError(
        'وصف القصة يجب ألا يتجاوز 300 حرف.',
      );
    }

    if (cleanActivity != null && cleanActivity.length > 120) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
    }

    var effectiveDuration = duration;
    try {
      final member = await _requireClient.from('erp_company_members').select('company_id').eq('user_id', _userId).eq('is_active', true).limit(1).maybeSingle();
      final erpUser = member == null ? await _requireClient.from('erp_users').select('company_id').eq('auth_user_id', _userId).eq('is_active', true).limit(1).maybeSingle() : null;
      final companyId = (member?['company_id'] ?? erpUser?['company_id'])?.toString();
      if (companyId != null && companyId.isNotEmpty) {
        final policy = await _requireClient.from('erp_program_policies').select('policy_value,is_enabled').eq('company_id', companyId).eq('policy_key', 'trader_market.story_duration').maybeSingle();
        final maximumValue = int.tryParse((policy?['policy_value'] ?? '60').toString());
        final unitPolicy = await _requireClient.from('erp_program_policies').select('policy_value,is_enabled').eq('company_id', companyId).eq('policy_key', 'trader_market.story_duration_unit').maybeSingle();
        final unit = (unitPolicy?['policy_value'] ?? 'دقيقة').toString();
        final maximumMinutes = (maximumValue ?? 60) * (unit == 'ساعة' ? 60 : 1);
        if (policy?['is_enabled'] == true && maximumMinutes > 0 && effectiveDuration.inMinutes > maximumMinutes) effectiveDuration = Duration(minutes: maximumMinutes.clamp(1,1440).toInt());
      }
    } catch (_) { /* Keep the 60-minute default if company policy is unavailable. */ }
    if (effectiveDuration <= Duration.zero ||
        effectiveDuration > const Duration(hours: 24)) {
      throw ArgumentError(
        'مدة القصة يجب أن تكون أكبر من صفر '
        'ولا تتجاوز ساعة واحدة.',
      );
    }

    final now = DateTime.now().toUtc();

    final data = <String, dynamic>{
      'user_id': _userId,
      'media_url': cleanUrl.isEmpty ? null : cleanUrl,
      'media_type': cleanType,
      'caption': cleanCaption,
      'created_at': now.toIso8601String(),
      'expires_at': now.add(effectiveDuration).toIso8601String(),
      'duration_minutes': effectiveDuration.inMinutes.clamp(1,1440),
    };

    if (cleanActivity != null) {
      data['activity_type'] = cleanActivity;
    }

    final response = await _requireClient
        .from('stories')
        .insert(data)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// معرّفات القصص التي شاهدها المستخدم الحالي.
  Future<Set<String>> getViewedStoryIds() async {
    final rows = await _requireClient
        .from('story_views')
        .select('story_id')
        .eq('viewer_id', _userId);
    return rows
        .whereType<Map>()
        .map((row) => row['story_id'].toString())
        .toSet();
  }

  /// تسجيل مشاهدة واحدة للقصة للمستخدم الحالي.
  Future<void> markStoryViewed(String storyId) async {
    final id = _requiredText(storyId, 'معرّف القصة مطلوب.');
    await _requireClient.from('story_views').upsert(
      {'story_id': int.tryParse(id) ?? id, 'viewer_id': _userId},
      onConflict: 'story_id,viewer_id',
      ignoreDuplicates: true,
    );
  }

  /// إرسال رد خاص على قصة إلى صاحبها.
  Future<void> sendReply({
    required String storyId,
    required String recipientId,
    required String body,
  }) async {
    final id = int.tryParse(_requiredText(storyId, 'معرّف القصة مطلوب.'));
    if (id == null || id <= 0) {
      throw ArgumentError('معرّف القصة غير صالح.');
    }
    final recipient = _requiredText(recipientId, 'صاحب القصة غير معروف.');
    final message = _requiredText(body, 'اكتب الرسالة أولًا.');
    if (message.length > 2000) {
      throw ArgumentError('الرسالة يجب ألا تتجاوز 2000 حرف.');
    }
    if (recipient == _userId) {
      throw ArgumentError('لا يمكنك إرسال رسالة إلى نفسك.');
    }
    await _requireClient.from('story_replies').insert({
      'story_id': id,
      'sender_id': _userId,
      'recipient_id': recipient,
      'body': message,
    });
  }

  /// جلب الرسائل الواردة والصادرة المرتبطة بالقصص للمستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyReplies({int limit = 100}) async {
    if (limit < 1 || limit > 200) throw ArgumentError('حد الرسائل غير صالح.');
    final userId = _userId;
    final rows = await _requireClient
        .from('story_replies')
        .select()
        .or('sender_id.eq.$userId,recipient_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapRows(rows);
  }

  /// حذف قصة يملكها المستخدم الحالي.
  Future<void> deleteStory(String storyId) async {
    final id = _requiredText(
      storyId,
      'معرّف القصة مطلوب.',
    );

    await _requireClient
        .from('stories')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  void _validateMediaUrl(String value) {
    if (value.isEmpty) {
      throw ArgumentError('رابط صورة أو فيديو القصة مطلوب.');
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw ArgumentError(
        'رابط القصة يجب أن يكون رابط ويب صحيحًا يبدأ بـ https أو http.',
      );
    }
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  String _requiredText(String value, String message) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError(message);
    }

    return cleaned;
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  List<Map<String, dynamic>> _mapRows(dynamic response) {
    if (response is! List) {
      throw StateError('تعذر قراءة بيانات القصص.');
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
