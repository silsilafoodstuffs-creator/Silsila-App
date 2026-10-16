import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryService {
  CategoryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// جلب الأقسام الرئيسية والفرعية.
  Future<List<Map<String, dynamic>>> getCategories({
    String? activityType,
    bool activeOnly = true,
  }) async {
    var query = _client.from('categories').select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    if (activityType != null && activityType.trim().isNotEmpty) {
      query = query.eq('activity_type', activityType.trim());
    }

    final rows = await query.order('sort_order').order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  /// جلب قسم بواسطة المعرّف.
  Future<Map<String, dynamic>?> getCategoryById(
    int categoryId,
  ) async {
    return await _client
        .from('categories')
        .select()
        .eq('id', categoryId)
        .maybeSingle();
  }

  /// جلب الأقسام الفرعية لقسم رئيسي.
  Future<List<Map<String, dynamic>>> getSubcategories(
    int parentId,
  ) async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('parent_id', parentId)
        .eq('is_active', true)
        .order('sort_order')
        .order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  /// إضافة قسم جديد.
  Future<Map<String, dynamic>> createCategory({
    required String name,
    int? parentId,
    String? icon,
    String? imageUrl,
    int sortOrder = 0,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('اسم القسم مطلوب.');
    }

    final result = await _client
        .from('categories')
        .insert({
          'name': cleanName,
          'parent_id': parentId,
          'icon': icon,
          'image_url': imageUrl,
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
    int? sortOrder,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) {
      if (name.trim().isEmpty) {
        throw ArgumentError('اسم القسم لا يمكن أن يكون فارغًا.');
      }
      updates['name'] = name.trim();
    }

    if (parentId != null) updates['parent_id'] = parentId;
    if (icon != null) updates['icon'] = icon;
    if (imageUrl != null) updates['image_url'] = imageUrl;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (isActive != null) updates['is_active'] = isActive;

    if (updates.isEmpty) return;

    await _client
        .from('categories')
        .update(updates)
        .eq('id', categoryId);
  }

  /// تعطيل قسم دون حذفه نهائيًا.
  Future<void> deactivateCategory(int categoryId) async {
    await _client
        .from('categories')
        .update({'is_active': false})
        .eq('id', categoryId);
  }
}
