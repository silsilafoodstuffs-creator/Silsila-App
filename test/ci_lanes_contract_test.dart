import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unified HR routing and active global UI standards stay wired', () {
    final dashboard = File('lib/erp/erp_dashboard_screen.dart').readAsStringSync();
    final hr = File('lib/erp/screens/erp_hr_affairs_screen.dart').readAsStringSync();
    final hrRecords = File('lib/erp/screens/erp_hr_records_screen.dart').readAsStringSync();
    final app = File('lib/main.dart').readAsStringSync();

    expect(dashboard, contains("'موارد بشرية': {"));
    expect(dashboard, isNot(contains("'شئون موظفين': {")));
    expect(hr, contains("page == 'أجهزة البصمة وربط الحضور'"));
    expect(hr, contains('HrFingerprintDevicesScreen(companyId: companyId)'));
    expect(hr, contains("page == 'الوظائف الشاغرة'"));
    expect(hrRecords, isNot(contains("p.contains('الوظائف الشاغرة')")));

    expect(app, contains('headingRowHeight: 40'));
    expect(app, contains('dataRowMinHeight: 40'));
    expect(app, contains('dataRowMaxHeight: 40'));
    expect(app, contains('space: 5'));
  });

  test('independent mobile, web app, and web preview workflows stay active', () {
    final mobile = File('.github/workflows/mobile-validation.yml').readAsStringSync();
    final web = File('.github/workflows/web-validation.yml').readAsStringSync();
    final deploy = File('.github/workflows/deploy.yml').readAsStringSync();
    final preview = File('.github/workflows/web-preview-validation.yml').readAsStringSync();
    final release = File('.github/workflows/build.yml').readAsStringSync();
    // The signed production APK is built only by build.yml; no separate debug APK workflow exists.

    expect(mobile, contains('name: Silsila Mobile App Validation'));
    expect(mobile, contains('flutter test --reporter expanded'));
    expect(mobile, isNot(contains('flutter build apk')));
    expect(mobile, contains('Flutter analyze + tests'));
    expect(mobile, isNot(contains('Set up Java 17')));
    expect(release, contains('name: Build Silsila Android App'));
    expect(release, contains('flutter build apk --release'));
    expect(release, contains('Verify APK signature'));
    expect(release, contains('Verify APK identity, version, and launcher icon'));
    expect(release, contains('silsila-android-apk'));

    expect(web, contains('name: Silsila Web App Validation'));
    expect(web, contains('flutter build web --release'));
    expect(web, contains('actions/upload-artifact@v4'));
    expect(web, contains('silsila-web-build-'));

    expect(deploy, contains('name: Silsila Web Preview Deployment'));
    expect(deploy, contains('Silsila Web App Validation'));
    expect(deploy, contains('actions/deploy-pages@v4'));
    expect(deploy, contains('concurrency:'));
    expect(deploy, contains('group: silsila-pages-main'));
    expect(deploy, contains('cancel-in-progress: false'));
    expect(preview, contains('name: Silsila Web Preview Validation'));
    expect(preview, contains('Silsila Web App Validation'));
    expect(preview, contains('actions/download-artifact@v4'));
    expect(preview, contains('tools/web_view_test.mjs'));
    expect(preview, contains('Run real desktop + mobile WebView smoke tests'));
    expect(preview, contains('group: silsila-web-preview-validation-'));
    expect(release, contains('workflow_dispatch:'));
    expect(release, isNot(contains('workflow_run:')));

    // Mobile and Web validation keep only the newest commit per ref active.
    for (final workflow in [mobile, web]) {
      expect(workflow, contains('cancel-in-progress: true'));
      expect(workflow, contains('github.ref'));
    }
    // Preview smoke tests remain tied to the exact completed Web artifact.
    expect(preview, contains('cancel-in-progress: false'));
    expect(preview, contains('github.run_id'));
    expect(mobile, contains('workflow_dispatch:'));
    expect(web, contains('workflow_dispatch:'));
  });
}
