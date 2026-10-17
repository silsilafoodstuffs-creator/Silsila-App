import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client})
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

  /// إنشاء حساب جديد باستخدام رقم الهاتف وكلمة المرور.
  Future<AuthResponse> register({
    required String phone,
    required String password,
    Map<String, dynamic> metadata = const {},
  }) async {
    final normalizedPhone = phone.trim();

    if (normalizedPhone.isEmpty) {
      throw ArgumentError('يرجى إدخال رقم الهاتف.');
    }

    if (!_isStrongPassword(password)) {
      throw ArgumentError(
        'كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل، '
        'وحرف كبير وحرف صغير ورقم ورمز.',
      );
    }

    return _requireClient.auth.signUp(
      phone: normalizedPhone,
      password: password,
      data: metadata,
    );
  }

  /// تسجيل الدخول برقم الهاتف وكلمة المرور.
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    if (phone.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('يرجى إدخال رقم الهاتف وكلمة المرور.');
    }

    return _requireClient.auth.signInWithPassword(
      phone: phone.trim(),
      password: password,
    );
  }

  /// تسجيل الخروج من الحساب الحالي.
  Future<void> logout() async {
    await _requireClient.auth.signOut();
  }

  /// إعادة إرسال رمز التحقق إلى الهاتف.
  Future<void> resendPhoneOtp(String phone) async {
    if (phone.trim().isEmpty) {
      throw ArgumentError('يرجى إدخال رقم الهاتف.');
    }

    await _requireClient.auth.resend(
      type: OtpType.sms,
      phone: phone.trim(),
    );
  }

  /// التحقق من رمز الهاتف.
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    if (phone.trim().isEmpty || token.trim().isEmpty) {
      throw ArgumentError('يرجى إدخال رقم الهاتف ورمز التحقق.');
    }

    return _requireClient.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone.trim(),
      token: token.trim(),
    );
  }

  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  /// التحقق من وجود جلسة دخول حالية.
  bool get isLoggedIn => _client?.auth.currentSession != null;

  /// الحصول على معرّف المستخدم الحالي.
  String? get currentUserId => _client?.auth.currentUser?.id;

  /// الحصول على رقم الهاتف المسجل.
  String? get currentPhone => _client?.auth.currentUser?.phone;
}
