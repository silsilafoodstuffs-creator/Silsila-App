import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierDetailsService {
  SupplierDetailsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// جلب بيانات المورد بواسطة معرّف الحساب.
  Future<Map<String, dynamic>?> getSupplierDetails(
    String supplierId,
  ) async {
    return await _client
        .from('supplier_details')
        .select()
        .eq('supplier_id', supplierId)
        .maybeSingle();
  }

  /// جلب بيانات المورد الحالي.
  Future<Map<String, dynamic>?> getCurrentSupplierDetails() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    return getSupplierDetails(user.id);
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
    final result = await _client
        .from('supplier_details')
        .insert({
          'supplier_id': supplierId,
          'business_name': businessName?.trim(),
          'business_description': businessDescription?.trim(),
          'commercial_registration': commercialRegistration?.trim(),
          'tax_number': taxNumber?.trim(),
          'minimum_order_amount': minimumOrderAmount,
          'accepts_negotiation': acceptsNegotiation,
        })
        .select()
        .single();

    return result;
  }

  /// تعديل بيانات المورد.
  Future<void> updateSupplierDetails({
    required String supplierId,
    String? businessName,
    String? businessDescription,
    String? commercialRegistration,
    String? taxNumber,
    double? minimumOrderAmount,
    bool? acceptsNegotiation,
  }) async {
    final updates = <String, dynamic>{};

    if (businessName != null) {
      updates['business_name'] = businessName.trim();
    }

    if (businessDescription != null) {
      updates['business_description'] = businessDescription.trim();
    }

    if (commercialRegistration != null) {
      updates['commercial_registration'] =
          commercialRegistration.trim();
    }

    if (taxNumber != null) {
      updates['tax_number'] = taxNumber.trim();
    }

    if (minimumOrderAmount != null) {
      if (minimumOrderAmount < 0) {
        throw ArgumentError('الحد الأدنى للطلب لا يمكن أن يكون سالبًا.');
      }
      updates['minimum_order_amount'] = minimumOrderAmount;
    }

    if (acceptsNegotiation != null) {
      updates['accepts_negotiation'] = acceptsNegotiation;
    }

    if (updates.isEmpty) return;

    await _client
        .from('supplier_details')
        .update(updates)
        .eq('supplier_id', supplierId);
  }

  /// حذف بيانات المورد.
  Future<void> deleteSupplierDetails(String supplierId) async {
    await _client
        .from('supplier_details')
        .delete()
        .eq('supplier_id', supplierId);
  }
}
