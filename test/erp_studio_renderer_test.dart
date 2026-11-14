import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/services/studio_document.dart';
import 'package:silsila_app/erp/services/studio_renderer.dart';

void main() {
  group('StudioDocumentRenderer', () {
    testWidgets('renders a data-bound table using supplied safe preview rows', (tester) async {
      final document = StudioDocument(
        id: 'table-test',
        name: 'اختبار الجدول',
        nodes: [
          StudioNode(
            id: 'items-table',
            type: 'table',
            props: {
              'columns': ['item_code', 'item_name'],
              'binding': {'source': 'items', 'field': 'item_name', 'mode': 'read'},
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudioDocumentRenderer(
            document: document,
            dataBySource: {
              'items': [
                {'item_code': 'Itm0001', 'item_name': 'أرز معبأ'},
                {'item_code': 'Itm0002', 'item_name': 'سكر معبأ'},
              ],
            },
          ),
        ),
      ));

      expect(find.text('Itm0001'), findsOneWidget);
      expect(find.text('أرز معبأ'), findsOneWidget);
      expect(find.text('سكر معبأ'), findsOneWidget);
    });

    testWidgets('does not render hidden components', (tester) async {
      final document = StudioDocument(
        id: 'hidden-test',
        name: 'اختبار الإخفاء',
        nodes: [
          StudioNode(id: 'visible', type: 'text', props: {'text': 'ظاهر'}),
          StudioNode(id: 'hidden', type: 'text', props: {'text': 'مخفي'}, hidden: true),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StudioDocumentRenderer(document: document)),
      ));

      expect(find.text('ظاهر'), findsOneWidget);
      expect(find.text('مخفي'), findsNothing);
    });

    testWidgets('renders grouped components inside a shared visual container', (tester) async {
      final document = StudioDocument(
        id: 'group-test',
        name: 'اختبار التجميع',
        nodes: [
          StudioNode(id: 'a', type: 'text', props: {'text': 'عنصر أول'}, groupId: 'g1'),
          StudioNode(id: 'b', type: 'text', props: {'text': 'عنصر ثان'}, groupId: 'g1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StudioDocumentRenderer(document: document)),
      ));

      expect(find.text('مجموعة عناصر'), findsOneWidget);
      expect(find.text('عنصر أول'), findsOneWidget);
      expect(find.text('عنصر ثان'), findsOneWidget);
    });

    testWidgets('simulates an allow-listed button action only in interactive preview', (tester) async {
      String? action;
      final document = StudioDocument(
        id: 'action-test',
        name: 'اختبار الأزرار',
        nodes: [
          StudioNode(id: 'save', type: 'button', props: {'text': 'حفظ تجريبي', 'actionKey': 'preview'}),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudioDocumentRenderer(
            document: document,
            interactive: true,
            onAction: (value) => action = value,
          ),
        ),
      ));

      await tester.tap(find.text('حفظ تجريبي'));
      expect(action, 'preview');
    });
  });
}
