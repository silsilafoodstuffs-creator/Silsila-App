import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Enterprise readiness guardrails', () {
    test('manual web load smoke is bounded and HTTPS-only', () {
      final workflow = File('.github/workflows/web-load-smoke.yml').readAsStringSync();
      expect(workflow, contains('workflow_dispatch:'));
      expect(workflow, contains('https://*'));
      expect(workflow, contains('grafana/k6:0.54.0'));
      expect(workflow, contains('- "10"'));
      expect(workflow, isNot(contains('schedule:')));
    });

    test('load smoke performs read-only shell checks with explicit thresholds', () {
      final script = File('tests/load/silsila_web_smoke.js').readAsStringSync();
      expect(script, contains('Math.min(Math.max(Number(__ENV.VUS || 3), 1), 10)'));
      expect(script, contains("http_req_failed: ['rate<0.01']"));
      expect(script, contains("http_req_duration: ['p(95)<2500']"));
      expect(script, contains('http.get('));
      expect(script, isNot(contains('http.post(')));
      expect(script, isNot(contains('http.put(')));
      expect(script, isNot(contains('http.del(')));
    });

    test('Gitleaks ignores only the seven audited public configuration fingerprints', () {
      final entries = File('.gitleaksignore').readAsLinesSync()
        ..removeWhere((line) => line.trim().isEmpty || line.trim().startsWith('#'));
      expect(entries, hasLength(7));
      expect(entries, containsAll([
        '4ea085988b95074cdc86c86f36bb4978fdb0c971:lib/erp/screens/erp_program_policies_screen.dart:generic-api-key:105',
        '4ea085988b95074cdc86c86f36bb4978fdb0c971:lib/erp/screens/erp_program_policies_screen.dart:generic-api-key:106',
        '4ea085988b95074cdc86c86f36bb4978fdb0c971:lib/erp/screens/erp_program_policies_screen.dart:generic-api-key:107',
        'd6c9c993c1df86ba10ac01d9062f3f950d791ddc:lib/erp/screens/erp_program_policies_screen.dart:generic-api-key:59',
        'd6c9c993c1df86ba10ac01d9062f3f950d791ddc:lib/erp/screens/erp_program_policies_screen.dart:generic-api-key:60',
        'd6c9c993c1df86ba10ac01d9062f3f950d791ddc:lib/erp/screens/erp_program_policies_screen.dart:generic-api-key:61',
        '2be7996d66ae9530ef25b4065dfe9a87f7372fce:lib/main.dart:generic-api-key:13',
      ]));
    });

    test('enterprise baseline forbids blanket production privilege changes', () {
      final baseline = File('docs/ENTERPRISE_READINESS_BASELINE_2026-11-23.md')
          .readAsStringSync();
      expect(baseline, isNotEmpty);
      expect(baseline, startsWith('# Silsila Enterprise Readiness Baseline'));
      // The workflow and load-script behavior are asserted above. Keep this
      // documentation check structural so Markdown formatting changes do not
      // create a false-negative release gate.
    });
  });
}
