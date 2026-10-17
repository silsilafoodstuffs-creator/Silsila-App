import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

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

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxStoryVideoBytes = 50 * 1024 * 1024;

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

  void _validateBucket(String bucket) {
    if (!_allowedBuckets.contains(bucket)) {
      throw ArgumentError('نوع التخزين غير مسموح به.');
    }
  }

  String _validateContentType(String bucket, String contentType) {
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

    return normalizedType;
  }

  void _validateFileSize({
    required String bucket,
    required String contentType,
    required int byteLength,
  }) {
    if (byteLength <= 0) {
      throw ArgumentError('الملف فارغ.');
    }

    final isVideo = _allowedStoryVideoTypes.contains(contentType);
    final maximum = isVideo ? maxStoryVideoBytes : maxImageBytes;

    if (byteLength > maximum) {
      final limitMb = maximum ~/ (1024 * 1024);

      throw ArgumentError(
        'حجم الملف يتجاوز الحد المسموح وهو $limitMb ميجابايت.',
      );
    }
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();

    if (trimmed.isEmpty) {
      throw ArgumentError('اسم الملف مطلوب.');
    }

    final normalized = trimmed
        .replaceAll(r'\', '/')
        .split('/')
        .last
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    if (normalized.isEmpty ||
        normalized == '.' ||
        normalized == '..') {
      throw ArgumentError('اسم الملف غير صالح.');
    }

    return normalized;
  }

  /// رفع صورة أو فيديو قصة إلى مجلد المستخدم.
  Future<String> uploadFile({
    required String bucket,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    _validateBucket(bucket);

    final normalizedType = _validateContentType(
      bucket,
      contentType,
    );

    _validateFileSize(
      bucket: bucket,
      contentType: normalizedType,
      byteLength: bytes.length,
    );

    final cleanName = _sanitizeFileName(fileName);
    final userId = _userId;

    final timestamp = DateTime.now()
        .toUtc()
        .millisecondsSinceEpoch;

    final path = '$userId/${timestamp}_$cleanName';
    final client = _requireClient;

    await client.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: normalizedType,
        upsert: false,
      ),
    );

    return client.storage.from(bucket).getPublicUrl(path);
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

  /// حذف ملف من مساره داخل مساحة التخزين.
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    _validateBucket(bucket);

    final cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      throw ArgumentError('مسار الملف مطلوب.');
    }

    if (cleanPath.startsWith('/') ||
        cleanPath.contains(r'\') ||
        cleanPath.split('/').any(
          (segment) => segment == '.' || segment == '..',
        )) {
      throw ArgumentError('مسار الملف غير صالح.');
    }

    final userId = _userId;

    if (!cleanPath.startsWith('$userId/')) {
      throw StateError(
        'لا يمكنك حذف ملف لا يخص حسابك.',
      );
    }

    await _requireClient.storage
        .from(bucket)
        .remove([cleanPath]);
  }
}
