import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryService {
  CategoryService({SupabaseClient? client})
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
      throw StateError('اتصال Supabase غير متاح.');
    }

    return client;
  }

  /// جلب الأقسام الرئيسية والفرعية.
  Future<List<Map<String, dynamic>>> getCategories({
    String? activityType,
    String? activityCode,
    bool activeOnly = true,
    int limit = 200,
  }) async {
    _validateLimit(limit);

    final activity = _emptyToNull(activityType);

    // Prefer the ERP's canonical item-category tree: this is the live master catalogue edited
    // from the desktop program, including binary images stored in PostgreSQL.
    try {
      var resolvedActivityCode = _normalizeActivityCode(activityCode);
      if (activity != null && resolvedActivityCode == null) {
        final activityRow = await _requireClient
            .from('activity_types')
            .select('code,name')
            .eq('name', activity)
            .eq('is_active', true)
            .maybeSingle();
        resolvedActivityCode = _normalizeActivityCode(
          activityRow?['code']?.toString() ?? activity,
        );
      }
      // Never query the entire cross-activity catalogue when the selected activity
      // cannot be resolved. That previously mixed unrelated categories in the app.
      if (activity != null && (resolvedActivityCode == null || resolvedActivityCode.isEmpty)) {
        return const <Map<String, dynamic>>[];
      }
      var categoriesQuery = _requireClient
          .from('erp_item_categories')
          .select('id,parent_id,category_code:category_code,category_name:category_name,category_name_en:category_name_en,activity_code,is_active,show_in_app,image_data,image_mime_type');
      if (activeOnly) {
        categoriesQuery = categoriesQuery.eq('is_active', true).eq('show_in_app', true);
      }
      if (resolvedActivityCode != null && resolvedActivityCode.isNotEmpty) {
        categoriesQuery = categoriesQuery.eq('activity_code', resolvedActivityCode);
      }
      final categoryRows = await categoriesQuery.order('category_name').limit(limit);
      final categories = (categoryRows as List).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        return <String, dynamic>{
          ...row,
          'name': row['category_name'],
          'name_en': row['category_name_en'],
          'activity_type': activity,
          'sort_order': row['category_code']?.toString() ?? '',
          'icon': null,
          'image_data': _decodePostgresBytea(row['image_data']),
        };
      }).toList(growable: false);
      if (categories.isNotEmpty) return categories;
    } catch (_) {
      // Preserve compatibility with the legacy app catalogue if the ERP tree
      // is not available yet or this activity has no item categories.
    }

    var query = _requireClient.from('categories').select();
    if (activeOnly) query = query.eq('is_active', true);
    if (activity != null) query = query.eq('activity_type', activity);
    final rows = await query.order('sort_order').order('name').limit(limit);
    return (rows as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      row['image_data'] = _decodePostgresBytea(row['image_data']);
      return row;
    }).toList(growable: false);
  }

  /// جلب قسم باستخدام معرّفه.
  Future<Map<String, dynamic>?> getCategoryById(
    int categoryId,
  ) async {
    _validateId(categoryId, 'القسم');

    final result = await _requireClient
        .from('categories')
        .select()
        .eq('id', categoryId)
        .maybeSingle();

    if (result == null) return null;

    final row = Map<String, dynamic>.from(result);
    row['image_data'] = _decodePostgresBytea(row['image_data']);
    return row;
  }

  /// جلب الأقسام الفرعية لقسم رئيسي.
  Future<List<Map<String, dynamic>>> getSubcategories(
    int parentId, {
    int limit = 200,
  }) async {
    _validateId(parentId, 'القسم الرئيسي');
    _validateLimit(limit);

    final rows = await _requireClient
        .from('categories')
        .select()
        .eq('parent_id', parentId)
        .eq('is_active', true)
        .order('sort_order')
        .order('name')
        .limit(limit);

    return (rows as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      row['image_data'] = _decodePostgresBytea(row['image_data']);
      return row;
    }).toList(growable: false);
  }

  /// إنشاء قسم جديد.
  Future<Map<String, dynamic>> createCategory({
    required String name,
    int? parentId,
    String? icon,
    String? imageUrl,
    Uint8List? imageData,
    String? imageMimeType,
    String? activityType,
    int sortOrder = 0,
  }) async {
    final cleanName = _requiredText(name, 'اسم القسم');

    if (cleanName.length > 120) {
      throw ArgumentError('اسم القسم يجب ألا يتجاوز 120 حرفًا.');
    }

    if (parentId != null) {
      _validateId(parentId, 'القسم الرئيسي');
    }

    if (sortOrder < 0) {
      throw ArgumentError('ترتيب القسم لا يمكن أن يكون سالبًا.');
    }

    final cleanIcon = _emptyToNull(icon);
    final cleanActivity = _emptyToNull(activityType);
    final cleanImageUrl = imageData == null ? _emptyToNull(imageUrl) : null;
    final cleanImageMimeType = _emptyToNull(imageMimeType);
    if (imageData != null && imageData.isEmpty) {
      throw ArgumentError('ملف صورة القسم فارغ.');
    }
    if (imageData != null && imageData.length > 5 * 1024 * 1024) {
      throw ArgumentError('حجم صورة القسم يجب ألا يتجاوز 5 ميجابايت.');
    }
    if (imageData != null && cleanImageMimeType == null) {
      throw ArgumentError('نوع ملف الصورة مطلوب.');
    }

    if (cleanIcon != null && cleanIcon.length > 80) {
      throw ArgumentError('اسم أيقونة القسم طويل أكثر من اللازم.');
    }

    if (cleanActivity != null && cleanActivity.length > 120) {
      throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
    }

    if (cleanImageUrl != null) {
      _validateImageUrl(cleanImageUrl);
    }

    final result = await _requireClient
        .from('categories')
        .insert({
          'name': cleanName,
          'parent_id': parentId,
          'icon': cleanIcon,
          'image_url': cleanImageUrl,
          'image_data': imageData == null ? null : _toPostgresBytea(imageData),
          'image_mime_type': cleanImageMimeType,
          'activity_type': cleanActivity,
          'sort_order': sortOrder,
          'is_active': true,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(result);
  }

  /// تعديل بيانات قسم موجود.
  Future<void> updateCategory({
    required int categoryId,
    String? name,
    int? parentId,
    String? icon,
    String? imageUrl,
    Uint8List? imageData,
    String? imageMimeType,
    String? activityType,
    int? sortOrder,
    bool? isActive,
  }) async {
    _validateId(categoryId, 'القسم');

    final updates = <String, dynamic>{};

    if (name != null) {
      final cleanName = _requiredText(name, 'اسم القسم');

      if (cleanName.length > 120) {
        throw ArgumentError('اسم القسم يجب ألا يتجاوز 120 حرفًا.');
      }

      updates['name'] = cleanName;
    }

    if (parentId != null) {
      _validateId(parentId, 'القسم الرئيسي');

      if (parentId == categoryId) {
        throw ArgumentError('لا يمكن جعل القسم تابعًا لنفسه.');
      }

      updates['parent_id'] = parentId;
    }

    if (icon != null) {
      final cleanIcon = _emptyToNull(icon);

      if (cleanIcon != null && cleanIcon.length > 80) {
        throw ArgumentError('اسم أيقونة القسم طويل أكثر من اللازم.');
      }

      updates['icon'] = cleanIcon;
    }

    if (imageData != null) {
      if (imageData.isEmpty) throw ArgumentError('ملف صورة القسم فارغ.');
      if (imageData.length > 5 * 1024 * 1024) {
        throw ArgumentError('حجم صورة القسم يجب ألا يتجاوز 5 ميجابايت.');
      }
      final mime = _emptyToNull(imageMimeType);
      if (mime == null) throw ArgumentError('نوع ملف الصورة مطلوب.');
      updates['image_data'] = _toPostgresBytea(imageData);
      updates['image_mime_type'] = mime;
      updates['image_url'] = null;
    } else if (imageUrl != null) {
      final cleanImageUrl = _emptyToNull(imageUrl);

      if (cleanImageUrl != null) {
        _validateImageUrl(cleanImageUrl);
      }

      updates['image_url'] = cleanImageUrl;
    }

    if (activityType != null) {
      final cleanActivity = _emptyToNull(activityType);

      if (cleanActivity != null && cleanActivity.length > 120) {
        throw ArgumentError('نوع النشاط طويل أكثر من اللازم.');
      }

      updates['activity_type'] = cleanActivity;
    }

    if (sortOrder != null) {
      if (sortOrder < 0) {
        throw ArgumentError('ترتيب القسم لا يمكن أن يكون سالبًا.');
      }

      updates['sort_order'] = sortOrder;
    }

    if (isActive != null) {
      updates['is_active'] = isActive;
    }

    if (updates.isEmpty) return;

    await _requireClient
        .from('categories')
        .update(updates)
        .eq('id', categoryId);
  }

  /// تفعيل قسم.
  Future<void> activateCategory(int categoryId) async {
    _validateId(categoryId, 'القسم');

    await _requireClient
        .from('categories')
        .update({'is_active': true})
        .eq('id', categoryId);
  }

  /// تعطيل قسم دون حذفه نهائيًا.
  Future<void> deactivateCategory(int categoryId) async {
    _validateId(categoryId, 'القسم');

    await _requireClient
        .from('categories')
        .update({'is_active': false})
        .eq('id', categoryId);
  }

  void _validateId(int id, String fieldName) {
    if (id <= 0) {
      throw ArgumentError('معرّف $fieldName غير صالح.');
    }
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 500) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و500.');
    }
  }

  String _requiredText(String? value, String fieldName) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      throw ArgumentError('يرجى إدخال $fieldName.');
    }

    return cleaned;
  }

  /// Normalize old ACTnnn and numeric activity identifiers to the
  /// canonical 01..20 codes used by erp_item_categories.
  String? _normalizeActivityCode(String? value) {
    final clean = _emptyToNull(value)?.toUpperCase();
    if (clean == null) return null;
    final legacy = RegExp(r'^ACT([0-9]{3})$').firstMatch(clean);
    if (legacy != null) {
      final number = int.tryParse(legacy.group(1)!);
      return number == null ? clean : number.toString().padLeft(2, '0');
    }
    if (RegExp(r'^[0-9]{1,2}$').hasMatch(clean)) {
      return int.parse(clean).toString().padLeft(2, '0');
    }
    const aliases = <String, String>{
      'FOOD': '01', 'مواد غذائية': '01', 'FOODSTUFFS': '01',
      'BUILDING': '02', 'لوازم بناء': '02',
      'CLOTHING': '03', 'ملابس واكسسوارات': '03',
      'ELECTRONICS': '04', 'أجهزة وإلكترونيات': '04',
      'VEHICLES': '05', 'سيارات ومعدات': '05',
      'SHIPPING': '06', 'خدمات شحن ونقل': '06',
      'FURNITURE': '07', 'أثاث وديكورات': '07',
    };
    return aliases[clean] ?? clean;
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  Uint8List? _decodePostgresBytea(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    final raw = value?.toString().trim() ?? '';
    final prefixLength = raw.startsWith(r'\\x') ? 3 : raw.startsWith(r'\x') ? 2 : 0;
    if (prefixLength == 0 || raw.length <= prefixLength) return null;
    final hex = raw.substring(prefixLength);
    if (hex.isEmpty || hex.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        hex.length ~/ 2,
        (index) => int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16),
      ));
    } catch (_) {
      return null;
    }
  }

  String _toPostgresBytea(Uint8List bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return r'\x' + hex;
  }

  void _validateImageUrl(String value) {
    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw ArgumentError('رابط صورة القسم غير صالح.');
    }
  }
}
