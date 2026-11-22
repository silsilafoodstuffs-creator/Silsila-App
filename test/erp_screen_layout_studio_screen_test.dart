import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silsila_app/erp/screens/erp_screen_layout_studio_screen.dart';
import 'package:silsila_app/erp/services/erp_screen_layout_profiles.dart';
import 'package:silsila_app/erp/screens/erp_operational_documents_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ErpScreenLayoutProfiles.resetForTesting();
  });

  testWidgets('shows layout controls and live placement preview', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ErpScreenLayoutStudioScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    expect(find.text('مرتجع مبيعات'), findsWidgets);
    await tester.tap(find.text('مرتجع مبيعات').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('عرض'));
    await tester.pumpAndSettle();

    expect(find.text('مواضع عناصر الشاشة'), findsOneWidget);
    expect(find.text('مكان التبويبات'), findsOneWidget);
    expect(find.text('مكان أزرار المهام'), findsOneWidget);
    expect(find.text('مكان التاريخ والفلاتر الزمنية'), findsOneWidget);
    expect(find.text('مكان الصور'), findsOneWidget);
    expect(find.text('مكان شريط التمرير'), findsOneWidget);
    expect(find.text('معاينة فورية للتخطيط'), findsOneWidget);
    expect(find.text('مكان التاريخ والفلاتر الزمنية'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
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

    await tester.tap(find.text('عرض'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    await tester.ensureVisible(find.text('الصور'));
    await tester.tap(find.text('الصور'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });
  testWidgets('renders a safe live sales invoice preview without database writes', (tester) async {
    tester.view.physicalSize = const Size(1500, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ErpScreenLayoutProfiles.profiles.value = <String, dynamic>{
      'فاتورة بيع': <String, dynamic>{
        'themePreset': 'glossy_neon_luxury',
        'headerStyle': 'neon',
        'primary': const Color(0xFF3E007D).toARGB32(),
        'accent': const Color(0xFFFF27C3).toARGB32(),
        'salesActionOrder': <String>['حفظ','تحديث','إضافة','تعديل','حذف','معاينة','طباعة','استيراد Excel','تصدير Excel','طباعة PDF'],
        'salesFieldOrder': <String>['اسم العميل','المخزن','مندوب المبيعات','مصدر المستند','نوع البيع / السداد'],
      },
    };

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ErpOperationalDocumentsScreen(
          kind: ErpOperationalKind.sales,
          initialDocumentType: 'invoice',
          previewOnly: true,
          initialTab: 2,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة بيع'), findsWidgets);
    expect(find.text('أرز مصري فاخر 1 كجم'), findsWidgets);
    expect(find.text('زيت خليط 1 لتر'), findsWidgets);
    expect(find.text('الخصومات والملاحظات'), findsWidgets);
  });

}
