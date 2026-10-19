import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierOfferService {
  SupplierOfferService({SupabaseClient? client}) : _client = client;

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

  /// جلب عروض المورد الحالي.
  Future<List<Map<String, dynamic>>> getMyOffers({
    bool activeOnly = false,
  }) async {
    var query = _requireClient
        .from('offers')
        .select()
        .eq('supplier_id', _userId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final rows = await query.order(
      'created_at',
      ascending: false,
    );

    return _mapRows(rows);
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
    String magazineColor = '#FFA015',
    List<String> targetGovernorates = const [],
    List<String> targetDistricts = const [],
    List<String> targetAreas = const [],
    List<String> targetCustomerTypes = const [],
  }) async {
    final cleanTitle = _requiredText(
      title,
      'عنوان العرض مطلوب.',
    );

    if (cleanTitle.length > 200) {
      throw ArgumentError(
        'عنوان العرض يجب ألا يتجاوز 200 حرف.',
      );
    }

    _validateDates(startsAt, endsAt);
    _validateDiscount(discountPercentage);

    final cleanDescription = _clean(description);
    final cleanImageUrl = _clean(imageUrl);
    final cleanActivityType = _clean(activityType);

    if (cleanDescription != null &&
        cleanDescription.length > 3000) {
      throw ArgumentError(
        'وصف العرض يجب ألا يتجاوز 3000 حرف.',
      );
    }

    if (cleanActivityType != null &&
        cleanActivityType.length > 120) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
    }

    if (cleanImageUrl != null) {
      _validateWebUrl(cleanImageUrl, 'رابط صورة العرض غير صحيح.');
    }

    final response = await _requireClient
        .from('offers')
        .insert({
          'supplier_id': _userId,
          'title': cleanTitle,
          'description': cleanDescription,
          'start_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'image_url': cleanImageUrl,
          'activity_type': cleanActivityType,
          'discount_percentage': discountPercentage,
          'magazine_color': magazineColor,
          'target_governorates': targetGovernorates,
          'target_districts': targetDistricts,
          'target_areas': targetAreas,
          'target_customer_types': targetCustomerTypes,
          'is_active': true,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// إنشاء عرض مرتبط بصنف محدد وحفظ السعرين في offer_items.
  Future<Map<String, dynamic>> createProductOffer({
    required String title,
    required String productName,
    required String? productId,
    required double originalPrice,
    required double offerPrice,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    String? imageUrl,
    String? activityType,
    double? discountPercentage,
    String magazineColor = '#FFA015',
    List<String> targetGovernorates = const [],
    List<String> targetDistricts = const [],
    List<String> targetAreas = const [],
    List<String> targetCustomerTypes = const [],
  }) async {
    if (!originalPrice.isFinite || !offerPrice.isFinite ||
        originalPrice < 0 || offerPrice < 0) {
      throw ArgumentError('الأسعار يجب أن تكون أرقامًا صحيحة غير سالبة.');
    }
    final cleanTitle = _requiredText(title, 'عنوان العرض مطلوب.');
    _validateDates(startsAt, endsAt);
    _validateDiscount(discountPercentage);
    final cleanImageUrl = _clean(imageUrl);
    if (cleanImageUrl != null) {
      _validateWebUrl(cleanImageUrl, 'رابط صورة العرض غير صحيح.');
    }

    final client = _requireClient;
    final offer = await client.from('offers').insert({
      'supplier_id': _userId,
      'title': cleanTitle,
      'description': _clean(description),
      'image_url': cleanImageUrl,
      'start_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'activity_type': _clean(activityType),
      'discount_percentage': discountPercentage,
      'magazine_color': magazineColor,
      'target_governorates': targetGovernorates,
      'target_districts': targetDistricts,
      'target_areas': targetAreas,
      'target_customer_types': targetCustomerTypes,
      'is_active': true,
    }).select().single();

    final offerId = offer['id'];
    if (offerId == null) {
      throw StateError('تم إنشاء العرض لكن تعذر الحصول على معرّفه.');
    }

    await client.from('offer_items').insert({
      'offer_id': offerId,
      if (productId != null && productId.trim().isNotEmpty)
        'product_id': productId.trim(),
      'product_name': _requiredText(productName, 'اسم الصنف مطلوب.'),
      'original_price': originalPrice,
      'offer_price': offerPrice,
      'discount_percentage': discountPercentage,
    });

    return Map<String, dynamic>.from(offer);
  }

  /// تعديل عرض يملكه المورد الحالي.
  Future<void> updateOffer({
    required String offerId,
    String? title,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? imageUrl,
    double? discountPercentage,
    bool? isActive,
  }) async {
    final cleanOfferId = _requiredText(
      offerId,
      'معرّف العرض مطلوب.',
    );

    final userId = _userId;
    final updates = <String, dynamic>{};

    if (title != null) {
      final cleanTitle = _requiredText(
        title,
        'عنوان العرض مطلوب.',
      );

      if (cleanTitle.length > 200) {
        throw ArgumentError(
          'عنوان العرض يجب ألا يتجاوز 200 حرف.',
        );
      }

      updates['title'] = cleanTitle;
    }

    if (description != null) {
      final cleanDescription = _clean(description);

      if (cleanDescription != null &&
          cleanDescription.length > 3000) {
        throw ArgumentError(
          'وصف العرض يجب ألا يتجاوز 3000 حرف.',
        );
      }

      updates['description'] = cleanDescription;
    }

    if (imageUrl != null) {
      final cleanImageUrl = _clean(imageUrl);

      if (cleanImageUrl != null) {
        _validateWebUrl(
          cleanImageUrl,
          'رابط صورة العرض غير صحيح.',
        );
      }

      updates['image_url'] = cleanImageUrl;
    }

    if (discountPercentage != null) {
      _validateDiscount(discountPercentage);
      updates['discount_percentage'] = discountPercentage;
    }

    if (startsAt != null || endsAt != null) {
      final current = await _requireClient
          .from('offers')
          .select('start_at, ends_at')
          .eq('id', cleanOfferId)
          .eq('supplier_id', userId)
          .maybeSingle();

      if (current == null) {
        throw StateError(
          'العرض غير موجود أو لا تملك صلاحية تعديله.',
        );
      }

      final currentStart = DateTime.tryParse(
        current['start_at']?.toString() ?? '',
      );

      final currentEnd = DateTime.tryParse(
        current['ends_at']?.toString() ?? '',
      );

      if (currentStart == null || currentEnd == null) {
        throw StateError(
          'تعذر قراءة تواريخ العرض الحالية.',
        );
      }

      final effectiveStart = startsAt ?? currentStart;
      final effectiveEnd = endsAt ?? currentEnd;

      _validateDates(effectiveStart, effectiveEnd);

      if (startsAt != null) {
        updates['start_at'] =
            startsAt.toUtc().toIso8601String();
      }

      if (endsAt != null) {
        updates['ends_at'] =
            endsAt.toUtc().toIso8601String();
      }
    }

    if (isActive != null) {
      updates['is_active'] = isActive;
    }

    if (updates.isEmpty) {
      return;
    }

    await _requireClient
        .from('offers')
        .update(updates)
        .eq('id', cleanOfferId)
        .eq('supplier_id', userId);
  }

  /// إيقاف العرض دون حذفه.
  Future<void> deactivateOffer(int offerId) async {
    if (offerId <= 0) {
      throw ArgumentError('رقم العرض غير صالح.');
    }

    await _requireClient
        .from('offers')
        .update({'is_active': false})
        .eq('id', offerId)
        .eq('supplier_id', _userId);
  }

  /// حذف عرض يملكه المورد الحالي.
  Future<void> deleteOffer(int offerId) async {
    if (offerId <= 0) {
      throw ArgumentError('رقم العرض غير صالح.');
    }

    await _requireClient
        .from('offers')
        .delete()
        .eq('id', offerId)
        .eq('supplier_id', _userId);
  }

  void _validateDates(DateTime startsAt, DateTime endsAt) {
    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError(
        'تاريخ انتهاء العرض يجب أن يكون بعد تاريخ بدايته.',
      );
    }
  }

  void _validateDiscount(double? discount) {
    if (discount != null &&
        (!discount.isFinite || discount < 0 || discount > 100)) {
      throw ArgumentError(
        'نسبة الخصم يجب أن تكون بين 0 و100.',
      );
    }
  }

  void _validateWebUrl(String value, String message) {
    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw ArgumentError(message);
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
      throw StateError('تعذر قراءة بيانات العروض.');
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
