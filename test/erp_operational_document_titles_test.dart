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
          body: ErpOperationalDocumentsScreen(
            key: ValueKey('${kind.name}-${documentType ?? 'default'}'),
            kind: kind,
            initialDocumentType: documentType,
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
    expect(find.text('عرض سعر'), findsWidgets);

    await pumpDocument(
      tester,
      kind: ErpOperationalKind.sales,
      documentType: 'order',
    );
    expect(find.text('أمر بيع'), findsWidgets);

    await pumpDocument(
      tester,
      kind: ErpOperationalKind.sales,
      documentType: 'invoice',
    );
    expect(find.text('فاتورة بيع'), findsWidgets);
  });

  testWidgets('purchase documents retain the purchase title', (tester) async {
    await pumpDocument(tester, kind: ErpOperationalKind.purchase);
    expect(find.text('مستندات المشتريات'), findsWidgets);
  });
}
