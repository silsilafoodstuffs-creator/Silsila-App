import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/main.dart';

void main() {
  testWidgets('welcome screen displays Silsila branding and primary action',
      (tester) async {
    await tester.pumpWidget(const SilsilaApp());
    await tester.pump();

    expect(find.text('سلسلة Silsila'), findsOneWidget);
    expect(find.text('بنربط السوق ببعضه'), findsOneWidget);
    expect(find.text('ابدأ الآن'), findsOneWidget);
  });

  testWidgets('primary action uses the Silsila color identity',
      (tester) async {
    await tester.pumpWidget(const SilsilaApp());
    await tester.pump();

    final context = tester.element(find.text('ابدأ الآن'));
    final theme = Theme.of(context);

    expect(theme.colorScheme.primary, const Color(0xFF3E007D));
    expect(theme.colorScheme.secondary, const Color(0xFFFFA015));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Tajawal');
  });

  testWidgets('login flow requests email and password, not phone OTP',
      (tester) async {
    await tester.pumpWidget(const SilsilaApp());
    await tester.tap(find.text('ابدأ الآن'));
    await tester.pumpAndSettle();

    expect(find.text('البريد الإلكتروني المسجل'), findsOneWidget);
    expect(find.text('اكتب كلمة المرور الخاصة بك'), findsOneWidget);
    expect(find.text('رقم الهاتف المسجل'), findsNothing);
    expect(find.text('إرسال رمز التحقق'), findsNothing);
  });
}
