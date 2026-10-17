import 'package:supabase_flutter/supabase_flutter.dart';

class AddressService {
  AddressService({SupabaseClient? client})
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

  String get _userId {
    final user = _requireClient.auth.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    return user.id;
  }

  /// جلب عناوين المستخدم الحالي.
  Future<List<Map<String, dynamic>>> getAddresses({
    int limit = 100,
  }) async {
    _validateLimit(limit);

    final response = await _requireClient
        .from('addresses')
        .select()
        .eq('user_id', _userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب العنوان الافتراضي للمستخدم الحالي.
  Future<Map<String, dynamic>?> getDefaultAddress() async {
    final response = await _requireClient
        .from('addresses')
        .select()
        .eq('user_id', _userId)
        .eq('is_default', true)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
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
    final cleanTitle = _requiredText(title, 'اسم العنوان');
    final cleanGovernorate =
        _requiredText(governorate, 'المحافظة');
    final cleanAddress =
        _requiredText(address, 'العنوان بالتفصيل');

    _validateTextLength(cleanTitle, 'اسم العنوان', 100);
    _validateTextLength(cleanGovernorate, 'المحافظة', 100);
    _validateTextLength(cleanAddress, 'العنوان بالتفصيل', 2000);
    _validateOptionalLength(district, 'المركز', 150);
    _validateOptionalLength(village, 'القرية', 150);
    _validateOptionalLength(landmark, 'علامة مميزة', 300);
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

    final response = await _requireClient
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

  /// تعيين عنوان محفوظ كعنوان افتراضي.
  Future<void> setDefaultAddress(String addressId) async {
    final id = _requiredText(addressId, 'معرّف العنوان');
    _validateTextLength(id, 'معرّف العنوان', 200);

    await _requireClient.rpc(
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
    final cleanId =
        _requiredText(addressId, 'معرّف العنوان');
    final cleanTitle = _requiredText(title, 'اسم العنوان');
    final cleanGovernorate =
        _requiredText(governorate, 'المحافظة');
    final cleanAddress =
        _requiredText(address, 'العنوان بالتفصيل');

    _validateTextLength(cleanId, 'معرّف العنوان', 200);
    _validateTextLength(cleanTitle, 'اسم العنوان', 100);
    _validateTextLength(cleanGovernorate, 'المحافظة', 100);
    _validateTextLength(cleanAddress, 'العنوان بالتفصيل', 2000);
    _validateOptionalLength(district, 'المركز', 150);
    _validateOptionalLength(village, 'القرية', 150);
    _validateOptionalLength(landmark, 'علامة مميزة', 300);
    _validateCoordinates(latitude, longitude);

    final userId = _userId;

    if (isDefault == true) {
      return _saveDefaultAddress(
        addressId: cleanId,
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

    final response = await _requireClient
        .from('addresses')
        .update(updates)
        .eq('id', cleanId)
        .eq('user_id', userId)
        .select()
        .maybeSingle();

    if (response == null) {
      throw StateError(
        'لم يتم العثور على العنوان أو لا تملك صلاحية تعديله.',
      );
    }

    return Map<String, dynamic>.from(response);
  }

  /// حفظ عنوان افتراضي عبر إجراء قاعدة البيانات.
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
    final response = await _requireClient.rpc(
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

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    if (response is List && response.isNotEmpty) {
      final first = response.first;

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    throw StateError(
      'لم تُرجع قاعدة البيانات بيانات العنوان الافتراضي بصورة صحيحة.',
    );
  }

  /// حذف عنوان من حساب المستخدم الحالي.
  Future<void> deleteAddress(String addressId) async {
    final id = _requiredText(addressId, 'معرّف العنوان');
    _validateTextLength(id, 'معرّف العنوان', 200);

    await _requireClient
        .from('addresses')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// التحقق من صحة إحداثيات الموقع.
  void _validateCoordinates(
    double? latitude,
    double? longitude,
  ) {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError(
        'يجب إدخال خط العرض وخط الطول معًا.',
      );
    }

    if (latitude == null || longitude == null) return;

    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError(
        'إحداثيات الموقع خارج النطاق الصحيح.',
      );
    }
  }

  void _validateTextLength(
    String value,
    String fieldName,
    int maxLength,
  ) {
    if (value.length > maxLength) {
      throw ArgumentError('$fieldName يجب ألا يتجاوز $maxLength حرفًا.');
    }
  }

  void _validateOptionalLength(
    String? value,
    String fieldName,
    int maxLength,
  ) {
    final cleaned = value?.trim();
    if (cleaned != null && cleaned.length > maxLength) {
      throw ArgumentError('$fieldName يجب ألا يتجاوز $maxLength حرفًا.');
    }
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('يجب أن يكون الحد بين 1 و200.');
    }
  }

  String _requiredText(String? value, String fieldName) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      throw ArgumentError('يرجى إدخال $fieldName.');
    }

    return cleaned;
  }

  String? _emptyToNull(String? value) {
    final cleaned = value?.trim();

    return cleaned == null || cleaned.isEmpty
        ? null
        : cleaned;
  }
}
