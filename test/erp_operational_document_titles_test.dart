import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silsila_app/erp/screens/erp_operational_documents_screen.dart';
import 'package:silsila_app/erp/services/erp_operational_documents_repository.dart';

void main() {
  Future<void> pumpDocument(
    WidgetTester tester, {
    required ErpOperationalKind kind,
    String? documentType,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ErpOperationalDocumentsScreen(
              key: ValueKey('${kind.name}-${documentType ?? 'default'}'),
              kind: kind,
              initialDocumentType: documentType,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sales quotation, order, and invoice have distinct screen titles',
      (tester) async {
    await pumpDocument(
      tester,
      kind: ErpOperationalKind.sales,
      documentType: 'quotation',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('operational-document-title'))).data,
      'عرض سعر',
    );

    await pumpDocument(
      tester,
      kind: ErpOperationalKind.sales,
      documentType: 'order',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('operational-document-title'))).data,
      'أمر بيع',
    );

    await pumpDocument(
      tester,
      kind: ErpOperationalKind.sales,
      documentType: 'invoice',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('operational-document-title'))).data,
      'فاتورة بيع',
    );
  });

  testWidgets('purchase documents retain the purchase title', (tester) async {
    await pumpDocument(tester, kind: ErpOperationalKind.purchase);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('operational-document-title'))).data,
      'مستندات المشتريات',
    );
  });
}
