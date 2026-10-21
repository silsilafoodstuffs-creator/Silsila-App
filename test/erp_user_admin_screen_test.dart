import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_user_admin_screen.dart';

void main() {
  testWidgets(
    'user types grid stays visible with default preview rows when Supabase is unavailable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErpUserAdminScreen(
              companyId: null,
              initialView: 'types',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أنواع المستخدمين'), findsOneWidget);
      expect(find.text('كود النوع'), findsOneWidget);
      expect(find.text('ادمن'), findsOneWidget);
      expect(find.text('موظف'), findsOneWidget);
      expect(find.text('مورد'), findsOneWidget);
      expect(find.text('عميل'), findsOneWidget);
      expect(find.text('مندوب'), findsOneWidget);
      expect(find.text('شركة شحن'), findsOneWidget);
      expect(
        find.textContaining('للمعاينة'),
        findsOneWidget,
      );
    },
  );
}
