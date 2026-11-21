import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/erp_dashboard_screen.dart';
import 'package:silsila_app/erp/services/erp_screen_layout_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Studio Grid density is applied to live ERP widgets', (tester) async {
    final original = Map<String, dynamic>.from(ErpScreenLayoutProfiles.profiles.value);
    addTearDown(() => ErpScreenLayoutProfiles.profiles.value = original);
    ErpScreenLayoutProfiles.profiles.value = <String, dynamic>{
      'Studio test screen': <String, dynamic>{'gridStyle': 'comfortable'},
    };

    await tester.pumpWidget(
      MaterialApp(
        home: ErpScreenLayoutRuntime(
          screen: 'Studio test screen',
          child: Builder(
            builder: (context) {
              expect(Theme.of(context).visualDensity, VisualDensity.standard);
              expect(Theme.of(context).dividerTheme.thickness, 0.7);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });

  testWidgets('Studio outlined Grid preset strengthens live separators', (tester) async {
    final original = Map<String, dynamic>.from(ErpScreenLayoutProfiles.profiles.value);
    addTearDown(() => ErpScreenLayoutProfiles.profiles.value = original);
    ErpScreenLayoutProfiles.profiles.value = <String, dynamic>{
      'Studio test screen': <String, dynamic>{'gridStyle': 'outlined'},
    };

    await tester.pumpWidget(
      MaterialApp(
        home: ErpScreenLayoutRuntime(
          screen: 'Studio test screen',
          child: Builder(
            builder: (context) {
              expect(Theme.of(context).dividerTheme.thickness, 1.2);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });
}
