import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/widgets/erp_quick_task_button.dart';

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

    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton)).toList();
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

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.backgroundColor!.resolve(<WidgetState>{}), const Color(0xFF123456));
    expect(find.byIcon(Icons.table_rows_outlined), findsOneWidget);
  });
}
