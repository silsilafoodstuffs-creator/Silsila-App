import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_report_center_screen.dart';

void main() {
  testWidgets('report center refuses to show demo rows when no company is selected',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErpReportCenterScreen(
            companyId: null,
            reportName: 'تقرير المستخدمين',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تقرير المستخدمين'), findsOneWidget);
    expect(find.textContaining('لا توجد شركة محددة'), findsOneWidget);
    expect(find.text('لا توجد سجلات في مصدر التقرير المحدد.'), findsNothing);
  });
}
