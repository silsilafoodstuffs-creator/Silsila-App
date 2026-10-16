import 'package:supabase_flutter/supabase_flutter.dart';

class OfferService {
  OfferService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب العروض النشطة، مع إمكانية تحديد النشاط.
  Future<List<Map<String, dynamic>>> getOffers({
    String? activityType,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    var query = _client
        .from('offers')
        .select()
        .eq('is_active', true);

    final activity = activityType?.trim();
    if (activity != null && activity.isNotEmpty) {
      query = query.eq('activity_type', activity);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب عروض مورد معين.
  Future<List<Map<String, dynamic>>> getSupplierOffers(
    String supplierId, {
    bool activeOnly = true,
  }) async {
    var query = _client
        .from('offers')
        .select()
        .eq('supplier_id', supplierId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
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

    if (cleanTitle.isEmpty || cleanDescription.isEmpty) {
      throw ArgumentError('يرجى إدخال عنوان العرض ووصفه.');
    }

    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError('تاريخ انتهاء العرض يجب أن يكون بعد بدايته.');
    }

    if (discountPercentage != null &&
        (discountPercentage <= 0 || discountPercentage > 100)) {
      throw ArgumentError('نسبة الخصم يجب أن تكون أكبر من صفر وحتى 100%.');
    }

    final data = <String, dynamic>{
      'supplier_id': _userId,
      'title': cleanTitle,
      'description': cleanDescription,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'image_url': _emptyToNull(imageUrl),
      'is_active': true,
    };

    final activity = _emptyToNull(activityType);
    if (activity != null) {
      data['activity_type'] = activity;
    }

    if (discountPercentage != null) {
      data['discount_percentage'] = discountPercentage;
    }

    final response = await _client
        .from('offers')
        .insert(data)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// إيقاف عرض يملكه المورد الحالي.
  Future<void> deactivateOffer(String offerId) async {
    await _client
        .from('offers')
        .update({'is_active': false})
        .eq('id', offerId)
        .eq('supplier_id', _userId);
  }

  /// حذف عرض يملكه المورد الحالي.
  Future<void> deleteOffer(String offerId) async {
    await _client
        .from('offers')
        .delete()
        .eq('id', offerId)
        .eq('supplier_id', _userId);
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
