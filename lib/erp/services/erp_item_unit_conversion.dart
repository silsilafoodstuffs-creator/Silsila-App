class ErpItemUnitConversion {
  static List<Map<String, dynamic>> buildUnits({
    required String majorName,
    String? middleName,
    String? minorName,
    required double majorInnerQuantity,
    double middleInnerQuantity = 1,
  }) {
    final major = majorName.trim();
    final middle = middleName?.trim() ?? '';
    final minor = minorName?.trim() ?? '';
    if (major.isEmpty) throw ArgumentError('الوحدة الكبرى مطلوبة.');
    if (majorInnerQuantity <= 0 || middleInnerQuantity <= 0) {
      throw ArgumentError('الأعداد الداخلية يجب أن تكون أكبر من صفر.');
    }
    final hasMiddle = middle.isNotEmpty;
    final hasMinor = minor.isNotEmpty;
    final rows = <Map<String, dynamic>>[];
    if (hasMiddle && hasMinor) {
      rows.add(_row(1, major, majorInnerQuantity * middleInnerQuantity, false, majorInnerQuantity));
      rows.add(_row(2, middle, middleInnerQuantity, false, middleInnerQuantity));
      rows.add(_row(3, minor, 1, true, null));
    } else if (hasMiddle) {
      rows.add(_row(1, major, majorInnerQuantity, false, majorInnerQuantity));
      rows.add(_row(2, middle, 1, true, null));
    } else if (hasMinor) {
      rows.add(_row(1, major, majorInnerQuantity, false, majorInnerQuantity));
      rows.add({
        ..._row(2, major, 1, false, 1),
        'is_implicit': true,
        'is_selectable': false,
      });
      rows.add(_row(3, minor, 1, true, null));
    } else {
      rows.add(_row(1, major, 1, true, null));
    }

    // Units whose factor is 1 but which are not the canonical base unit are aliases, not distinct stock units.
    // Keep their records for history, but never expose them as selectable purchase/sale/transfer units.
    for (final row in rows) {
      if ((row['conversion_factor'] as num).toDouble() == 1 && row['is_base_unit'] != true) {
        row['is_selectable'] = false;
      }
    }

    final manual = rows.where((r) => r['is_implicit'] != true).toList();
    final counts = <String, int>{};
    for (final row in manual) {
      final key = _key(row['unit_name']);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final row in manual) {
      if ((counts[_key(row['unit_name'])] ?? 0) > 1) {
        if ((row['conversion_factor'] as num).toDouble() != 1) {
          throw ArgumentError('تكرار اسم الوحدة مسموح فقط عندما يكون معامل كل الوحدات المتكررة 1.');
        }
        row['is_selectable'] = false;
      }
    }
    return rows;
  }

  static Map<String, dynamic> _row(
    int level, String name, double factor, bool base, double? inner,
  ) => {
    'unit_code': 'LEVEL_$level',
    'unit_name': name,
    'conversion_factor': factor,
    'is_base_unit': base,
    'unit_level': level,
    'inner_quantity': inner,
    'is_implicit': false,
    'is_selectable': true,
  };

  static String _key(dynamic value) => value.toString().trim().toLowerCase();

  static double priceForUnit({
    required double majorUnitPrice,
    required double selectedConversionFactor,
    required double largestConversionFactor,
  }) {
    if (selectedConversionFactor <= 0 || largestConversionFactor <= 0) {
      throw ArgumentError('معامل التحويل يجب أن يكون أكبر من صفر.');
    }
    return majorUnitPrice * selectedConversionFactor / largestConversionFactor;
  }
}
