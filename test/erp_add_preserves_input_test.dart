import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_inventory_screen.dart';
import 'package:silsila_app/erp/screens/erp_payroll_screen.dart';
import 'package:silsila_app/erp/screens/erp_price_lists_screen.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('adding a price list does not clear an unsaved code or name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ErpPriceListsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(field('كود القائمة *'), 'PL-TEST');
    await tester.enterText(field('اسم القائمة *'), 'قائمة اختبار');
    await tester.tap(find.text('إضافة').first);
    await tester.pump();

    expect(tester.widget<TextField>(field('كود القائمة *')).controller!.text, 'PL-TEST');
    expect(tester.widget<TextField>(field('اسم القائمة *')).controller!.text, 'قائمة اختبار');
    expect(find.textContaining('لم يتم مسح أي بيانات'), findsOneWidget);
  });

  testWidgets('adding a payroll run does not clear an unsaved run code', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ErpPayrollScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(field('كود المسير *'), 'PAY-TEST');
    await tester.tap(find.text('إضافة').first);
    await tester.pump();

    expect(tester.widget<TextField>(field('كود المسير *')).controller!.text, 'PAY-TEST');
    expect(find.textContaining('لم يتم مسح أي بيانات'), findsOneWidget);
  });

  testWidgets('adding an inventory movement preserves a manually entered unit cost', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ErpInventoryScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(field('تكلفة الوحدة'), '17.5');
    await tester.tap(find.text('إضافة').first);
    await tester.pump();

    expect(tester.widget<TextField>(field('تكلفة الوحدة')).controller!.text, '17.5');
    expect(find.textContaining('احفظ الحركة الحالية أولًا'), findsOneWidget);
  });
}
