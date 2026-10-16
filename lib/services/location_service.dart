class LocationService {
  /// قائمة المحافظات المصرية.
  static const List<String> governorates = [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'القليوبية',
    'الشرقية',
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

  /// التحقق من اسم المحافظة.
  static bool isValidGovernorate(String value) {
    return governorates.contains(value.trim());
  }

  /// إرجاع قائمة المحافظات للعرض في القوائم المنسدلة.
  static List<String> getGovernorates() {
    return List<String>.unmodifiable(governorates);
  }

  /// تنظيف اسم الموقع النصي.
  static String normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// التحقق من أن الحقول الأساسية للموقع مكتملة.
  static bool isAddressComplete({
    required String governorate,
    required String district,
    required String address,
  }) {
    return isValidGovernorate(governorate) &&
        normalize(district).isNotEmpty &&
        normalize(address).isNotEmpty;
  }
}
