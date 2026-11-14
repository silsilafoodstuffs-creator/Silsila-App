import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/services/studio_data_sources.dart';
import 'package:silsila_app/erp/services/studio_document.dart';
import 'package:silsila_app/erp/services/erp_studio_draft_store.dart';
import 'package:silsila_app/erp/services/studio_renderer.dart';

void main() {
  group('StudioDraftStore company isolation', () {
    test('uses a local-only namespace when no company is selected', () {
      expect(StudioDraftStore.scopeForCompany(null), 'local');
      expect(StudioDraftStore.scopeForCompany('   '), 'local');
    });

    test('creates deterministic but distinct namespaces for separate companies', () {
      final companyA = StudioDraftStore.scopeForCompany('company-a');
      final companyAAgain = StudioDraftStore.scopeForCompany('company-a');
      final companyB = StudioDraftStore.scopeForCompany('company-b');
      expect(companyA, companyAAgain);
      expect(companyA, isNot('local'));
      expect(companyB, isNot('local'));
      expect(companyA, isNot(companyB));
    });
  });


  group('Studio BI charts', () {
    for (final chartType in ['bar', 'horizontal', 'line', 'pie', 'donut']) {
      testWidgets('renders $chartType charts from bound data', (tester) async {
        final node = StudioNode(
          id: 'chart',
          type: 'chart',
          props: {
            'chartType': chartType,
            'valueField': 'value',
            'labelField': 'label',
            'binding': {'source': 'sales', 'field': 'value'},
          },
        );
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: StudioComponentRegistry.build(
              node,
              dataBySource: {
                'sales': [
                  {'label': 'A', 'value': 10},
                  {'label': 'B', 'value': 25},
                  {'label': 'C', 'value': 15},
                ],
              },
            ),
          ),
        ));
        expect(find.byType(CustomPaint), findsOneWidget);
        await tester.pumpAndSettle();
      });
    }
  });

  group('StudioDocument schema', () {
    test('round trips a supported design document including metadata and bindings', () {
      final original = StudioDocument.create('اختبار', designKind: 'report').copyWith(
        bindings: {
          'table_1': {'source': 'items', 'field': 'item_name', 'mode': 'read'},
        },
        settings: {'direction': 'rtl', 'spacing': 5},
      );
      final restored = StudioDocument.fromJson(original.toJson());
      expect(restored.name, 'اختبار');
      expect(restored.designKind, 'report');
      expect(restored.schemaVersion, 2);
      expect(restored.nodes.length, original.nodes.length);
      expect(restored.bindings['table_1']['source'], 'items');
      expect(restored.settings['spacing'], 5);
    });

    test('reads schema v1 documents and upgrades them to v2', () {
      final restored = StudioDocument.fromJson({
        'schemaVersion': 1,
        'id': 'legacy',
        'name': 'تصميم قديم',
        'nodes': [{'id': 'title', 'type': 'text', 'props': {'text': 'قديم'}}],
      });
      expect(restored.schemaVersion, 2);
      expect(restored.designKind, 'screen');
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
          'schemaVersion': 2, 'id': 'x', 'name': 'x',
          'nodes': [{'id': 'x', 'type': 'script', 'props': {}}],
        }),
        throwsFormatException,
      );
    });

    test('accepts the registered report, form, chart and icon components', () {
      final restored = StudioDocument.fromJson({
        'schemaVersion': 2, 'id': 'x', 'name': 'x', 'designKind': 'report',
        'nodes': [
          {'id': 'chart', 'type': 'chart', 'props': {'valueField': 'grand_total'}},
          {'id': 'form', 'type': 'form', 'props': {'fields': ['name']}},
          {'id': 'icon', 'type': 'icon', 'props': {'name': 'dashboard'}},
        ],
      });
      expect(restored.nodes.map((e) => e.type), ['chart', 'form', 'icon']);
    });

    test('preserves group, hidden and locked layer metadata', () {
      final restored = StudioDocument.fromJson({
        'schemaVersion': 2, 'id': 'x', 'name': 'x',
        'nodes': [
          {'id': 'a', 'type': 'text', 'groupId': 'g1', 'hidden': true, 'locked': true, 'props': {'text': 'A'}},
        ],
      });
      expect(restored.nodes.single.groupId, 'g1');
      expect(restored.nodes.single.hidden, isTrue);
      expect(restored.nodes.single.locked, isTrue);
    });

    test('rejects duplicate component identifiers', () {
      expect(
        () => StudioDocument.fromJson({
          'schemaVersion': 2, 'id': 'x', 'name': 'x',
          'nodes': [
            {'id': 'same', 'type': 'text', 'props': {}},
            {'id': 'same', 'type': 'divider', 'props': {}},
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects oversized component collections', () {
      expect(
        () => StudioDocument.fromJson({
          'schemaVersion': 2, 'id': 'x', 'name': 'x',
          'nodes': List.generate(501, (i) => {'id': '$i', 'type': 'divider', 'props': {}}),
        }),
        throwsFormatException,
      );
    });

    test('rejects invalid component bindings and oversized top-level settings', () {
      expect(
        () => StudioDocument.fromJson({
          'schemaVersion': 2, 'id': 'x', 'name': 'x',
          'nodes': [
            {'id': 'a', 'type': 'text', 'props': {'binding': 'not-an-object'}},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => StudioDocument.fromJson({
          'schemaVersion': 2, 'id': 'x', 'name': 'x',
          'nodes': [],
          'settings': {for (var i = 0; i < 81; i++) 'setting_$i': i},
        }),
        throwsFormatException,
      );
    });

    test('validates nested values in top-level binding metadata', () {
      final deeplyNested = <String, dynamic>{};
      Map<String, dynamic> cursor = deeplyNested;
      for (var i = 0; i < 10; i++) {
        final child = <String, dynamic>{};
        cursor['child'] = child;
        cursor = child;
      }
      expect(
        () => StudioDocument.fromJson({
          'schemaVersion': 2, 'id': 'x', 'name': 'x',
          'nodes': [],
          'bindings': {'component': deeplyNested},
        }),
        throwsFormatException,
      );
    });

    test('rejects non-JSON property values and excessive nested data', () {
      expect(
        () => StudioDocument.fromJson({
          'schemaVersion': 2, 'id': 'x', 'name': 'x',
          'nodes': [{'id': 'a', 'type': 'text', 'props': {'bad': Object()}}],
        }),
        throwsFormatException,
      );
    });
  });

  group('StudioDataSources allow-list', () {
    test('exposes only known company-scoped ERP tables', () {
      expect(
        StudioDataSources.all.map((e) => e.table).toSet(),
        containsAll(['erp_items', 'erp_brands', 'erp_item_categories', 'erp_warehouses', 'erp_sales_documents', 'erp_purchase_documents', 'erp_stock_balances']),
      );
    });

    test('rejects unregistered table keys', () {
      expect(() => StudioDataSources.byKey('users;drop table'), throwsArgumentError);
    });

    test('demo-sensitive sources explicitly exclude demo records', () {
      expect(StudioDataSources.byKey('items').excludeDemo, isTrue);
      expect(StudioDataSources.byKey('sales_documents').excludeDemo, isTrue);
      expect(StudioDataSources.byKey('warehouses').excludeDemo, isFalse);
    });
  });
}
