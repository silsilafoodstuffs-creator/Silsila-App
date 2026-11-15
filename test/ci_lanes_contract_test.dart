import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('independent mobile, web app, and web preview workflows stay active', () {
    final mobile = File('.github/workflows/mobile-validation.yml').readAsStringSync();
    final web = File('.github/workflows/web-validation.yml').readAsStringSync();
    final deploy = File('.github/workflows/deploy.yml').readAsStringSync();
    final preview = File('.github/workflows/web-preview-validation.yml').readAsStringSync();
    final release = File('.github/workflows/build.yml').readAsStringSync();

    expect(mobile, contains('name: Silsila Mobile App Validation'));
    expect(mobile, contains('flutter test --reporter expanded'));
    expect(mobile, contains('flutter build apk --debug --no-pub --target-platform android-arm,android-arm64'));
    expect(mobile, contains('Cache Android NDK and CMake'));

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

    for (final workflow in [mobile, web, preview]) {
      expect(workflow, contains('cancel-in-progress: false'));
      expect(workflow, contains('github.run_id'));
    }
    expect(mobile, contains('workflow_dispatch:'));
    expect(web, contains('workflow_dispatch:'));
  });
}
