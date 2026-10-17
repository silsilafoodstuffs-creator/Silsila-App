import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewService {
  ReviewService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
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
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }

    final response = await _client
        .from('reviews')
        .select()
        .eq('supplier_id', supplierId.trim())
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// حساب متوسط التقييم وعدد التقييمات.
  Future<Map<String, dynamic>> getSupplierRating(
    String supplierId,
  ) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError('معرّف المورد مطلوب.');
    }
    final cleanSupplierId = supplierId.trim();
    final reviews = await _client
        .from('reviews')
        .select('rating')
        .eq('supplier_id', cleanSupplierId);

    final rows = List<Map<String, dynamic>>.from(reviews);
    var total = 0.0;
    var validCount = 0;

    for (final review in rows) {
      final rawRating = review['rating'];
      final rating = rawRating is num
          ? rawRating.toDouble()
          : double.tryParse(rawRating?.toString() ?? '');

      // Ignore malformed rows instead of including them in the average's
      // denominator or presenting an invalid score.
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

  /// إضافة تقييم لمورد بعد إتمام التعامل.
  Future<Map<String, dynamic>> addReview({
    required String supplierId,
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('التقييم يجب أن يكون من نجمة إلى خمس نجوم.');
    }

    if (supplierId.trim().isEmpty || orderId.trim().isEmpty) {
      throw ArgumentError('معرّف المورد والطلب مطلوبان.');
    }
    final parsedOrderId = int.tryParse(orderId.trim());
    if (parsedOrderId == null || parsedOrderId <= 0) {
      throw ArgumentError('رقم الطلب المرتبط بالتقييم غير صحيح.');
    }
    if ((comment ?? '').trim().length > 3000) {
      throw ArgumentError('تعليق التقييم يجب ألا يتجاوز 3000 حرف.');
    }

    final response = await _client
        .from('reviews')
        .insert({
          'customer_id': _userId,
          'supplier_id': supplierId.trim(),
          'order_id': orderId.trim(),
          'rating': rating,
          'comment': _emptyToNull(comment),
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// تعديل تقييم سابق يملكه المستخدم الحالي.
  Future<Map<String, dynamic>> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('التقييم يجب أن يكون من نجمة إلى خمس نجوم.');
    }
    if (reviewId.trim().isEmpty) {
      throw ArgumentError('معرّف التقييم مطلوب.');
    }
    if ((comment ?? '').trim().length > 3000) {
      throw ArgumentError('تعليق التقييم يجب ألا يتجاوز 3000 حرف.');
    }

    final response = await _client
        .from('reviews')
        .update({
          'rating': rating,
          'comment': _emptyToNull(comment),
        })
        .eq('id', reviewId.trim())
        .eq('customer_id', _userId)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// حذف تقييم يملكه المستخدم الحالي.
  Future<void> deleteReview(String reviewId) async {
    final id = reviewId.trim();
    if (id.isEmpty) {
      throw ArgumentError('معرّف التقييم مطلوب.');
    }
    await _client
        .from('reviews')
        .delete()
        .eq('id', id)
        .eq('customer_id', _userId);
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
