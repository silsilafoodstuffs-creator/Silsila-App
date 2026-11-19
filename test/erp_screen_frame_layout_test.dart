import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/widgets/erp_screen_frame.dart';

void main() {
  testWidgets('applies the active screen profile to nested frame positions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ErpScreenLayoutScope(
          screen: 'قائمة الاختبار',
          profile: <String, dynamic>{
            'showTitle': true,
            'showTabs': true,
            'showTasks': true,
            'showFooter': false,
            'tabsPosition': 'top',
            'tasksPosition': 'bottom',
          },
          child: ErpScreenFrame(
            title: 'عنوان داخلي مختلف',
            tabs: const ['تبويب الاختبار'],
            actions: const [Text('شريط المهام الاختباري')],
            child: const Text('محتوى الشاشة'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tab = tester.getRect(find.text('تبويب الاختبار'));
    final title = tester.getRect(find.text('عنوان داخلي مختلف'));
    final body = tester.getRect(find.text('محتوى الشاشة'));
    final task = tester.getRect(find.text('شريط المهام الاختباري'));

    expect(tab.bottom, lessThan(title.top));
    expect(body.bottom, lessThan(task.top));
  });

  testWidgets('hides taskbar when its saved position is hidden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ErpScreenLayoutScope(
          screen: 'قائمة الاختبار',
          profile: <String, dynamic>{
            'showTitle': true,
            'showTabs': false,
            'showTasks': true,
            'showFooter': false,
            'tasksPosition': 'hidden',
          },
          child: ErpScreenFrame(
            title: 'عنوان الاختبار',
            actions: const [Text('يجب ألا يظهر شريط المهام')],
            child: const Text('محتوى الشاشة'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('يجب ألا يظهر شريط المهام'), findsNothing);
  });
}
