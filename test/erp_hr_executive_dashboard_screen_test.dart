import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_hr_executive_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('HR executive dashboard renders Silsila leadership identity and analysis controls',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ErpHrExecutiveDashboardScreen(companyId: null),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ملخص إدارة الموارد البشرية'), findsOneWidget);
    expect(find.text('لوحة قيادة رأس المال البشري'), findsOneWidget);
    expect(find.text('فترة التحليل'), findsOneWidget);
    expect(find.text('إجمالي الموظفين'), findsOneWidget);
    expect(find.text('الهيكل التنظيمي والوظائف'), findsOneWidget);
    expect(find.text('التأمينات والرخص والتدريب'), findsOneWidget);
    expect(find.text('التوظيف والاستقالات ودوران العمالة'), findsOneWidget);
    expect(find.text('تنبيهات ومتابعات مدير الموارد البشرية'), findsOneWidget);
    expect(find.textContaining('افتح بيانات الشركة أولاً'), findsOneWidget);
  });

  testWidgets('HR executive dashboard exposes the supported analysis periods',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ErpHrExecutiveDashboardScreen(companyId: null),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();

    expect(find.text('آخر 30 يومًا'), findsOneWidget);
    expect(find.text('آخر 90 يومًا'), findsOneWidget);
    expect(find.text('آخر 6 أشهر'), findsOneWidget);
    expect(find.text('آخر 12 شهرًا'), findsWidgets);
  });
}
