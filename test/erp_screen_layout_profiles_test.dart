import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silsila_app/erp/services/erp_screen_layout_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ErpScreenLayoutProfiles company isolation', () {
    test('assigns stable, distinct local namespaces to different companies', () {
      final first = ErpScreenLayoutProfiles.scopeForCompany('company-a');
      final firstAgain = ErpScreenLayoutProfiles.scopeForCompany('company-a');
      final second = ErpScreenLayoutProfiles.scopeForCompany('company-b');
      expect(ErpScreenLayoutProfiles.scopeForCompany(null), 'local');
      expect(ErpScreenLayoutProfiles.scopeForCompany('  '), 'local');
      expect(first, firstAgain);
      expect(first, isNot('local'));
      expect(second, isNot('local'));
      expect(first, isNot(second));
    });

    test('keeps profiles and pending uploads separate across companies', () async {
      await ErpScreenLayoutProfiles.load(companyId: 'company-a');
      await ErpScreenLayoutProfiles.save(
        'فئات الأصناف',
        {'rowHeight': 40, 'primary': 0xFF3E007D},
        companyId: 'company-a',
      );
      expect(
        ErpScreenLayoutProfiles.pendingProfiles(companyId: 'company-a').keys,
        contains('فئات الأصناف'),
      );

      await ErpScreenLayoutProfiles.load(companyId: 'company-b');
      expect(ErpScreenLayoutProfiles.profiles.value, isEmpty);
      expect(ErpScreenLayoutProfiles.pendingProfiles(companyId: 'company-b'), isEmpty);

      await ErpScreenLayoutProfiles.save(
        'فئات الأصناف',
        {'rowHeight': 56, 'primary': 0xFFFFA015},
        companyId: 'company-b',
      );
      await ErpScreenLayoutProfiles.load(companyId: 'company-a');
      expect(ErpScreenLayoutProfiles.profiles.value['فئات الأصناف']['rowHeight'], 40);
      await ErpScreenLayoutProfiles.load(companyId: 'company-b');
      expect(ErpScreenLayoutProfiles.profiles.value['فئات الأصناف']['rowHeight'], 56);
    });

    test('quarantines legacy unscoped profiles in the local-only namespace', () async {
      SharedPreferences.setMockInitialValues({
        ErpScreenLayoutProfiles.legacyStorageKey: '{"*":{"rowHeight":44}}',
        ErpScreenLayoutProfiles.legacyPendingStorageKey: <String>['*'],
      });

      await ErpScreenLayoutProfiles.load(companyId: 'company-a');
      expect(ErpScreenLayoutProfiles.profiles.value, isEmpty);
      expect(ErpScreenLayoutProfiles.pendingProfiles(companyId: 'company-a'), isEmpty);

      await ErpScreenLayoutProfiles.load();
      expect(ErpScreenLayoutProfiles.profiles.value['*']['rowHeight'], 44);
      expect(ErpScreenLayoutProfiles.pendingProfiles()['*'], isNotNull);
    });
  });
}
