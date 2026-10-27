import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_user_admin_screen.dart';

void main() {
  testWidgets(
    'user administration shows the five configured user types and tree/table controls without Supabase',
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

      expect(find.text('المستخدمين'), findsWidgets);
      expect(find.text('عرض شجرة'), findsOneWidget);
      expect(find.text('عرض جدول'), findsOneWidget);
      expect(find.textContaining('بحث في أنواع المستخدمين'), findsOneWidget);
      // The tree is a lazily built ListView; switch to the complete grid before
      // asserting rows that may initially be below the viewport.
      await tester.tap(find.text('عرض جدول'));
      await tester.pumpAndSettle();

      expect(find.text('ادمن'), findsOneWidget);
      expect(find.text('مورد'), findsOneWidget);
      expect(find.text('عميل'), findsOneWidget);
      expect(find.text('مندوب'), findsOneWidget);
      expect(find.text('شركة شحن'), findsOneWidget);
      expect(find.textContaining('للمعاينة'), findsOneWidget);

      // Switching back must render the expandable hierarchy, not leave the
      // table in place or produce an empty tree.
      await tester.tap(find.text('عرض شجرة'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('ادمن'), findsOneWidget);
      // Scroll the hierarchy's actual viewport. scrollUntilVisible can select
      // an offstage Scrollable from the previous table view on web/test builds.
      for (var i = 0; i < 8 && find.text('شركة شحن').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -350));
        await tester.pumpAndSettle();
      }
      expect(find.text('شركة شحن'), findsOneWidget);
    },
  );
}
