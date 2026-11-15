import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silsila_app/erp/screens/erp_screen_layout_studio_screen.dart';
import 'package:silsila_app/erp/services/erp_screen_layout_profiles.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ErpScreenLayoutProfiles.profiles.value = <String, dynamic>{};
  });

  testWidgets('shows layout controls and live placement preview', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ErpScreenLayoutStudioScreen(availableScreens: const ['شاشة اختبار مخصصة'])),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('شاشة اختبار مخصصة'), findsOneWidget);
    await tester.tap(find.text('شاشة اختبار مخصصة'));
    await tester.pumpAndSettle();

    expect(find.text('مواضع عناصر الشاشة'), findsOneWidget);
    expect(find.text('مكان التبويبات'), findsOneWidget);
    expect(find.text('مكان أزرار المهام'), findsOneWidget);
    expect(find.text('مكان التاريخ والفلاتر الزمنية'), findsOneWidget);
    expect(find.text('مكان الصور'), findsOneWidget);
    expect(find.text('مكان شريط التمرير'), findsOneWidget);
    expect(find.text('معاينة فورية للتخطيط'), findsOneWidget);
    expect(find.text('من تاريخ — إلى تاريخ'), findsOneWidget);
    expect(find.text('صور الأصناف'), findsOneWidget);
  });

  testWidgets('image visibility toggle updates the live preview', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ErpScreenLayoutStudioScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('صور الأصناف'), findsOneWidget);
    await tester.ensureVisible(find.text('الصور'));
    await tester.tap(find.text('الصور'));
    await tester.pumpAndSettle();
    expect(find.text('صور الأصناف'), findsNothing);
  });
}
