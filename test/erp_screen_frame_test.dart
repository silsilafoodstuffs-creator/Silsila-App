import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/services/erp_screen_layout_profiles.dart';
import 'package:silsila_app/erp/widgets/erp_screen_frame.dart';

void main() {
  setUp(() {
    ErpScreenLayoutProfiles.profiles.value = <String, dynamic>{};
  });

  tearDown(() {
    ErpScreenLayoutProfiles.profiles.value = <String, dynamic>{};
  });

  testWidgets('applies configured task and tab positions', (tester) async {
    ErpScreenLayoutProfiles.profiles.value = {
      'اختبار التخطيط': {
        'tasksPosition': 'top',
        'tabsPosition': 'bottom',
      },
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(textDirection: TextDirection.rtl, child: ErpScreenFrame(
          title: 'اختبار التخطيط',
          tabs: const ['البيانات'],
          actions: [
            TextButton(onPressed: null, child: const Text('إجراء')),
          ],
          child: const Text('محتوى الشاشة'),
        )),
      ),
    ));

    final actionY = tester.getTopLeft(find.text('إجراء')).dy;
    final titleY = tester.getTopLeft(find.text('اختبار التخطيط')).dy;
    final contentY = tester.getTopLeft(find.text('محتوى الشاشة')).dy;
    final tabY = tester.getTopLeft(find.text('البيانات')).dy;

    expect(actionY, lessThan(titleY));
    expect(tabY, greaterThan(contentY));
  });

  testWidgets('hides configured tabs and task bar', (tester) async {
    ErpScreenLayoutProfiles.profiles.value = {
      'اختبار الإخفاء': {
        'tabsPosition': 'hidden',
        'tasksPosition': 'hidden',
      },
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(textDirection: TextDirection.rtl, child: ErpScreenFrame(
          title: 'اختبار الإخفاء',
          tabs: const ['تبويب مخفي'],
          actions: [
            TextButton(onPressed: null, child: const Text('إجراء مخفي')),
          ],
          child: const Text('المحتوى'),
        )),
      ),
    ));

    expect(find.text('تبويب مخفي'), findsNothing);
    expect(find.text('إجراء مخفي'), findsNothing);
    expect(find.text('المحتوى'), findsOneWidget);
  });

  testWidgets('renders side-positioned tabs and actions', (tester) async {
    ErpScreenLayoutProfiles.profiles.value = {
      'اختبار الجانب': {
        'tabsPosition': 'right',
        'tasksPosition': 'left',
      },
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(textDirection: TextDirection.rtl, child: ErpScreenFrame(
          title: 'اختبار الجانب',
          tabs: const ['تبويب جانبي'],
          actions: [
            TextButton(onPressed: null, child: const Text('إجراء جانبي')),
          ],
          child: const Text('محتوى جانبي'),
        )),
      ),
    ));

    expect(find.text('تبويب جانبي'), findsOneWidget);
    expect(find.text('إجراء جانبي'), findsOneWidget);
    expect(find.text('محتوى جانبي'), findsOneWidget);
    final tabX = tester.getTopLeft(find.text('تبويب جانبي')).dx;
    final actionX = tester.getTopLeft(find.text('إجراء جانبي')).dx;
    final contentX = tester.getTopLeft(find.text('محتوى جانبي')).dx;
    expect(tabX, greaterThan(contentX), reason: 'RTL right rail should remain on the visual right.');
    expect(actionX, lessThan(contentX), reason: 'RTL left rail should remain on the visual left.');
  });
  testWidgets('places date, image and sidebar slots from Studio profile', (tester) async {
    ErpScreenLayoutProfiles.profiles.value = {
      'اختبار العناصر': {
        'datePosition': 'left',
        'imagesPosition': 'right',
        'showSidebar': true,
        'showScroll': false,
      },
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(textDirection: TextDirection.rtl, child: ErpScreenFrame(
          title: 'اختبار العناصر',
          dateFilter: const Text('مرشح التاريخ'),
          imagePanel: const Text('لوحة الصور'),
          sidebar: const Text('قائمة جانبية'),
          child: const Text('المحتوى الرئيسي'),
        )),
      ),
    ));

    expect(find.text('مرشح التاريخ'), findsOneWidget);
    expect(find.text('لوحة الصور'), findsOneWidget);
    expect(find.text('قائمة جانبية'), findsOneWidget);
    final dateX = tester.getTopLeft(find.text('مرشح التاريخ')).dx;
    final imageX = tester.getTopLeft(find.text('لوحة الصور')).dx;
    final contentX = tester.getTopLeft(find.text('المحتوى الرئيسي')).dx;
    expect(dateX, lessThan(contentX));
    expect(imageX, greaterThan(contentX));
  });

  testWidgets('supports shared tabs without duplicating a specialized screen title', (tester) async {
    ErpScreenLayoutProfiles.profiles.value = {
      'اختبار الشاشة المتخصصة': {'tabsPosition': 'top'},
    };

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ErpScreenFrame(
            title: 'عنوان إطار لا يجب عرضه',
            showFrameTitle: false,
            applyContentWidth: false,
            tabs: const ['بيانات أساسية', 'حركات', 'تقارير'],
            child: const Text('عنوان الشاشة المتخصصة'),
          ),
        ),
      ),
    ));

    expect(find.text('عنوان إطار لا يجب عرضه'), findsNothing);
    expect(find.text('عنوان الشاشة المتخصصة'), findsOneWidget);
    expect(find.text('بيانات أساسية'), findsOneWidget);
  });

}
