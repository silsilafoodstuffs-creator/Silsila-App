import 'package:flutter_test/flutter_test.dart';
import '../lib/erp/services/erp_item_unit_conversion.dart';

void main() {
  group('ErpItemUnitConversion', () {
    test('calculates cumulative carton, inner and sachet factors', () {
      final rows = ErpItemUnitConversion.buildUnits(
        majorName: 'كرتونة',
        middleName: 'علبة',
        minorName: 'ظرف',
        majorInnerQuantity: 24,
        middleInnerQuantity: 12,
      );
      expect(rows.map((r) => r['conversion_factor']).toList(), [288, 12, 1]);
      expect(rows.map((r) => r['unit_level']).toList(), [1, 2, 3]);
      expect(24 * 12, 288);
      expect(2 * 288, 576);
    });

    test('supports two levels without inventing a third level', () {
      final rows = ErpItemUnitConversion.buildUnits(
        majorName: 'كرتونة',
        middleName: 'علبة',
        majorInnerQuantity: 24,
      );
      expect(rows.length, 2);
      expect(rows.map((r) => r['conversion_factor']).toList(), [24, 1]);
    });

    test('creates hidden implicit middle level when it is skipped', () {
      final rows = ErpItemUnitConversion.buildUnits(
        majorName: 'كرتونة',
        minorName: 'ظرف',
        majorInnerQuantity: 288,
      );
      expect(rows.length, 3);
      expect(rows[1]['unit_name'], 'كرتونة');
      expect(rows[1]['conversion_factor'], 1);
      expect(rows[1]['is_implicit'], isTrue);
      expect(rows[1]['is_selectable'], isFalse);
      expect(rows[0]['is_selectable'], isTrue);
    });

    test('hides non-base aliases whose conversion factor is one', () {
      final rows = ErpItemUnitConversion.buildUnits(
        majorName: 'عبوة 1 كجم',
        minorName: 'كجم',
        majorInnerQuantity: 1,
      );
      expect(rows.length, 3);
      expect(rows[0]['conversion_factor'], 1);
      expect(rows[0]['is_base_unit'], isFalse);
      expect(rows[0]['is_selectable'], isFalse);
      expect(rows[2]['is_base_unit'], isTrue);
      expect(rows[2]['is_selectable'], isTrue);
    });

    test('supports one-unit items as 1:1', () {
      final rows = ErpItemUnitConversion.buildUnits(
        majorName: 'قطعة',
        majorInnerQuantity: 1,
      );
      expect(rows.length, 1);
      expect(rows.single['conversion_factor'], 1);
      expect(rows.single['is_base_unit'], isTrue);
    });

    test('hides all manually repeated names only when every factor is one', () {
      final rows = ErpItemUnitConversion.buildUnits(
        majorName: 'وحدة',
        middleName: 'وحدة',
        minorName: 'وحدة',
        majorInnerQuantity: 1,
        middleInnerQuantity: 1,
      );
      expect(rows.every((r) => r['is_selectable'] == false), isTrue);
    });

    test('rejects repeated names when any repeated factor exceeds one', () {
      expect(
        () => ErpItemUnitConversion.buildUnits(
          majorName: 'كرتونة',
          middleName: 'كرتونة',
          minorName: 'ظرف',
          majorInnerQuantity: 24,
          middleInnerQuantity: 12,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive inner quantities', () {
      expect(
        () => ErpItemUnitConversion.buildUnits(
          majorName: 'كرتونة',
          middleName: 'علبة',
          minorName: 'ظرف',
          majorInnerQuantity: 0,
          middleInnerQuantity: 12,
        ),
        throwsArgumentError,
      );
    });

    test('prices each level proportionally to its cumulative factor', () {
      expect(ErpItemUnitConversion.priceForUnit(
        majorUnitPrice: 288,
        selectedConversionFactor: 12,
        largestConversionFactor: 288,
      ), 12);
      expect(ErpItemUnitConversion.priceForUnit(
        majorUnitPrice: 288,
        selectedConversionFactor: 1,
        largestConversionFactor: 288,
      ), 1);
    });
  });
}
