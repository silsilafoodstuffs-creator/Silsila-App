import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_company_branches_design_screen.dart';

void main() {
  testWidgets(
    'company profile uses the redesigned live branches directory',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErpCompanyBranchesDesignScreen(
              companyId: 'company-test',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('فروع الشركة'), findsOneWidget);
      expect(
        find.text(
          'إدارة بيانات الفروع الفعلية ومواقعها ووسائل الاتصال والمخازن التابعة',
        ),
        findsOneWidget,
      );
      expect(find.text('إضافة فرع'), findsOneWidget);
      expect(find.text('سجّل الدخول إلى Supabase أولًا.'), findsOneWidget);
    },
  );
}
