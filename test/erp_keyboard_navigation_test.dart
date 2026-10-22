import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/widgets/erp_keyboard_navigation.dart';

void main() {
  testWidgets('F12 invokes add and F8 invokes save callbacks', (tester) async {
    var addCalls = 0;
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ErpKeyboardNavigation(
          child: Builder(
            builder: (context) {
              ErpKeyboardNavigation.registerActions(
                add: () => addCalls++,
                save: () => saveCalls++,
              );
              return const Scaffold(
                body: Center(child: Text('Keyboard actions ready')),
              );
            },
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.f12);
    await tester.pump();
    expect(addCalls, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await tester.pump();
    expect(saveCalls, 1);
  });

  testWidgets('registered shortcuts survive a parent rebuild when child is unchanged', (tester) async {
    var addCalls = 0;
    var saveCalls = 0;
    final stableChild = Builder(
      builder: (context) {
        ErpKeyboardNavigation.registerActions(
          add: () => addCalls++,
          save: () => saveCalls++,
        );
        return const Scaffold(body: Center(child: Text('Stable ERP screen')));
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setParentState) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => setParentState(() {}),
                  child: const Text('Rebuild parent'),
                ),
                Expanded(child: ErpKeyboardNavigation(child: stableChild)),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rebuild parent'));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.f12);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await tester.pump();

    expect(addCalls, 1);
    expect(saveCalls, 1);
  });
}
