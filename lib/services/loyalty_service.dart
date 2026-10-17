import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyService {
  LoyaltyService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب رصيد النقاط من جدول profiles.
  Future<int> getPointsBalance() async {
    final response = await _client
        .from('profiles')
        .select('points_balance')
        .eq('id', _userId)
        .maybeSingle();

    if (response == null) return 0;

    final value = response['points_balance'];
    final int? points;
    if (value is int) {
      points = value;
    } else if (value is num) {
      if (!value.isFinite || value < 0 || value > 9007199254740991) {
        throw StateError('تعذر قراءة رصيد النقاط بصورة صحيحة.');
      }
      points = value.toInt();
    } else {
      points = int.tryParse(value?.toString() ?? '');
    }

    if (points == null || points < 0) {
      throw StateError('تعذر قراءة رصيد النقاط بصورة صحيحة.');
    }
    return points;
  }

  /// جلب سجل حركات النقاط.
  Future<List<Map<String, dynamic>>> getPointsHistory({
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _client
        .from('loyalty_transactions')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب أهداف المستخدم.
  Future<List<Map<String, dynamic>>> getMyGoals({
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _client
        .from('user_goals')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// حساب نسبة تحقيق الهدف.
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
}
