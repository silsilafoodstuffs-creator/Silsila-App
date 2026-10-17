import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewService {
  ReviewService({SupabaseClient? client}) : _client = client;

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

  /// جلب تقييمات مورد معين.
  Future<List<Map<String, dynamic>>> getSupplierReviews(
    String supplierId, {
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final cleanSupplierId = _requiredText(
      supplierId,
      'معرّف المورد مطلوب.',
    );

    final response = await _requireClient
        .from('reviews')
        .select()
        .eq('reviewed_user_id', cleanSupplierId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(response);
  }

  /// حساب متوسط التقييم وعدد التقييمات الصحيحة.
  Future<Map<String, dynamic>> getSupplierRating(
    String supplierId,
  ) async {
    final cleanSupplierId = _requiredText(
      supplierId,
      'معرّف المورد مطلوب.',
    );

    final response = await _requireClient
        .from('reviews')
        .select('rating')
        .eq('reviewed_user_id', cleanSupplierId);

    final rows = _mapRows(response);

    var total = 0.0;
    var validCount = 0;

    for (final review in rows) {
      final rawRating = review['rating'];

      final rating = rawRating is num
          ? rawRating.toDouble()
          : double.tryParse(rawRating?.toString() ?? '');

      if (rating == null ||
          !rating.isFinite ||
          rating < 1 ||
          rating > 5) {
        continue;
      }

      total += rating;
      validCount++;
    }

    if (validCount == 0) {
      return {
        'average': 0.0,
        'count': 0,
      };
    }

    return {
      'average': double.parse(
        (total / validCount).toStringAsFixed(1),
      ),
      'count': validCount,
    };
  }

  /// إضافة تقييم لمورد.
  Future<Map<String, dynamic>> addReview({
    required String supplierId,
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    _validateRating(rating);

    final cleanSupplierId = _requiredText(
      supplierId,
      'معرّف المورد مطلوب.',
    );

    final cleanOrderId = _requiredText(
      orderId,
      'رقم الطلب مطلوب.',
    );

    final parsedOrderId = int.tryParse(cleanOrderId);

    if (parsedOrderId == null || parsedOrderId <= 0) {
      throw ArgumentError(
        'رقم الطلب المرتبط بالتقييم غير صحيح.',
      );
    }

    final cleanComment = _cleanComment(comment);
    final reviewerId = _userId;

    if (cleanSupplierId == reviewerId) {
      throw ArgumentError('لا يمكنك تقييم حسابك الشخصي.');
    }

    final response = await _requireClient
        .from('reviews')
        .insert({
          'reviewer_id': reviewerId,
          'reviewed_user_id': cleanSupplierId,
          'order_id': parsedOrderId,
          'rating': rating,
          'comment': cleanComment,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// تعديل تقييم يملكه المستخدم الحالي.
  Future<Map<String, dynamic>> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) async {
    _validateRating(rating);

    final cleanReviewId = _requiredText(
      reviewId,
      'معرّف التقييم مطلوب.',
    );

    final cleanComment = _cleanComment(comment);
    final reviewerId = _userId;

    final response = await _requireClient
        .from('reviews')
        .update({
          'rating': rating,
          'comment': cleanComment,
        })
        .eq('id', cleanReviewId)
        .eq('reviewer_id', reviewerId)
        .select()
        .maybeSingle();

    if (response == null) {
      throw StateError(
        'لم يتم العثور على التقييم أو لا تملك صلاحية تعديله.',
      );
    }

    return Map<String, dynamic>.from(response);
  }

  /// حذف تقييم يملكه المستخدم الحالي.
  Future<void> deleteReview(String reviewId) async {
    final cleanReviewId = _requiredText(
      reviewId,
      'معرّف التقييم مطلوب.',
    );

    final reviewerId = _userId;

    await _requireClient
        .from('reviews')
        .delete()
        .eq('id', cleanReviewId)
        .eq('reviewer_id', reviewerId);
  }

  void _validateRating(int rating) {
    if (rating < 1 || rating > 5) {
      throw ArgumentError(
        'التقييم يجب أن يكون من نجمة إلى خمس نجوم.',
      );
    }
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  String _requiredText(String value, String errorMessage) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError(errorMessage);
    }

    if (cleaned.length > 200) {
      throw ArgumentError('معرّف البيانات أطول من الحد المسموح.');
    }

    if (cleaned.contains(r'\n') || cleaned.contains(r'\r')) {
      throw ArgumentError('معرّف البيانات يحتوي على محارف غير صالحة.');
    }

    return cleaned;
  }

  String? _cleanComment(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    if (cleaned.length > 3000) {
      throw ArgumentError(
        'تعليق التقييم يجب ألا يتجاوز 3000 حرف.',
      );
    }

    return cleaned;
  }

  List<Map<String, dynamic>> _mapRows(dynamic response) {
    if (response is! List) {
      throw StateError('تعذر قراءة بيانات التقييمات.');
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
