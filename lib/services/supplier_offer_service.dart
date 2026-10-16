import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierOfferService {
  SupplierOfferService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// جلب عروض المورد الحالي.
  Future<List<Map<String, dynamic>>> getMyOffers({
    bool activeOnly = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    var query = _client
        .from('offers')
        .select()
        .eq('supplier_id', user.id);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final rows = await query.order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// إنشاء عرض جديد.
  Future<Map<String, dynamic>> createOffer({
    required String title,
    String? description,
    required DateTime startsAt,
    required DateTime endsAt,
    String? imageUrl,
    String? activityType,
    double? discountPercentage,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError('عنوان العرض مطلوب.');
    }

    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError('تاريخ انتهاء العرض يجب أن يكون بعد تاريخ بدايته.');
    }

    if (discountPercentage != null &&
        (discountPercentage < 0 || discountPercentage > 100)) {
      throw ArgumentError('نسبة الخصم يجب أن تكون بين 0 و100.');
    }

    final result = await _client
        .from('offers')
        .insert({
          'supplier_id': user.id,
          'title': title.trim(),
          'description': description?.trim(),
          'starts_at': startsAt.toIso8601String(),
          'ends_at': endsAt.toIso8601String(),
          'image_url': imageUrl,
          'activity_type': activityType,
          'discount_percentage': discountPercentage,
          'is_active': true,
        })
        .select()
        .single();

    return result;
  }

  /// تعديل عرض يملكه المورد الحالي.
  Future<void> updateOffer({
    required int offerId,
    String? title,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? imageUrl,
    double? discountPercentage,
    bool? isActive,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    final updates = <String, dynamic>{};

    if (title != null) {
      if (title.trim().isEmpty) {
        throw ArgumentError('عنوان العرض مطلوب.');
      }
      updates['title'] = title.trim();
    }

    if (description != null) {
      updates['description'] = description.trim();
    }

    if (startsAt != null) {
      updates['starts_at'] = startsAt.toIso8601String();
    }

    if (endsAt != null) {
      updates['ends_at'] = endsAt.toIso8601String();
    }

    if (startsAt != null || endsAt != null) {
      final current = await _client
          .from('offers')
          .select('starts_at, ends_at')
          .eq('id', offerId)
          .eq('supplier_id', user.id)
          .maybeSingle();

      if (current == null) {
        throw Exception('العرض غير موجود.');
      }

      final effectiveStart =
          startsAt ?? DateTime.parse(current['starts_at'].toString());
      final effectiveEnd =
          endsAt ?? DateTime.parse(current['ends_at'].toString());

      if (!effectiveEnd.isAfter(effectiveStart)) {
        throw ArgumentError('تاريخ انتهاء العرض يجب أن يكون بعد بدايته.');
      }
    }

    if (imageUrl != null) updates['image_url'] = imageUrl;

    if (discountPercentage != null) {
      if (discountPercentage < 0 || discountPercentage > 100) {
        throw ArgumentError('نسبة الخصم يجب أن تكون بين 0 و100.');
      }
      updates['discount_percentage'] = discountPercentage;
    }

    if (isActive != null) updates['is_active'] = isActive;

    if (updates.isEmpty) return;

    await _client
        .from('offers')
        .update(updates)
        .eq('id', offerId)
        .eq('supplier_id', user.id);
  }

  /// إيقاف العرض دون حذفه.
  Future<void> deactivateOffer(int offerId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    await _client
        .from('offers')
        .update({'is_active': false})
        .eq('id', offerId)
        .eq('supplier_id', user.id);
  }

  /// حذف عرض يملكه المورد الحالي.
  Future<void> deleteOffer(int offerId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    await _client
        .from('offers')
        .delete()
        .eq('id', offerId)
        .eq('supplier_id', user.id);
  }
}
