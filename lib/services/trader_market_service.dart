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
    DateTime? expiryDate,
    bool isNegotiable = false,
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
    data['is_negotiable'] = isNegotiable;
    if (expiryDate != null) data['expiry_date'] = expiryDate.toIso8601String().split('T').first;

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
    final client = _requireClient;
    final userId = _userId;
    if (interactionType == 'accept' || interactionType == 'reject') {
      await client
          .from('trader_market_post_interactions')
          .delete()
          .eq('post_id', id)
          .eq('user_id', userId)
          .inFilter('interaction_type', const ['accept', 'reject']);
    }
    await client.from('trader_market_post_interactions').upsert(
      {
        'post_id': id,
        'user_id': userId,
        'interaction_type': interactionType,
      },
      onConflict: 'post_id,user_id,interaction_type',
      ignoreDuplicates: true,
    );
  }


  /// جلب عروض التفاوض المرتبطة بطلب سوق التجار.
  Future<List<Map<String, dynamic>>> getNegotiations(String postId) async {
    final id = int.tryParse(postId.trim());
    if (id == null || id <= 0) throw ArgumentError('معرّف المنشور غير صالح.');
    final rows = await _requireClient
        .from('trader_market_negotiations')
        .select()
        .eq('post_id', id)
        .order('created_at', ascending: true);
    return _mapRows(rows);
  }

  /// إرسال اقتراح سعر إلى صاحب الطلب.
  Future<Map<String, dynamic>> proposeNegotiation({
    required String postId,
    required double proposedPrice,
  }) async {
    if (!proposedPrice.isFinite || proposedPrice <= 0) {
      throw ArgumentError('سعر التفاوض يجب أن يكون أكبر من صفر.');
    }
    final id = int.tryParse(postId.trim());
    if (id == null || id <= 0) throw ArgumentError('معرّف المنشور غير صالح.');
    final client = _requireClient;
    final userId = _userId;
    final post = await client.from('trader_market_posts')
        .select('user_id,is_negotiable,is_active')
        .eq('id', id).maybeSingle();
    if (post == null || post['is_active'] == false) {
      throw StateError('الطلب غير موجود أو تم إغلاقه.');
    }
    if (post['is_negotiable'] != true) {
      throw StateError('صاحب الطلب لم يسمح بالتفاوض على السعر.');
    }
    final ownerId = (post['user_id'] ?? '').toString();
    if (ownerId.isEmpty || ownerId == userId) {
      throw StateError('لا يمكن إرسال تفاوض إلى نفس حسابك.');
    }
    final row = await client.from('trader_market_negotiations').insert({
      'post_id': id,
      'proposer_id': userId,
      'recipient_id': ownerId,
      'proposed_price': proposedPrice,
      'status': 'pending',
    }).select().single();
    return Map<String, dynamic>.from(row);
  }

  /// قبول أو رفض اقتراح، أو إرسال سعر مقابل للطرف الآخر.
  Future<void> respondToNegotiation({
    required String negotiationId,
    required String action,
    double? counterPrice,
  }) async {
    if (!const {'accept','reject','counter'}.contains(action)) {
      throw ArgumentError('الإجراء غير صالح.');
    }
    if (action == 'counter' &&
        (counterPrice == null || !counterPrice.isFinite || counterPrice <= 0)) {
      throw ArgumentError('أدخل سعرًا مقابلًا صحيحًا.');
    }
    final client = _requireClient;
    final userId = _userId;
    final id = int.tryParse(negotiationId.trim());
    if (id == null || id <= 0) throw ArgumentError('معرّف التفاوض غير صالح.');
    final current = await client.from('trader_market_negotiations')
        .select().eq('id', id).maybeSingle();
    if (current == null) throw StateError('اقتراح التفاوض غير موجود.');
    if ((current['recipient_id'] ?? '').toString() != userId ||
        (current['status'] ?? '').toString() != 'pending') {
      throw StateError('هذا الاقتراح ليس بانتظار ردك.');
    }
    await client.from('trader_market_negotiations').update({
      'status': action == 'counter' ? 'countered' : action == 'accept' ? 'accepted' : 'rejected',
    }).eq('id', id);
    if (action == 'counter') {
      await client.from('trader_market_negotiations').insert({
        'post_id': current['post_id'],
        'parent_id': id,
        'proposer_id': userId,
        'recipient_id': current['proposer_id'],
        'proposed_price': counterPrice,
        'status': 'pending',
      });
    }
  }

  Future<bool> hasInteraction(String postId, String interactionType) async {
    final id = int.tryParse(postId.trim());
    if (id == null || id <= 0) return false;
    if (!const {'view', 'accept', 'reject'}.contains(interactionType)) return false;
    final rows = await _requireClient
        .from('trader_market_post_interactions')
        .select('interaction_type')
        .eq('post_id', id)
        .eq('user_id', _userId)
        .eq('interaction_type', interactionType)
        .limit(1);
    return rows is List && rows.isNotEmpty;
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
