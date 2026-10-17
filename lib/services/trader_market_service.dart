import 'package:supabase_flutter/supabase_flutter.dart';

class TraderMarketService {
  TraderMarketService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب منشورات سوق التجار الأحدث.
  Future<List<Map<String, dynamic>>> getPosts({
    String? activityType,
    String? postType,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    var query = _client
        .from('trader_market_posts')
        .select()
        .eq('is_active', true);

    final activity = activityType?.trim();
    if (activity != null && activity.isNotEmpty) {
      query = query.eq('activity_type', activity);
    }

    final type = postType?.trim();
    if (type != null && type.isNotEmpty) {
      query = query.eq('post_type', type);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب منشورات المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyPosts() async {
    final response = await _client
        .from('trader_market_posts')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// نشر طلب شراء أو عرض بيع في سوق التجار.
  ///
  /// استخدم postType بقيمة متوافقة مع قاعدة البيانات،
  /// مثل: request أو offer.
  Future<Map<String, dynamic>> createPost({
    required String title,
    required String description,
    required String postType,
    String? activityType,
    String? category,
    double? quantity,
    String? unit,
    double? targetPrice,
    String? governorate,
    String? contactPhone,
  }) async {
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanType = postType.trim();

    if (cleanTitle.isEmpty ||
        cleanDescription.isEmpty ||
        cleanType.isEmpty) {
      throw ArgumentError('يرجى إدخال العنوان والوصف ونوع المنشور.');
    }
    if (cleanTitle.length > 200 ||
        cleanDescription.length > 10000 ||
        cleanType.length > 80) {
      throw ArgumentError('العنوان أو الوصف أو نوع المنشور تجاوز الحد المسموح.');
    }

    if (quantity != null && (!quantity.isFinite || quantity <= 0)) {
      throw ArgumentError('الكمية يجب أن تكون أكبر من صفر.');
    }

    if (targetPrice != null &&
        (!targetPrice.isFinite || targetPrice < 0)) {
      throw ArgumentError('السعر لا يمكن أن يكون سالبًا.');
    }

    final data = <String, dynamic>{
      'user_id': _userId,
      'title': cleanTitle,
      'description': cleanDescription,
      'post_type': cleanType,
      'is_active': true,
    };

    _addIfNotEmpty(data, 'activity_type', activityType);
    _addIfNotEmpty(data, 'category', category);
    _addIfNotEmpty(data, 'unit', unit);
    _addIfNotEmpty(data, 'governorate', governorate);
    _addIfNotEmpty(data, 'contact_phone', contactPhone);

    if (quantity != null) {
      data['quantity'] = quantity;
    }

    if (targetPrice != null) {
      data['target_price'] = targetPrice;
    }

    final response = await _client
        .from('trader_market_posts')
        .insert(data)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// تعديل منشور يملكه المستخدم الحالي.
  Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String title,
    required String description,
    String? category,
    double? quantity,
    String? unit,
    double? targetPrice,
    String? governorate,
    bool? isActive,
  }) async {
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();

    final cleanPostId = postId.trim();
    if (cleanPostId.isEmpty) {
      throw ArgumentError('معرّف المنشور مطلوب.');
    }
    if (cleanTitle.isEmpty || cleanDescription.isEmpty) {
      throw ArgumentError('يرجى إدخال العنوان والوصف.');
    }
    if (cleanTitle.length > 200 || cleanDescription.length > 10000) {
      throw ArgumentError('العنوان أو الوصف تجاوز الحد المسموح.');
    }

    if (quantity != null && (!quantity.isFinite || quantity <= 0)) {
      throw ArgumentError('الكمية يجب أن تكون أكبر من صفر.');
    }

    if (targetPrice != null && targetPrice < 0) {
      throw ArgumentError('السعر لا يمكن أن يكون سالبًا.');
    }

    final data = <String, dynamic>{
      'title': cleanTitle,
      'description': cleanDescription,
      'category': _emptyToNull(category),
      'quantity': quantity,
      'unit': _emptyToNull(unit),
      'target_price': targetPrice,
      'governorate': _emptyToNull(governorate),
    };

    if (isActive != null) {
      data['is_active'] = isActive;
    }

    final response = await _client
        .from('trader_market_posts')
        .update(data)
        .eq('id', cleanPostId)
        .eq('user_id', _userId)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// حذف منشور يملكه المستخدم الحالي.
  Future<void> deletePost(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) {
      throw ArgumentError('معرّف المنشور مطلوب.');
    }
    await _client
        .from('trader_market_posts')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  void _addIfNotEmpty(
    Map<String, dynamic> data,
    String key,
    String? value,
  ) {
    final cleaned = _emptyToNull(value);
    if (cleaned != null) {
      data[key] = cleaned;
    }
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
