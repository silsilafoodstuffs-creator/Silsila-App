import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/widgets/erp_quick_task_button.dart';

void main() {
  testWidgets('ERP quick task buttons use semantic action colors without changing actions',
      (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErpQuickTaskButton(
            label: 'إضافة',
            icon: Icons.add,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byWidgetPredicate((widget) => widget is FilledButton));
    expect(
      button.style?.backgroundColor?.resolve({}),
      const Color(0xFF18865A),
    );

    expect(find.text('إضافة'), findsOneWidget);
    await tester.tap(find.text('إضافة'));
    await tester.pump();
    expect(pressed, isTrue);
  });

  testWidgets('ERP quick task buttons are hidden when the current screen action is not allowed',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ErpQuickTaskPermissionScope(
          canPerform: (_) => false,
          child: Scaffold(
            body: ErpQuickTaskButton(
              label: 'إضافة',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('إضافة'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
