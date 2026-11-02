import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_financial_operations_screen.dart';

void main() {
  testWidgets('checkbook registration grid supports adding and removing draft rows', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ErpFinancialOperationsScreen(
          companyId: null,
          initialView: 'تسجيل دفاتر شيكات',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('إضافة دفتر'), findsOneWidget);
    expect(find.byTooltip('حذف السطر'), findsOneWidget);

    await tester.tap(find.text('إضافة دفتر'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('حذف السطر'), findsNWidgets(2));

    await tester.tap(find.byTooltip('حذف السطر').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('حذف السطر'), findsOneWidget);
  });
}