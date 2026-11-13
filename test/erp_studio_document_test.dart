import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/services/studio_document.dart';

void main() {
  group('StudioDocument schema', () {
    test('round trips a supported design document', () {
      final original = StudioDocument.create('اختبار');
      final restored = StudioDocument.fromJson(original.toJson());
      expect(restored.name, 'اختبار');
      expect(restored.nodes.length, original.nodes.length);
    });

    test('rejects unsupported schema versions', () {
      expect(
        () => StudioDocument.fromJson({'schemaVersion': 99, 'id': 'x', 'name': 'x', 'nodes': []}),
        throwsFormatException,
      );
    });

    test('rejects unknown component types instead of executing them', () {
      expect(
        () => StudioDocument.fromJson({
          'schemaVersion': 1, 'id': 'x', 'name': 'x',
          'nodes': [{'id': 'x', 'type': 'script', 'props': {}}],
        }),
        throwsFormatException,
      );
    });

    test('rejects duplicate component identifiers', () {\n      expect(\n        () => StudioDocument.fromJson({\n          'schemaVersion': 1, 'id': 'x', 'name': 'x',\n          'nodes': [\n            {'id': 'same', 'type': 'text', 'props': {}},\n            {'id': 'same', 'type': 'divider', 'props': {}},\n          ],\n        }),\n        throwsFormatException,\n      );\n    });\n\n    test('rejects oversized component collections', () {
      expect(
        () => StudioDocument.fromJson({
          'schemaVersion': 1, 'id': 'x', 'name': 'x',
          'nodes': List.generate(501, (i) => {'id': '$i', 'type': 'divider', 'props': {}}),
        }),
        throwsFormatException,
      );
    });
  });
}
