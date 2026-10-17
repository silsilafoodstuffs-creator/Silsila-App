import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryService {
  CategoryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// جلب الأقسام الرئيسية والفرعية.
  Future<List<Map<String, dynamic>>> getCategories({
    String? activityType,
    bool activeOnly = true,
    int limit = 200,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و500.');
    }
    var query = _client.from('categories').select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    if (activityType != null && activityType.trim().isNotEmpty) {
      query = query.eq('activity_type', activityType.trim());
    }

    final rows = await query
        .order('sort_order')
        .order('name')
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// جلب قسم بواسطة المعرّف.
  Future<Map<String, dynamic>?> getCategoryById(
    int categoryId,
  ) async {
    if (categoryId <= 0) {
      throw ArgumentError('معرّف القسم غير صالح.');
    }
    return await _client
        .from('categories')
        .select()
        .eq('id', categoryId)
        .maybeSingle();
  }

  /// جلب الأقسام الفرعية لقسم رئيسي.
  Future<List<Map<String, dynamic>>> getSubcategories(
    int parentId, {
    int limit = 200,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و500.');
    }
    if (parentId <= 0) {
      throw ArgumentError('معرّف القسم الرئيسي غير صالح.');
    }
    final rows = await _client
        .from('categories')
        .select()
        .eq('parent_id', parentId)
        .eq('is_active', true)
        .order('sort_order')
        .order('name')
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// إضافة قسم جديد.
  Future<Map<String, dynamic>> createCategory({
    required String name,
    int? parentId,
    String? icon,
    String? imageUrl,
    String? activityType,
    int sortOrder = 0,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty || cleanName.length > 120) {
      throw ArgumentError('اسم القسم مطلوب ويجب ألا يتجاوز 120 حرفًا.');
    }
    if (parentId != null && parentId <= 0) {
      throw ArgumentError('معرّف القسم الرئيسي غير صالح.');
    }
    if (sortOrder < 0) {
      throw ArgumentError('ترتيب القسم لا يمكن أن يكون سالبًا.');
    }
    if ((icon ?? '').trim().length > 80) {
      throw ArgumentError('اسم أيقونة القسم طويل أكثر من اللازم.');
    }
    if ((imageUrl ?? '').trim().isNotEmpty) {
      final uri = Uri.tryParse(imageUrl!.trim());
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty) {
        throw ArgumentError('رابط صورة القسم غير صالح.');
      }
    }
    if (activityType != null && activityType.trim().length > 120) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
    }

    final result = await _client
        .from('categories')
        .insert({
          'name': cleanName,
          'parent_id': parentId,
          'icon': icon,
          'image_url': imageUrl,
          if (activityType != null && activityType.trim().isNotEmpty)
            'activity_type': activityType.trim(),
          'sort_order': sortOrder,
          'is_active': true,
        })
        .select()
        .single();

    return result;
  }

  /// تعديل بيانات قسم.
  Future<void> updateCategory({
    required int categoryId,
    String? name,
    int? parentId,
    String? icon,
    String? imageUrl,
    String? activityType,
    int? sortOrder,
    bool? isActive,
  }) async {
    if (categoryId <= 0) {
      throw ArgumentError('معرّف القسم غير صالح.');
    }
    final updates = <String, dynamic>{};

    if (name != null) {
      final cleanName = name.trim();
      if (cleanName.isEmpty || cleanName.length > 120) {
        throw ArgumentError('اسم القسم مطلوب ويجب ألا يتجاوز 120 حرفًا.');
      }
      updates['name'] = cleanName;
    }

    if (parentId != null) {
      if (parentId <= 0 || parentId == categoryId) {
        throw ArgumentError('معرّف القسم الرئيسي غير صالح.');
      }
      updates['parent_id'] = parentId;
    }
    if (icon != null) {
      final cleanIcon = icon.trim();
      if (cleanIcon.length > 80) {
        throw ArgumentError('اسم أيقونة القسم طويل أكثر من اللازم.');
      }
      updates['icon'] = cleanIcon.isEmpty ? null : cleanIcon;
    }
    if (imageUrl != null) {
      final cleanImageUrl = imageUrl.trim();
      if (cleanImageUrl.isNotEmpty) {
        final uri = Uri.tryParse(cleanImageUrl);
        if (uri == null ||
            !uri.hasScheme ||
            (uri.scheme != 'https' && uri.scheme != 'http') ||
            uri.host.isEmpty) {
          throw ArgumentError('رابط صورة القسم غير صالح.');
        }
      }
      updates['image_url'] = cleanImageUrl.isEmpty ? null : cleanImageUrl;
    }
    if (activityType != null) {
      final cleanedActivity = activityType.trim();
      if (cleanedActivity.length > 120) {
        throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
      }
      updates['activity_type'] =
          cleanedActivity.isEmpty ? null : cleanedActivity;
    }
    if (sortOrder != null) {
      if (sortOrder < 0) {
        throw ArgumentError('ترتيب القسم لا يمكن أن يكون سالبًا.');
      }
      updates['sort_order'] = sortOrder;
    }
    if (isActive != null) updates['is_active'] = isActive;

    if (updates.isEmpty) return;

    await _client
        .from('categories')
        .update(updates)
        .eq('id', categoryId);
  }

  /// تعطيل قسم دون حذفه نهائيًا.
  Future<void> deactivateCategory(int categoryId) async {
    if (categoryId <= 0) {
      throw ArgumentError('معرّف القسم غير صالح.');
    }
    await _client
        .from('categories')
        .update({'is_active': false})
        .eq('id', categoryId);
  }
}
