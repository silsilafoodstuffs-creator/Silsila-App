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

    test('enterprise baseline forbids blanket production privilege changes', () {
      final baseline = File('docs/ENTERPRISE_READINESS_BASELINE_2026-11-23.md')
          .readAsStringSync();
      expect(baseline, contains('No destructive DDL'));
      expect(baseline, contains('blanket GRANT/REVOKE'));
      expect(baseline, contains('not a capacity certification'));
      expect(baseline, contains('tenant isolation'));
    });
  });
}
