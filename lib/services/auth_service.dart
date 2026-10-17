
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
    final normalizedPhone = _normalizePhone(phone);

    if (!_isValidPhone(normalizedPhone)) {
      throw ArgumentError('يرجى إدخال رقم هاتف صحيح.');
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
      data: Map<String, dynamic>.from(metadata),
    );
  }

  /// تسجيل الدخول برقم الهاتف وكلمة المرور.
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = _normalizePhone(phone);

    if (!_isValidPhone(normalizedPhone) || password.isEmpty) {
      throw ArgumentError(
        'يرجى إدخال رقم الهاتف الصحيح وكلمة المرور.',
      );
    }

    return _requireClient.auth.signInWithPassword(
      phone: normalizedPhone,
      password: password,
    );
  }

  /// تسجيل الخروج من الحساب الحالي.
  Future<void> logout() async {
    await _requireClient.auth.signOut();
  }

  /// إعادة إرسال رمز التحقق إلى الهاتف.
  Future<void> resendPhoneOtp(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

    if (!_isValidPhone(normalizedPhone)) {
      throw ArgumentError('يرجى إدخال رقم هاتف صحيح.');
    }

    await _requireClient.auth.resend(
      type: OtpType.sms,
      phone: normalizedPhone,
    );
  }

  /// التحقق من رمز الهاتف.
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    final normalizedToken = token.trim();

    if (!_isValidPhone(normalizedPhone)) {
      throw ArgumentError('يرجى إدخال رقم هاتف صحيح.');
    }

    if (!RegExp(r'^\d{6}$').hasMatch(normalizedToken)) {
      throw ArgumentError('رمز التحقق يجب أن يتكون من 6 أرقام.');
    }

    return _requireClient.auth.verifyOTP(
      type: OtpType.sms,
      phone: normalizedPhone,
      token: normalizedToken,
    );
  }

  /// التحقق من قوة كلمة المرور.
  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  /// توحيد رقم الهاتف إلى صيغة E.164 قبل إرساله إلى Supabase.
  /// يحوّل أرقام مصر المحلية مثل 01012345678 إلى +201012345678.
  String _normalizePhone(String value) {
    final asciiInput = value.trim().replaceAllMapped(
      RegExp(r'[٠-٩۰-۹]'),
      (match) {
        final code = match.group(0)!.codeUnitAt(0);
        final digit = code >= 0x0660 && code <= 0x0669
            ? code - 0x0660
            : code - 0x06F0;
        return String.fromCharCode(0x30 + digit);
      },
    );
    final compact = asciiInput.replaceAll(RegExp(r'[\s().-]'), '');
    final digits = compact.replaceAll(RegExp(r'\D'), '');

    if (compact.startsWith('+')) return '+' + digits;
    if (digits.startsWith('00')) return '+' + digits.substring(2);
    if (digits.startsWith('20')) return '+' + digits;
    if (digits.startsWith('0') &&
        (digits.length == 10 || digits.length == 11)) {
      return '+20' + digits.substring(1);
    }
    return '+' + digits;
  }

  /// التحقق الأساسي من صيغة رقم الهاتف.
  bool _isValidPhone(String value) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
  }

  /// هل توجد جلسة دخول حالية؟
  bool get isLoggedIn =>
      _client?.auth.currentSession != null;

  /// معرّف المستخدم الحالي.
  String? get currentUserId =>
      _client?.auth.currentUser?.id;

  /// رقم الهاتف المسجل.
  String? get currentPhone =>
      _client?.auth.currentUser?.phone;
}
