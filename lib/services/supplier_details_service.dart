import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierDetailsService {
  SupplierDetailsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

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

  /// جلب بيانات المورد بواسطة معرّف الحساب.
  Future<Map<String, dynamic>?> getSupplierDetails(
    String supplierId,
  ) async {
    final cleanSupplierId = _requiredText(
      supplierId,
      'معرّف المورد مطلوب.',
    );

    final response = await _requireClient
        .from('supplier_details')
        .select()
        .eq('supplier_id', cleanSupplierId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  /// جلب بيانات المورد الحالي.
  Future<Map<String, dynamic>?> getCurrentSupplierDetails() async {
    return getSupplierDetails(_userId);
  }

  /// إنشاء بيانات المورد لأول مرة.
  Future<Map<String, dynamic>> createSupplierDetails({
    required String supplierId,
    String? businessName,
    String? businessDescription,
    String? commercialRegistration,
    String? taxNumber,
    double? minimumOrderAmount,
    bool acceptsNegotiation = true,
  }) async {
    final cleanSupplierId = _requiredText(
      supplierId,
      'معرّف المورد مطلوب.',
    );

    _requireOwner(cleanSupplierId);

    _validateMinimumOrderAmount(minimumOrderAmount);

    final response = await _requireClient
        .from('supplier_details')
        .insert({
          'supplier_id': cleanSupplierId,
          'business_name': _clean(businessName),
          'business_description': _clean(businessDescription),
          'commercial_registration': _clean(commercialRegistration),
          'tax_number': _clean(taxNumber),
          'minimum_order_amount': minimumOrderAmount,
          'accepts_negotiation': acceptsNegotiation,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// تعديل بيانات المورد الحالي.
  Future<void> updateSupplierDetails({
    required String supplierId,
    String? businessName,
    String? businessDescription,
    String? commercialRegistration,
    String? taxNumber,
    double? minimumOrderAmount,
    bool? acceptsNegotiation,
  }) async {
    final cleanSupplierId = _requiredText(
      supplierId,
      'معرّف المورد مطلوب.',
    );

    _requireOwner(cleanSupplierId);
    _validateMinimumOrderAmount(minimumOrderAmount);

    final updates = <String, dynamic>{};

    if (businessName != null) {
      updates['business_name'] = _clean(businessName);
    }

    if (businessDescription != null) {
      updates['business_description'] =
          _clean(businessDescription);
    }

    if (commercialRegistration != null) {
      updates['commercial_registration'] =
          _clean(commercialRegistration);
    }

    if (taxNumber != null) {
      updates['tax_number'] = _clean(taxNumber);
    }

    if (minimumOrderAmount != null) {
      updates['minimum_order_amount'] = minimumOrderAmount;
    }

    if (acceptsNegotiation != null) {
      updates['accepts_negotiation'] = acceptsNegotiation;
    }

    if (updates.isEmpty) {
      return;
    }

    await _requireClient
        .from('supplier_details')
        .update(updates)
        .eq('supplier_id', cleanSupplierId);
  }

  /// حذف بيانات المورد الحالي.
  Future<void> deleteSupplierDetails(String supplierId) async {
    final cleanSupplierId = _requiredText(
      supplierId,
      'معرّف المورد مطلوب.',
    );

    _requireOwner(cleanSupplierId);

    await _requireClient
        .from('supplier_details')
        .delete()
        .eq('supplier_id', cleanSupplierId);
  }

  void _requireOwner(String supplierId) {
    if (supplierId != _userId) {
      throw StateError(
        'لا يمكنك تعديل بيانات مورد آخر.',
      );
    }
  }

  void _validateMinimumOrderAmount(double? amount) {
    if (amount != null && (!amount.isFinite || amount < 0)) {
      throw ArgumentError(
        'الحد الأدنى للطلب يجب أن يكون صفرًا أو أكثر.',
      );
    }
  }

  String _requiredText(String value, String message) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
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
}
