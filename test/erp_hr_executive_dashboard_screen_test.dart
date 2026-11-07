import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_hr_executive_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The Supabase auth client uses SharedPreferences during initialization.
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (methodCall) async {
        if (methodCall.method == 'getAll') return <String, Object>{};
        return null;
      },
    );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
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
    expect(find.textContaining('افتح بيانات الشركة أولاً'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('الهيكل التنظيمي والوظائف'), 400, scrollable: scrollable);
    expect(find.text('الهيكل التنظيمي والوظائف'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('التأمينات والرخص والتدريب'), 400, scrollable: scrollable);
    expect(find.text('التأمينات والرخص والتدريب'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('التوظيف والاستقالات ودوران العمالة'), 400, scrollable: scrollable);
    expect(find.text('التوظيف والاستقالات ودوران العمالة'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('تنبيهات ومتابعات مدير الموارد البشرية'), 400, scrollable: scrollable);
    expect(find.text('تنبيهات ومتابعات مدير الموارد البشرية'), findsOneWidget);
    expect(find.text('سجلات موظفين مؤقتة'), findsOneWidget);
    expect(find.text('التعيينات المستقبلية'), findsOneWidget);
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
  test('operational employee filtering excludes temporary, Arabic test, and demo rows', () {
    final rows = filterHrOperationalEmployees([
      {'id': 'real-1', 'notes': 'موظف فعلي'},
      {'id': 'seed-1', 'notes': 'بيانات أولية مؤقتة'},
      {'id': 'test-1', 'notes': 'سجل اختبار'},
      {'id': 'demo-1', 'notes': 'demo employee'},
      {'id': 'test-status', 'employment_status': 'test'},
    ]);

    expect(rows.map((row) => row['id']).toList(), ['real-1']);
  });

  test('operational employee filtering does not treat an empty source as complete data', () {
    expect(filterHrOperationalEmployees([]), isEmpty);
  });

  testWidgets('HR dashboard exposes performance and vacancy data-quality notices',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ErpHrExecutiveDashboardScreen(companyId: null),
      ),
    ));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('تقييم الأداء'), 450, scrollable: scrollable);
    expect(find.text('تقييم الأداء'), findsOneWidget);
    expect(find.textContaining('غير متاح — لا توجد تقييمات مكتملة'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('الوظائف الشاغرة: غير متاحة'), 450, scrollable: scrollable);
    expect(find.textContaining('الوظائف الشاغرة: غير متاحة'), findsOneWidget);
  });

}
