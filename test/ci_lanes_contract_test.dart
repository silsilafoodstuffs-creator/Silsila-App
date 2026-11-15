import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('independent mobile, web app, and web preview workflows stay active', () {
    final mobile = File('.github/workflows/mobile-validation.yml').readAsStringSync();
    final web = File('.github/workflows/web-validation.yml').readAsStringSync();
    final preview = File('.github/workflows/deploy.yml').readAsStringSync();

    expect(mobile, contains('name: Silsila Mobile App Validation'));
    expect(mobile, contains('flutter test --reporter expanded'));
    expect(mobile, contains('flutter build apk --debug'));

    expect(web, contains('name: Silsila Web App Validation'));
    expect(web, contains('flutter build web --release'));
    expect(web, contains('tools/web_view_test.mjs'));

    expect(preview, contains('name: Silsila Web Preview - Deploy + Smoke Tests'));
    expect(preview, contains('Run deployed WebView tests (desktop + mobile)'));

    for (final workflow in [mobile, web, preview]) {
      expect(workflow, contains('cancel-in-progress: false'));
      expect(workflow, contains('workflow_dispatch:'));
    }
  });
}
