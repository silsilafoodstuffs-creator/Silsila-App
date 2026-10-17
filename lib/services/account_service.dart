import 'package:supabase_flutter/supabase_flutter.dart';

class AccountService {
  AccountService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    return user.id;
  }

  /// جلب بيانات الحساب من جدول profiles.
  Future<Map<String, dynamic>?> getMyAccount() async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
  }

  /// تحديث الاسم وبيانات التواصل والنشاط والعنوان.
  ///
  /// تغيير رقم الهاتف الأساسي يتطلب تحققًا من Supabase Auth.
  /// لذلك لا يتم تغيير رقم الهاتف الأساسي من هذه الدالة.
  Future<Map<String, dynamic>> updateMyAccount({
    required String fullName,
    String? phone,
    String? whatsappPhone,
    String? activityType,
    String? governorate,
    String? district,
    String? village,
    String? address,
    String? landmark,
  }) async {
    final cleanName = fullName.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('يرجى إدخال الاسم.');
    }

    if (cleanName.length > 120) {
      throw ArgumentError('الاسم طويل جدًا.');
    }

    final requestedPhone = _emptyToNull(phone);

    if (requestedPhone != null) {
      final profile = await getMyAccount();

      final profilePhone = _emptyToNull(
        profile?['phone']?.toString(),
      );

      final authPhone = _emptyToNull(
        _client.auth.currentUser?.phone,
      );

      final currentPhone = profilePhone ?? authPhone;

      if (requestedPhone != currentPhone) {
        throw StateError(
          'تغيير رقم الهاتف يحتاج إلى تحقق OTP من Supabase Auth، '
          'ولا يمكن تغييره بتعديل الملف الشخصي فقط.',
        );
      }
    }

    final data = <String, dynamic>{
      'full_name': cleanName,
      'whatsapp_phone': _emptyToNull(whatsappPhone),
      'activity_type': _emptyToNull(activityType),
      'governorate': _emptyToNull(governorate),
      'district': _emptyToNull(district),
      'area': _emptyToNull(village),
      'address': _emptyToNull(address),
      'landmark': _emptyToNull(landmark),
    };

    final response = await _client
        .from('profiles')
        .update(data)
        .eq('id', _userId)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// حساب نسبة اكتمال البيانات المتاحة في الملف الشخصي.
  Future<int> getProfileCompletion() async {
    final profile = await getMyAccount();

    if (profile == null) return 0;

    const fields = [
      'full_name',
      'phone',
      'whatsapp_phone',
      'activity_type',
      'governorate',
      'district',
      'area',
      'address',
    ];

    var completed = 0;

    for (final field in fields) {
      final value = profile[field];

      if (value != null && value.toString().trim().isNotEmpty) {
        completed++;
      }
    }

    return ((completed / fields.length) * 100).round();
  }

  /// تحديث كلمة المرور للحساب الحالي.
  Future<void> changePassword(String newPassword) async {
    if (!_isStrongPassword(newPassword)) {
      throw ArgumentError(
        'كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل، '
        'وحرف كبير وحرف صغير ورقم ورمز.',
      );
    }

    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
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

  /// تحويل النص الفارغ إلى null وتنظيف المسافات المحيطة.
  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
