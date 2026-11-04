import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_inventory_screen.dart';
import 'package:silsila_app/erp/screens/erp_payroll_screen.dart';
import 'package:silsila_app/erp/screens/erp_price_lists_screen.dart';

// Regression coverage for database-generated, read-only code fields.
Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('price list code is generated automatically and adding preserves the unsaved name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ErpPriceListsScreen())),
    ));
    await tester.pumpAndSettle();

    final generatedCode = tester.widget<TextField>(field('كود القائمة (تلقائي)'));
    expect(generatedCode.readOnly, isTrue);
    await tester.enterText(field('اسم القائمة *'), 'قائمة اختبار');
    await tester.tap(find.text('إضافة').first);
    await tester.pump();

    expect(tester.widget<TextField>(field('كود القائمة (تلقائي)')).readOnly, isTrue);
    expect(tester.widget<TextField>(field('اسم القائمة *')).controller!.text, 'قائمة اختبار');
    expect(find.textContaining('لم يتم مسح أي بيانات'), findsOneWidget);
  });

  testWidgets('payroll run code is generated automatically and remains read-only', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ErpPayrollScreen())),
    ));
    await tester.pumpAndSettle();

    final generatedCode = tester.widget<TextField>(field('كود المسير (تلقائي)'));
    expect(generatedCode.readOnly, isTrue);
    await tester.tap(find.text('إضافة').first);
    await tester.pump();

    expect(tester.widget<TextField>(field('كود المسير (تلقائي)')).readOnly, isTrue);
    expect(find.textContaining('سيُنشأ الكود تلقائيًا عند الحفظ'), findsOneWidget);
  });

  testWidgets('adding an inventory movement preserves a manually entered unit cost', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ErpInventoryScreen())),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(field('تكلفة الوحدة'), '17.5');
    await tester.tap(find.text('إضافة').first);
    await tester.pump();

    expect(tester.widget<TextField>(field('تكلفة الوحدة')).controller!.text, '17.5');
    expect(find.textContaining('احفظ الحركة الحالية أولًا'), findsOneWidget);
  });
}
