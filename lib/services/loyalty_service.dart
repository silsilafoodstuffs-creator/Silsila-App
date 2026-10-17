import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyService {
  LoyaltyService({SupabaseClient? client})
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
      throw StateError('خدمة قاعدة البيانات غير متاحة حالياً.');
    }
    return client;
  }

  String get _userId {
    final user = _requireClient.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب رصيد النقاط من جدول profiles.
  Future<int> getPointsBalance() async {
    final response = await _requireClient
        .from('profiles')
        .select('points_balance')
        .eq('id', _userId)
        .maybeSingle();

    if (response == null) return 0;

    final value = response['points_balance'];

    if (value == null) return 0;

    if (value is int) {
      if (value < 0) {
        throw StateError('رصيد النقاط غير صالح.');
      }
      return value;
    }

    if (value is num) {
      if (!value.isFinite ||
          value < 0 ||
          value > 9007199254740991) {
        throw StateError('تعذر قراءة رصيد النقاط بصورة صحيحة.');
      }

      return value.toInt();
    }

    final parsed = int.tryParse(value.toString().trim());

    if (parsed == null || parsed < 0) {
      throw StateError('تعذر قراءة رصيد النقاط بصورة صحيحة.');
    }

    return parsed;
  }

  /// جلب سجل حركات النقاط.
  Future<List<Map<String, dynamic>>> getPointsHistory({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('loyalty_transactions')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _toMapList(response);
  }

  /// جلب أهداف المستخدم.
  Future<List<Map<String, dynamic>>> getMyGoals({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('user_goals')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _toMapList(response);
  }

  /// حساب نسبة تحقيق الهدف، مع حصر النتيجة بين 0 و100.
  double calculateGoalProgress({
    required num currentValue,
    required num targetValue,
  }) {
    if (!currentValue.isFinite ||
        !targetValue.isFinite ||
        targetValue <= 0) {
      return 0;
    }

    final progress = currentValue / targetValue * 100;

    if (!progress.isFinite) return 0;

    return progress.clamp(0, 100).toDouble();
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) {
      throw StateError('أعاد الخادم قائمة بيانات غير متوقعة.');
    }

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
