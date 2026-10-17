import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String productBucket = 'products';
  static const String offerBucket = 'offers';
  static const String storyBucket = 'stories';
  static const String profileBucket = 'profiles';

  static const Set<String> _allowedBuckets = {
    productBucket,
    offerBucket,
    storyBucket,
    profileBucket,
  };

  static const Set<String> _allowedImageTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  static const Set<String> _allowedStoryVideoTypes = {
    'video/mp4',
    'video/webm',
    'video/quicktime',
  };

  void _validateBucket(String bucket) {
    if (!_allowedBuckets.contains(bucket)) {
      throw ArgumentError('نوع التخزين غير مسموح به.');
    }
  }

  void _validateContentType(String bucket, String contentType) {
    final normalizedType = contentType.trim().toLowerCase();
    final isImage = _allowedImageTypes.contains(normalizedType);
    final isStoryVideo = bucket == storyBucket &&
        _allowedStoryVideoTypes.contains(normalizedType);

    if (!isImage && !isStoryVideo) {
      throw ArgumentError(
        bucket == storyBucket
            ? 'صيغة القصة يجب أن تكون صورة أو فيديو مدعومًا.'
            : 'صيغة الصورة غير مدعومة.',
      );
    }
  }

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// رفع صورة أو ملف إلى مجلد المستخدم.
  Future<String> uploadFile({
    required String bucket,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    _validateBucket(bucket);
    _validateContentType(bucket, contentType);

    if (bytes.isEmpty) {
      throw ArgumentError('الملف فارغ.');
    }

    final cleanName = fileName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    if (cleanName.isEmpty) {
      throw ArgumentError('اسم الملف غير صالح.');
    }

    final path =
        '$_userId/${DateTime.now().toUtc().millisecondsSinceEpoch}_$cleanName';

    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// رفع صورة منتج.
  Future<String> uploadProductImage({
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) {
    return uploadFile(
      bucket: productBucket,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// رفع صورة عرض.
  Future<String> uploadOfferImage({
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) {
    return uploadFile(
      bucket: offerBucket,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// رفع صورة أو فيديو قصة.
  Future<String> uploadStoryMedia({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) {
    return uploadFile(
      bucket: storyBucket,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// رفع صورة الملف الشخصي.
  Future<String> uploadProfileImage({
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) {
    return uploadFile(
      bucket: profileBucket,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// حذف ملف من مساره داخل Bucket.
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    _validateBucket(bucket);
    final cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      throw ArgumentError('مسار الملف مطلوب.');
    }

    // لا يُسمح بالحذف إلا من مجلد المستخدم الحالي.
    if (!cleanPath.startsWith('$_userId/')) {
      throw StateError('لا يمكنك حذف ملف لا يخص حسابك.');
    }

    await _client.storage.from(bucket).remove([cleanPath]);
  }
}
