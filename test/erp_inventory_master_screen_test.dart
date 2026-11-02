import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_inventory_master_screen.dart';

void main() {
  testWidgets('warehouse master renders inside a bounded scroll viewport without Supabase',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ErpInventoryMasterScreen(initialView: 'warehouses'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('بيانات المخازن'), findsOneWidget);
    expect(find.text('تحديث'), findsOneWidget);
    expect(find.text('كود المخزن *'), findsOneWidget);
    expect(find.text('اسم المخزن عربي *'), findsOneWidget);
    expect(find.textContaining('لم يتم العثور على شركة نشطة'), findsOneWidget);
  });

  testWidgets('item master opens directly on item data and unit fields',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ErpInventoryMasterScreen(initialView: 'items'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بيانات الأصناف'), findsOneWidget);
    expect(find.text('كود الصنف *'), findsOneWidget);
    expect(find.text('اسم الصنف عربي *'), findsOneWidget);
    expect(find.text('الوحدة الكبرى *'), findsOneWidget);
  });
}
