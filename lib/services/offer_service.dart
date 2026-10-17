import 'package:supabase_flutter/supabase_flutter.dart';

class OfferService {
  OfferService({SupabaseClient? client})
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
      throw StateError('خدمة قاعدة البيانات غير متاحة حالياً.');
    }
    return client;
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  /// جلب العروض النشطة المتاحة حاليًا، مع إمكانية تحديد النشاط.
  Future<List<Map<String, dynamic>>> getOffers({
    String? activityType,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final now = DateTime.now().toUtc().toIso8601String();

    var query = _requireClient
        .from('offers')
        .select()
        .eq('is_active', true)
        .or('starts_at.is.null,starts_at.lte.$now')
        .or('ends_at.is.null,ends_at.gte.$now');

    final activity = _emptyToNull(activityType);
    if (activity != null) {
      query = query.eq('activity_type', activity);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return _toMapList(response);
  }

  /// جلب عروض مورد معين.
  Future<List<Map<String, dynamic>>> getSupplierOffers(
    String supplierId, {
    bool activeOnly = true,
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final cleanSupplierId = supplierId.trim();
    if (cleanSupplierId.isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    var query = _requireClient
        .from('offers')
        .select()
        .eq('supplier_id', cleanSupplierId);

    if (activeOnly) {
      final now = DateTime.now().toUtc().toIso8601String();

      query = query
          .eq('is_active', true)
          .or('starts_at.is.null,starts_at.lte.$now')
          .or('ends_at.is.null,ends_at.gte.$now');
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return _toMapList(response);
  }

  /// إضافة عرض جديد بواسطة المورد الحالي.
  Future<Map<String, dynamic>> createOffer({
    required String title,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
    String? imageUrl,
    String? activityType,
    double? discountPercentage,
  }) async {
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanImageUrl = _emptyToNull(imageUrl);
    final activity = _emptyToNull(activityType);

    if (cleanTitle.isEmpty || cleanDescription.isEmpty) {
      throw ArgumentError('يرجى إدخال عنوان العرض ووصفه.');
    }

    if (cleanTitle.length > 200 || cleanDescription.length > 5000) {
      throw ArgumentError('عنوان العرض أو وصفه تجاوز الحد المسموح.');
    }

    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError('تاريخ انتهاء العرض يجب أن يكون بعد بدايته.');
    }

    if (discountPercentage != null &&
        (!discountPercentage.isFinite ||
            discountPercentage <= 0 ||
            discountPercentage > 100)) {
      throw ArgumentError('نسبة الخصم يجب أن تكون أكبر من صفر وحتى 100%.');
    }

    if (cleanImageUrl != null) {
      final uri = Uri.tryParse(cleanImageUrl);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw ArgumentError('رابط صورة العرض غير صالح.');
      }
    }

    if (activity != null && activity.length > 120) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
    }

    final data = <String, dynamic>{
      'supplier_id': _userId,
      'title': cleanTitle,
      'description': cleanDescription,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'image_url': cleanImageUrl,
      'is_active': true,
    };

    if (activity != null) {
      data['activity_type'] = activity;
    }

    if (discountPercentage != null) {
      data['discount_percentage'] = discountPercentage;
    }

    final response = await _requireClient
        .from('offers')
        .insert(data)
        .select()
        .single();

    return _toMap(response);
  }

  /// إيقاف عرض يملكه المورد الحالي.
  Future<void> deactivateOffer(String offerId) async {
    final id = offerId.trim();

    if (id.isEmpty) {
      throw ArgumentError('معرّف العرض مطلوب.');
    }

    await _requireClient
        .from('offers')
        .update({'is_active': false})
        .eq('id', id)
        .eq('supplier_id', _userId);
  }

  /// حذف عرض يملكه المورد الحالي.
  Future<void> deleteOffer(String offerId) async {
    final id = offerId.trim();

    if (id.isEmpty) {
      throw ArgumentError('معرّف العرض مطلوب.');
    }

    await _requireClient
        .from('offers')
        .delete()
        .eq('id', id)
        .eq('supplier_id', _userId);
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw StateError('أعاد الخادم بيانات غير متوقعة.');
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) {
      throw StateError('أعاد الخادم قائمة بيانات غير متوقعة.');
    }

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
