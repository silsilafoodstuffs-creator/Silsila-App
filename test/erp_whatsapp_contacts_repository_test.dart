import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/services/erp_whatsapp_contacts_repository.dart';

void main() {
  group('ErpWhatsappContactsRepository.normalizePhone', () {
    test('keeps international plus and removes formatting characters', () {
      expect(
        ErpWhatsappContactsRepository.normalizePhone('+20 (100) 123-4567'),
        '+201001234567',
      );
    });

    test('converts Arabic-Indic digits to ASCII', () {
      expect(
        ErpWhatsappContactsRepository.normalizePhone('٠١٠ ١٢٣٤ ٥٦٧٨'),
        '٠١٠١٢٣٤٥٦٧٨'.replaceAllMapped(
          RegExp(r'[٠-٩]'),
          (match) => String.fromCharCode(
            0x30 + match.group(0)!.runes.first - 0x0660,
          ),
        ),
      );
    });

    test('converts Persian digits and returns empty for non-phone text', () {
      expect(
        ErpWhatsappContactsRepository.normalizePhone('۰۱۰۱۲۳۴۵۶۷۸'),
        '01012345678',
      );
      expect(ErpWhatsappContactsRepository.normalizePhone('لا يوجد'), '');
    });
  });
}
