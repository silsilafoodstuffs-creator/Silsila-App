import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  WalletService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب المحفظة الحالية للمستخدم.
  Future<Map<String, dynamic>?> getMyWallet() async {
    final response = await _client
        .from('wallets')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
  }

  /// قراءة الرصيد، مع إرجاع صفر إذا لم توجد محفظة.
  Future<double> getBalance() async {
    final wallet = await getMyWallet();

    if (wallet == null) return 0;

    final balance = wallet['balance'];

    if (balance is num) {
      return balance.toDouble();
    }

    return double.tryParse(balance?.toString() ?? '') ?? 0;
  }

  /// جلب سجل معاملات المحفظة.
  Future<List<Map<String, dynamic>>> getTransactions({
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _client
        .from('wallet_transactions')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب طلبات شحن المحفظة السابقة وحالات مراجعتها.
  Future<List<Map<String, dynamic>>> getMyTopUpRequests({
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }

    final response = await _client
        .from('wallet_topup_requests')
        .select('id, amount, payment_method, reference, status, review_note, created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// طلب شحن المحفظة.
  ///
  /// لا يضيف هذا الإجراء أموالًا إلى الرصيد؛
  /// بل ينشئ طلب شحن يحتاج إلى معالجة آمنة.
  Future<Map<String, dynamic>> requestTopUp({
    required double amount,
    required String paymentMethod,
    String? reference,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('مبلغ الشحن يجب أن يكون أكبر من صفر.');
    }

    final method = paymentMethod.trim();

    if (method.isEmpty || method.length > 80) {
      throw ArgumentError('يرجى تحديد طريقة دفع صحيحة.');
    }
    if (reference != null && reference.trim().length > 200) {
      throw ArgumentError('الرقم المرجعي يجب ألا يتجاوز 200 حرف.');
    }

    final response = await _client
        .from('wallet_topup_requests')
        .insert({
          'user_id': _userId,
          'amount': amount,
          'payment_method': method,
          'reference': _emptyToNull(reference),
          'status': 'pending',
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
