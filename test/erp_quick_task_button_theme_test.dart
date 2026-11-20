import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/widgets/erp_quick_task_button.dart';

void main() {
  testWidgets('ERP quick task buttons use a glossy gradient without changing actions',
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

    final glossySurface = tester.widget<Container>(
      find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).gradient != null),
    );
    final decoration = glossySurface.decoration! as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
    expect(decoration.boxShadow, isNotEmpty);

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
