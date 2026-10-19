import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  WalletService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    if (_client != null) {
      return _client;
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

    final id = user.id.trim();

    if (id.isEmpty || id.length > 200) {
      throw StateError('معرّف المستخدم غير صالح. يرجى تسجيل الدخول مرة أخرى.');
    }

    return id;
  }

  /// جلب المحفظة الحالية للمستخدم.
  Future<Map<String, dynamic>?> getMyWallet() async {
    final response = await _requireClient
        .from('wallets')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  /// قراءة الرصيد، وإرجاع صفر إذا لم توجد محفظة.
  Future<double> getBalance() async {
    final wallet = await getMyWallet();

    if (wallet == null) {
      return 0;
    }

    final value = wallet['balance'];

    final balance = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');

    if (balance == null ||
        !balance.isFinite ||
        balance < 0) {
      throw StateError(
        'تعذر قراءة رصيد المحفظة بصورة صحيحة.',
      );
    }

    return balance;
  }

  /// جلب سجل معاملات المحفظة.
  Future<List<Map<String, dynamic>>> getTransactions({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('wallet_transactions')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(response);
  }

  /// جلب طلبات شحن المحفظة السابقة.
  Future<List<Map<String, dynamic>>> getMyTopUpRequests({
    int limit = 50,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('wallet_topup_requests')
        .select(
          'id, amount, payment_method, reference, '
          'status, review_note, created_at',
        )
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(response);
  }

  /// إنشاء طلب شحن للمراجعة.
  ///
  /// لا يضيف هذا الإجراء أي أموال إلى الرصيد.
  /// يجب اعتماد الطلب عبر إجراء موثوق في الخادم.
  Future<Map<String, dynamic>> requestTopUp({
    required double amount,
    required String paymentMethod,
    String? reference,
  }) async {
    _validateAmount(amount);

    final method = _requiredText(
      paymentMethod,
      'يرجى تحديد طريقة دفع صحيحة.',
      maxLength: 80,
    );

    final cleanReference = _clean(reference);

    if (cleanReference != null &&
        cleanReference.length > 200) {
      throw ArgumentError(
        'الرقم المرجعي يجب ألا يتجاوز 200 حرف.',
      );
    }

    if (cleanReference != null &&
        (cleanReference.contains(r'\n') ||
            cleanReference.contains(r'\r'))) {
      throw ArgumentError(
        'الرقم المرجعي يجب أن يكون في سطر واحد.',
      );
    }

    final userId = _userId;

    final response = await _requireClient
        .from('wallet_topup_requests')
        .insert({
          'user_id': userId,
          'amount': amount,
          'payment_method': method,
          'reference': cleanReference,
          'status': 'pending',
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError(
        'يجب أن يكون الحد بين 1 و200.',
      );
    }
  }

  void _validateAmount(double amount) {
    if (!amount.isFinite ||
        amount <= 0 ||
        amount > 9999999999.99 ||
        amount != (amount * 100).roundToDouble() / 100) {
      throw ArgumentError(
        'مبلغ الشحن يجب أن يكون موجبًا وبحد أقصى منزلتين عشريتين.',
      );
    }
  }

  String _requiredText(
    String value,
    String message, {
    required int maxLength,
  }) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.length > maxLength) {
      throw ArgumentError(message);
    }

    return cleaned;
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  List<Map<String, dynamic>> _mapRows(dynamic response) {
    if (response is! List) {
      throw StateError(
        'تعذر قراءة بيانات المحفظة.',
      );
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
