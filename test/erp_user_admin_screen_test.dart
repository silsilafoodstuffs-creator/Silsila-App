import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_user_admin_screen.dart';

void main() {
  testWidgets(
    'combined user hierarchy shows default user types and tree/table controls without Supabase',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErpUserAdminScreen(
              companyId: null,
              initialView: 'hierarchy',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أنواع المستخدمين والمستخدمين'), findsOneWidget);
      expect(find.text('عرض شجرة'), findsOneWidget);
      expect(find.text('عرض جدول'), findsOneWidget);
      expect(find.textContaining('بحث في أنواع المستخدمين'), findsOneWidget);
      // The tree is a lazily built ListView; switch to the complete grid before
      // asserting rows that may initially be below the viewport.
      await tester.tap(find.text('عرض جدول'));
      await tester.pumpAndSettle();

      expect(find.text('ادمن'), findsOneWidget);
      expect(find.text('موظف'), findsOneWidget);
      expect(find.text('مورد'), findsOneWidget);
      expect(find.text('عميل'), findsOneWidget);
      expect(find.text('مندوب'), findsOneWidget);
      expect(find.text('شركة شحن'), findsOneWidget);
      expect(find.textContaining('للمعاينة'), findsOneWidget);
    },
  );
}
