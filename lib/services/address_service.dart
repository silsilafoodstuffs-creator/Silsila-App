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

    _validateCoordinates(latitude, longitude);

    final userId = _userId;

    if (isDefault) {
      return _saveDefaultAddress(
        addressId: null,
        title: cleanTitle,
        governorate: cleanGovernorate,
        address: cleanAddress,
        district: district,
        village: village,
        landmark: landmark,
        latitude: latitude,
        longitude: longitude,
      );
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
          'is_default': false,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// تعيين عنوان حالي كعنوان افتراضي.
  Future<void> setDefaultAddress(String addressId) async {
    final id = addressId.trim();
    if (id.isEmpty) {
      throw ArgumentError('معرّف العنوان مطلوب.');
    }

    if (_client.auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
    await _client.rpc(
      'set_default_address',
      params: {'p_address_id': id},
    );
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
    final cleanAddressId = addressId.trim();
    if (cleanAddressId.isEmpty) {
      throw ArgumentError('معرّف العنوان مطلوب.');
    }
    final cleanTitle = title.trim();
    final cleanGovernorate = governorate.trim();
    final cleanAddress = address.trim();

    if (cleanTitle.isEmpty ||
        cleanGovernorate.isEmpty ||
        cleanAddress.isEmpty) {
      throw ArgumentError('يرجى إدخال اسم العنوان والمحافظة والعنوان بالتفصيل.');
    }

    _validateCoordinates(latitude, longitude);

    final userId = _userId;

    if (isDefault == true) {
      return _saveDefaultAddress(
        addressId: cleanAddressId,
        title: cleanTitle,
        governorate: cleanGovernorate,
        address: cleanAddress,
        district: district,
        village: village,
        landmark: landmark,
        latitude: latitude,
        longitude: longitude,
      );
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
        .eq('id', cleanAddressId)
        .eq('user_id', userId)
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// Save a default address atomically through a database transaction.
  Future<Map<String, dynamic>> _saveDefaultAddress({
    required String? addressId,
    required String title,
    required String governorate,
    required String address,
    String? district,
    String? village,
    String? landmark,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.rpc(
      'save_default_address',
      params: {
        'p_address_id': addressId,
        'p_title': title,
        'p_governorate': governorate,
        'p_address': address,
        'p_district': _emptyToNull(district),
        'p_village': _emptyToNull(village),
        'p_landmark': _emptyToNull(landmark),
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );

    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw StateError('لم تُرجع قاعدة البيانات العنوان الافتراضي بصورة صحيحة.');
  }

  /// حذف عنوان محفوظ.
  Future<void> deleteAddress(String addressId) async {
    final id = addressId.trim();
    if (id.isEmpty) {
      throw ArgumentError('معرّف العنوان مطلوب.');
    }
    await _client
        .from('addresses')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  void _validateCoordinates(double? latitude, double? longitude) {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError('يجب إدخال خط العرض وخط الطول معًا.');
    }
    if (latitude != null &&
        (!latitude.isFinite ||
            !longitude!.isFinite ||
            latitude < -90 || latitude > 90 ||
            longitude < -180 || longitude > 180)) {
      throw ArgumentError('إحداثيات الموقع خارج النطاق الصحيح.');
    }
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
