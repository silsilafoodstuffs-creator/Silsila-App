import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/widgets/erp_quick_task_button.dart';
import 'package:silsila_app/erp/widgets/erp_standard_data_table.dart';
import 'package:silsila_app/erp/widgets/erp_catalog_tree_card.dart';

Finder _filledButtons() =>
    find.byWidgetPredicate((widget) => widget is FilledButton);

void main() {
  testWidgets('tree and table actions keep their own icons and shared palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ErpQuickTaskButton(
                label: 'عرض شجرة',
                icon: Icons.account_tree_outlined,
                kind: ErpQuickTaskKind.treeView,
                onPressed: () {},
              ),
              ErpQuickTaskButton(
                label: 'عرض جدول',
                icon: Icons.table_rows_outlined,
                kind: ErpQuickTaskKind.tableView,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
    expect(find.byIcon(Icons.table_rows_outlined), findsOneWidget);
    expect(find.byIcon(Icons.preview_outlined), findsNothing);

    final buttons = tester.widgetList<FilledButton>(_filledButtons()).toList();
    expect(buttons, hasLength(2));
    expect(buttons[0].style!.backgroundColor!.resolve(<WidgetState>{}), const Color(0xFF6E2BA6));
    expect(buttons[1].style!.backgroundColor!.resolve(<WidgetState>{}), const Color(0xFF6E2BA6));
  });

  testWidgets('explicit custom action kind preserves caller icon and fallback color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErpQuickTaskButton(
            label: 'عرض جدول',
            icon: Icons.table_rows_outlined,
            kind: ErpQuickTaskKind.custom,
            fallbackColor: const Color(0xFF123456),
            onPressed: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(_filledButtons());
    expect(button.style!.backgroundColor!.resolve(<WidgetState>{}), const Color(0xFF123456));
    expect(find.byIcon(Icons.table_rows_outlined), findsOneWidget);
  });

  testWidgets('standard ERP data table enforces the shared 40px row contract', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ErpStandardDataTable(
              columns: <DataColumn>[DataColumn(label: Text('الكود'))],
              rows: <DataRow>[
                DataRow(cells: <DataCell>[DataCell(Text('ITM001'))]),
              ],
            ),
          ),
        ),
      ),
    );

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.headingRowHeight, 40);
    expect(table.dataRowMinHeight, 40);
    expect(table.dataRowMaxHeight, 40);
    expect(table.horizontalMargin, 5);
    expect(table.columnSpacing, 5);
  });
  testWidgets('semantic custom action does not infer destructive confirmation from its label', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErpQuickTaskButton(
            label: 'حذف صورة',
            icon: Icons.delete_outline,
            kind: ErpQuickTaskKind.custom,
            onPressed: () => calls++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('حذف صورة'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('catalog tree card provides shared selection surface', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErpCatalogTreeCard(
            depth: 1,
            selected: false,
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFFF0E7FA),
            borderColor: const Color(0xFFE8E1EF),
            selectedBorderColor: const Color(0xFF3E007D),
            onTap: () => selected = true,
            child: const Text('عنصر تجريبي'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('عنصر تجريبي'));
    expect(selected, isTrue);
  });

}
