class LocationService {
  /// قائمة المحافظات المصرية.
  static const List<String> governorates = [
    // Keep the primary operating areas first, in branch-code order.
    'القاهرة',
    'الجيزة',
    'القليوبية',
    'الشرقية',
    'الإسكندرية',
    'الغربية',
    'المنوفية',
    'البحيرة',
    'كفر الشيخ',
    'الدقهلية',
    'دمياط',
    'بورسعيد',
    'الإسماعيلية',
    'السويس',
    'شمال سيناء',
    'جنوب سيناء',
    'الفيوم',
    'بني سويف',
    'المنيا',
    'أسيوط',
    'سوهاج',
    'قنا',
    'الأقصر',
    'أسوان',
    'البحر الأحمر',
    'الوادي الجديد',
    'مطروح',
  ];

  /// التحقق من اسم المحافظة بعد تنظيف المسافات.
  static bool isValidGovernorate(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return false;

    return governorates.contains(normalized);
  }

  /// إرجاع قائمة المحافظات للعرض في القوائم المنسدلة.
  static List<String> getGovernorates() {
    return List<String>.unmodifiable(governorates);
  }

  /// تنظيف المسافات الزائدة من النص.
  static String normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// تنظيف قيمة اختيارية وإرجاع نص فارغ عند عدم وجود قيمة.
  static String normalizeOptional(String? value) {
    if (value == null) return '';
    return normalize(value);
  }

  /// التحقق من اكتمال بيانات العنوان الأساسية.
  static bool isAddressComplete({
    required String governorate,
    required String district,
    required String address,
  }) {
    return isValidGovernorate(governorate) &&
        normalize(district).isNotEmpty &&
        normalize(address).isNotEmpty;
  }

  /// التحقق من اكتمال العنوان مع إمكانية إضافة القرية أو المنطقة.
  static bool isDetailedAddressComplete({
    required String governorate,
    required String district,
    String? village,
    required String address,
  }) {
    final normalizedVillage = normalizeOptional(village);

    return isValidGovernorate(governorate) &&
        normalize(district).isNotEmpty &&
        normalize(address).isNotEmpty &&
        normalizedVillage.length <= 150;
  }

  /// تجهيز بيانات العنوان النصية قبل إرسالها إلى قاعدة البيانات.
  static Map<String, String> normalizeAddress({
    required String governorate,
    required String district,
    String? village,
    required String address,
    String? landmark,
  }) {
    return {
      'governorate': normalize(governorate),
      'district': normalize(district),
      'village': normalizeOptional(village),
      'address': normalize(address),
      'landmark': normalizeOptional(landmark),
    };
  }
}
