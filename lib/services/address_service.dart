import 'package:supabase_flutter/supabase_flutter.dart';

class AddressService {
  AddressService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    return user.id;
  }

  /// جلب جميع عناوين المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getAddresses() async {
    final response = await _client
        .from('addresses')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// إضافة عنوان جديد.
  Future<Map<String, dynamic>> addAddress({
    required String title,
    required String governorate,
    required String address,
    String? district,
    String? village,
    String? landmark,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final cleanTitle = title.trim();
    final cleanGovernorate = governorate.trim();
    final cleanAddress = address.trim();

    if (cleanTitle.isEmpty ||
        cleanGovernorate.isEmpty ||
        cleanAddress.isEmpty) {
      throw ArgumentError('يرجى إدخال اسم العنوان والمحافظة والعنوان بالتفصيل.');
    }

    final userId = _userId;

    if (isDefault) {
      await _client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId);
    }

    final response = await _client
        .from('addresses')
        .insert({
          'user_id': userId,
          'title': cleanTitle,
          'governorate': cleanGovernorate,
          'address': cleanAddress,
          'district': _emptyToNull(district),
          'village': _emptyToNull(village),
          'landmark': _emptyToNull(landmark),
          'latitude': latitude,
          'longitude': longitude,
          'is_default': isDefault,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// تعيين عنوان حالي كعنوان افتراضي.
  Future<void> setDefaultAddress(String addressId) async {
    final userId = _userId;

    await _client
        .from('addresses')
        .update({'is_default': false})
        .eq('user_id', userId);

    await _client
        .from('addresses')
        .update({'is_default': true})
        .eq('id', addressId)
        .eq('user_id', userId);
  }

  /// تعديل عنوان محفوظ.
  Future<Map<String, dynamic>> updateAddress({
    required String addressId,
    required String title,
    required String governorate,
    required String address,
    String? district,
    String? village,
    String? landmark,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    final cleanTitle = title.trim();
    final cleanGovernorate = governorate.trim();
    final cleanAddress = address.trim();

    if (cleanTitle.isEmpty ||
        cleanGovernorate.isEmpty ||
        cleanAddress.isEmpty) {
      throw ArgumentError('يرجى إدخال اسم العنوان والمحافظة والعنوان بالتفصيل.');
    }

    final userId = _userId;

    if (isDefault == true) {
      await _client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId);
    }

    final updates = <String, dynamic>{
      'title': cleanTitle,
      'governorate': cleanGovernorate,
      'address': cleanAddress,
      'district': _emptyToNull(district),
      'village': _emptyToNull(village),
      'landmark': _emptyToNull(landmark),
      'latitude': latitude,
      'longitude': longitude,
    };

    if (isDefault != null) {
      updates['is_default'] = isDefault;
    }

    final response = await _client
        .from('addresses')
        .update(updates)
        .eq('id', addressId)
        .eq('user_id', userId)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// حذف عنوان محفوظ.
  Future<void> deleteAddress(String addressId) async {
    await _client
        .from('addresses')
        .delete()
        .eq('id', addressId)
        .eq('user_id', _userId);
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
