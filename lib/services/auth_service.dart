import 'package:supabase_flutter/supabase_flutter.dart';

/// Email-first authentication for Silsila during pre-launch testing.
/// Phone numbers are profile/contact data only; phone OTP is intentionally disabled.
class AuthService {
  AuthService({SupabaseClient? client}) : _client = client ?? _defaultClient;

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

  String _normalizeEmail(String value) => value.trim().toLowerCase();

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+.hasMatch(value);

  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  /// Creates a user with email/password; optional contact details belong in metadata.
  Future<AuthResponse> register({
    required String email,
    required String password,
    Map<String, dynamic> metadata = const {},
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (!_isValidEmail(normalizedEmail)) {
      throw ArgumentError('يرجى إدخال بريد إلكتروني صحيح.');
    }
    if (!_isStrongPassword(password)) {
      throw ArgumentError(
        'كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل، '
        'وحرف كبير وحرف صغير ورقم ورمز.',
      );
    }

    return _requireClient.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: Map<String, dynamic>.from(metadata),
    );
  }

  /// Signs in with email/password only. Phone-based authentication is not enabled.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (!_isValidEmail(normalizedEmail) || password.isEmpty) {
      throw ArgumentError('يرجى إدخال البريد الإلكتروني الصحيح وكلمة المرور.');
    }

    return _requireClient.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  /// Sends a password-reset link to the registered email address.
  Future<void> resetPassword(String email, {String? redirectTo}) async {
    final normalizedEmail = _normalizeEmail(email);
    if (!_isValidEmail(normalizedEmail)) {
      throw ArgumentError('يرجى إدخال بريد إلكتروني صحيح.');
    }
    await _requireClient.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: redirectTo,
    );
  }

  Future<void> logout() async {
    await _requireClient.auth.signOut();
  }

  bool get isLoggedIn => _client?.auth.currentSession != null;

  String? get currentUserId => _client?.auth.currentUser?.id;

  String? get currentEmail => _client?.auth.currentUser?.email;
}
).hasMatch(value);

  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  /// Creates a user with email/password; optional contact details belong in metadata.
  Future<AuthResponse> register({
    required String email,
    required String password,
    Map<String, dynamic> metadata = const {},
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (!_isValidEmail(normalizedEmail)) {
      throw ArgumentError('يرجى إدخال بريد إلكتروني صحيح.');
    }
    if (!_isStrongPassword(password)) {
      throw ArgumentError(
        'كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل، '
        'وحرف كبير وحرف صغير ورقم ورمز.',
      );
    }

    return _requireClient.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: Map<String, dynamic>.from(metadata),
    );
  }

  /// Signs in with email/password only. Phone-based authentication is not enabled.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (!_isValidEmail(normalizedEmail) || password.isEmpty) {
      throw ArgumentError('يرجى إدخال البريد الإلكتروني الصحيح وكلمة المرور.');
    }

    return _requireClient.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  /// Sends a password-reset link to the registered email address.
  Future<void> resetPassword(String email, {String? redirectTo}) async {
    final normalizedEmail = _normalizeEmail(email);
    if (!_isValidEmail(normalizedEmail)) {
      throw ArgumentError('يرجى إدخال بريد إلكتروني صحيح.');
    }
    await _requireClient.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: redirectTo,
    );
  }

  Future<void> logout() async {
    await _requireClient.auth.signOut();
  }

  bool get isLoggedIn => _client?.auth.currentSession != null;

  String? get currentUserId => _client?.auth.currentUser?.id;

  String? get currentEmail => _client?.auth.currentUser?.email;
}
