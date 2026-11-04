import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_facebook_group_leads_screen.dart';

void main() {
  testWidgets('Facebook group leads screen shows safe manual workflow without company',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErpFacebookGroupLeadsScreen(companyId: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إضافة حسابات جروبات فيسبوك'), findsOneWidget);
    expect(find.textContaining('واجهة Meta الرسمية لا تتيح حالياً'), findsOneWidget);
    expect(find.text('اختر شركة نشطة لبدء إدارة حسابات الجروبات.'), findsOneWidget);
  });
}
