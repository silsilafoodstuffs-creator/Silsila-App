import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads app-management images to a private Supabase Storage bucket.
///
/// Create the bucket and restrictive Storage policies before calling this class.
/// The returned value is a storage path, not a public URL. Register that path
/// in erp_app_assets only after upload succeeds.
class ErpAppAssetStorage {
  ErpAppAssetStorage({
    SupabaseClient? client,
    this.bucket = 'erp-app-assets',
    this.maxBytes = 8 * 1024 * 1024,
  }) : _client = client ?? _defaultClient;

  final SupabaseClient? _client;
  final String bucket;
  final int maxBytes;

  static SupabaseClient? get _defaultClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _db {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase غير مهيأ. قم بتهيئته قبل رفع الصور.');
    }
    if (client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول بحساب مخوّل لإدارة صور التطبيق.');
    }
    return client;
  }

  /// Uploads an image and returns its private bucket path.
  ///
  /// [companyId] and [appId] are used to partition object paths, but the
  /// Storage policies must independently verify that the signed-in user belongs
  /// to the company and may manage this app. Path values are sanitized.
  Future<String> uploadImage({
    required String companyId,
    required String appId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    String? assetType,
  }) async {
    if (companyId.trim().isEmpty || appId.trim().isEmpty) {
      throw ArgumentError('معرّف الشركة والتطبيق مطلوبان.');
    }
    if (bytes.isEmpty) throw ArgumentError('الملف فارغ.');
    if (bytes.length > maxBytes) {
      throw ArgumentError('حجم الصورة يتجاوز الحد المسموح (8 ميجابايت).');
    }
    const supportedTypes = <String, String>{
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'image/gif': 'gif',
    };
    final extension = supportedTypes[contentType.toLowerCase().trim()];
    if (extension == null) {
      throw ArgumentError('نوع الصورة غير مدعوم. استخدم JPG أو PNG أو WEBP أو GIF.');
    }
    const supportedAssetTypes = {
      'app_logo', 'splash', 'app_icon', 'category', 'item',
      'supplier', 'customer', 'shipping_company', 'other',
    };
    final type = assetType ?? 'other';
    if (!supportedAssetTypes.contains(type)) {
      throw ArgumentError('تصنيف الصورة غير مدعوم.');
    }

    final company = _safeSegment(companyId);
    final app = _safeSegment(appId);
    final original = fileName.split(RegExp(r'[/\\\\]')).last;
    final stem = original.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final path = '$company/$app/$type/${timestamp}_${stem.isEmpty ? 'image' : stem}.$extension';

    await _db.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType.toLowerCase().trim(),
        upsert: false,
      ),
    );
    return path;
  }

  /// Deletes a private object only when its path belongs to the supplied company and app.
  Future<void> deleteImage({
    required String companyId,
    required String appId,
    required String storagePath,
  }) async {
    final company = _safeSegment(companyId);
    final app = _safeSegment(appId);
    final expectedPrefix = '$company/$app/';
    if (!storagePath.startsWith(expectedPrefix) || storagePath.contains('..')) {
      throw ArgumentError('مسار الصورة لا يتبع الشركة والتطبيق المحددين.');
    }
    await _db.storage.from(bucket).remove([storagePath]);
  }

  /// Creates a short-lived URL for a private object; do not store this URL as
  /// the asset's canonical identifier. Store the returned path instead.
  Future<String> createSignedImageUrl({
    required String storagePath,
    Duration expiresIn = const Duration(minutes: 15),
  }) async {
    if (storagePath.trim().isEmpty) throw ArgumentError('مسار الصورة مطلوب.');
    return _db.storage
        .from(bucket)
        .createSignedUrl(storagePath, expiresIn.inSeconds);
  }

  static String _safeSegment(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      throw ArgumentError('معرّف المسار غير صالح.');
    }
    return cleaned;
  }
}
