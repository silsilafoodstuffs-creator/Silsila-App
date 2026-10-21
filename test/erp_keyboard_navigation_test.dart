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
}
