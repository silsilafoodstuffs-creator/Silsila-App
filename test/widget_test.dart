import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/main.dart';
import 'package:silsila_app/services/app_language.dart';
import 'package:silsila_app/widgets/silsila_white_logo.dart';

void main() {
  testWidgets('welcome screen displays Silsila branding and primary action',
      (tester) async {
    await tester.pumpWidget(const SilsilaApp());
    await tester.pump();

    expect(find.text('سلسلة Silsila'), findsOneWidget);
    expect(find.text('بنربط السوق ببعضه'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
    final welcomeScaffold = tester.widget<Scaffold>(
      find.ancestor(
        of: find.text('ابدأ'),
        matching: find.byType(Scaffold),
      ).first,
    );
    final welcomeContainer = tester.widget<Container>(
      find.descendant(
        of: find.byWidget(welcomeScaffold),
        matching: find.byType(Container),
      ).first,
    );
    expect(
      (welcomeContainer.decoration! as BoxDecoration).color,
      const Color(0xFF3E007D),
    );
  });

  testWidgets('English selection translates app labels and switches layout direction',
      (tester) async {
    SilsilaLanguage.locale.value = const Locale('en');
    await tester.pumpWidget(const SilsilaApp());
    await tester.pump();

    expect(SilsilaLanguage.isEnglish, isTrue);
    expect(silsilaText('نوع النشاط'), 'Business activity');
    expect(find.text('ابدأ'), findsOneWidget);
    final direction = tester.widget<Directionality>(
      find.ancestor(
        of: find.text('ابدأ'),
        matching: find.byType(Directionality),
      ).first,
    );
    expect(direction.textDirection, TextDirection.ltr);

    SilsilaLanguage.locale.value = const Locale('ar');
    await tester.pump();
  });

  testWidgets('primary action uses the Silsila color identity',
      (tester) async {
    await tester.pumpWidget(const SilsilaApp());
    await tester.pump();

    final context = tester.element(find.text('ابدأ'));
    final theme = Theme.of(context);

    expect(theme.colorScheme.primary, const Color(0xFF3E007D));
    expect(theme.colorScheme.secondary, const Color(0xFFFFA015));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Tajawal');
    expect(theme.floatingActionButtonTheme.backgroundColor,
        const Color(0xFFFFA015));
    expect(theme.snackBarTheme.backgroundColor, const Color(0xFF3E007D));
    expect(theme.progressIndicatorTheme.color, const Color(0xFFFFA015));
    expect(theme.listTileTheme.selectedTileColor, isNotNull);
  });

  testWidgets('white surfaces render the white-background Silsila logo',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: SilsilaWhiteLogo(width: 48, height: 48)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
  });

  testWidgets('login screen uses the white-background Silsila logo variant',
      (tester) async {
    await tester.pumpWidget(const SilsilaApp());
    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();

    expect(find.byType(SilsilaWhiteLogo), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
  });

  testWidgets('login flow requests email and password, not phone OTP',
      (tester) async {
    await tester.pumpWidget(const SilsilaApp());
    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();

    expect(find.text('البريد الإلكتروني المسجل'), findsOneWidget);
    expect(find.text('اكتب كلمة المرور الخاصة بك'), findsOneWidget);
    expect(find.text('رقم الهاتف المسجل'), findsNothing);
    expect(find.text('إرسال رمز التحقق'), findsNothing);
  });
}
