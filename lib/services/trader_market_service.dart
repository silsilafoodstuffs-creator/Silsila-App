import 'package:supabase_flutter/supabase_flutter.dart';

class TraderMarketService {
  TraderMarketService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    if (_client != null) {
      return _client;
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

  /// جلب منشورات سوق التجار الأحدث.
  Future<List<Map<String, dynamic>>> getPosts({
    String? activityType,
    String? postType,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    var query = _requireClient
        .from('trader_market_posts')
        .select()
        .eq('is_active', true);

    final activity = _clean(activityType);
    if (activity != null) {
      query = query.eq('activity_type', activity);
    }

    final type = _clean(postType);
    if (type != null) {
      query = query.eq('post_type', type);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(response);
  }

  /// جلب منشورات المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getMyPosts() async {
    final response = await _requireClient
        .from('trader_market_posts')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return _mapRows(response);
  }

  /// نشر طلب شراء أو عرض بيع في سوق التجار.
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
    final cleanTitle = _requiredText(
      title,
      'عنوان المنشور مطلوب.',
      maxLength: 200,
    );

    final cleanDescription = _requiredText(
      description,
      'وصف المنشور مطلوب.',
      maxLength: 10000,
    );

    final cleanType = _requiredText(
      postType,
      'نوع المنشور مطلوب.',
      maxLength: 80,
    );

    _validateQuantity(quantity);
    _validateTargetPrice(targetPrice);

    _validateOptionalText(
      activityType,
      'نوع النشاط',
      120,
    );
    _validateOptionalText(category, 'القسم', 120);
    _validateOptionalText(unit, 'الوحدة', 60);
    _validateOptionalText(governorate, 'المحافظة', 100);
    _validateOptionalText(contactPhone, 'رقم التواصل', 40);
    _validateContactPhone(contactPhone);

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

    final response = await _requireClient
        .from('trader_market_posts')
        .insert(data)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// تسجيل مشاهدة أو قبول أو رفض منشور سوق التجار.
  Future<void> recordInteraction({
    required String postId,
    required String interactionType,
  }) async {
    final id = int.tryParse(postId.trim());
    if (id == null || id <= 0) {
      throw ArgumentError('معرّف المنشور غير صالح.');
    }
    if (!const {'view', 'accept', 'reject'}.contains(interactionType)) {
      throw ArgumentError('نوع التفاعل غير صالح.');
    }
    await _requireClient.from('trader_market_post_interactions').upsert(
      {
        'post_id': id,
        'user_id': _userId,
        'interaction_type': interactionType,
      },
      onConflict: 'post_id,user_id,interaction_type',
      ignoreDuplicates: true,
    );
  }

  /// إحصاءات المشاهدة والقبول والرفض لمنشور واحد.
  Future<Map<String, int>> getInteractionCounts(String postId) async {
    final id = int.tryParse(postId.trim());
    if (id == null || id <= 0) {
      throw ArgumentError('معرّف المنشور غير صالح.');
    }
    final rows = await _requireClient
        .from('trader_market_post_interactions')
        .select('interaction_type')
        .eq('post_id', id);
    final counts = <String, int>{'view': 0, 'accept': 0, 'reject': 0};
    for (final row in rows.whereType<Map>()) {
      final type = row['interaction_type']?.toString();
      if (type != null && counts.containsKey(type)) {
        counts[type] = counts[type]! + 1;
      }
    }
    return counts;
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
    final cleanPostId = _requiredText(
      postId,
      'معرّف المنشور مطلوب.',
      maxLength: 200,
    );

    final cleanTitle = _requiredText(
      title,
      'عنوان المنشور مطلوب.',
      maxLength: 200,
    );

    final cleanDescription = _requiredText(
      description,
      'وصف المنشور مطلوب.',
      maxLength: 10000,
    );

    _validateQuantity(quantity);
    _validateTargetPrice(targetPrice);

    _validateOptionalText(category, 'القسم', 120);
    _validateOptionalText(unit, 'الوحدة', 60);
    _validateOptionalText(governorate, 'المحافظة', 100);

    final data = <String, dynamic>{
      'title': cleanTitle,
      'description': cleanDescription,
      'category': _clean(category),
      'quantity': quantity,
      'unit': _clean(unit),
      'target_price': targetPrice,
      'governorate': _clean(governorate),
    };

    if (isActive != null) {
      data['is_active'] = isActive;
    }

    final response = await _requireClient
        .from('trader_market_posts')
        .update(data)
        .eq('id', cleanPostId)
        .eq('user_id', _userId)
        .select()
        .maybeSingle();

    if (response == null) {
      throw StateError(
        'المنشور غير موجود أو لا تملك صلاحية تعديله.',
      );
    }

    return Map<String, dynamic>.from(response);
  }

  /// حذف منشور يملكه المستخدم الحالي.
  Future<void> deletePost(String postId) async {
    final cleanPostId = _requiredText(
      postId,
      'معرّف المنشور مطلوب.',
      maxLength: 200,
    );

    await _requireClient
        .from('trader_market_posts')
        .delete()
        .eq('id', cleanPostId)
        .eq('user_id', _userId);
  }

  void _validateContactPhone(String? value) {
    final phone = _clean(value);
    if (phone == null) return;

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      throw ArgumentError(
        'رقم التواصل يجب أن يكون بصيغة دولية صحيحة، مثل +201012345678.',
      );
    }
  }

  void _validateQuantity(double? quantity) {
    if (quantity != null &&
        (!quantity.isFinite || quantity <= 0)) {
      throw ArgumentError(
        'الكمية يجب أن تكون رقمًا أكبر من صفر.',
      );
    }
  }

  void _validateTargetPrice(double? price) {
    if (price != null && (!price.isFinite || price < 0)) {
      throw ArgumentError(
        'السعر يجب أن يكون رقمًا صالحًا وغير سالب.',
      );
    }
  }

  void _validateOptionalText(
    String? value,
    String fieldName,
    int maxLength,
  ) {
    final cleaned = _clean(value);

    if (cleaned != null && cleaned.length > maxLength) {
      throw ArgumentError(
        '$fieldName يجب ألا يتجاوز $maxLength حرفًا.',
      );
    }
  }

  String _requiredText(
    String value,
    String message, {
    required int maxLength,
  }) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.length > maxLength) {
      throw ArgumentError(message);
    }

    return cleaned;
  }

  void _addIfNotEmpty(
    Map<String, dynamic> data,
    String key,
    String? value,
  ) {
    final cleaned = _clean(value);

    if (cleaned != null) {
      data[key] = cleaned;
    }
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
      throw StateError('تعذر قراءة منشورات سوق التجار.');
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
