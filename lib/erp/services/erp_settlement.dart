/// Local draft model for Silsila ERP receipts and payments.
/// No database writes or accounting postings are performed by this model.
enum ErpSettlementKind {
  customerReceipt,
  supplierPayment,
  customerRefund,
  supplierRefund,
  otherReceipt,
  otherPayment,
}

enum ErpPaymentMethod { cash, bankTransfer, cheque, wallet, card, other }

enum ErpSettlementStatus { draft, approved, posted, cancelled }

class ErpSettlementAllocation {
  const ErpSettlementAllocation({
    required this.documentKind,
    required this.documentId,
    required this.amount,
    this.notes,
  });

  final String documentKind;
  final String documentId;
  final double amount;
  final String? notes;

  List<String> validate() {
    final errors = <String>[];
    if (!const ['purchase', 'sale'].contains(documentKind)) {
      errors.add('نوع المستند يجب أن يكون شراء أو بيع.');
    }
    if (documentId.trim().isEmpty) errors.add('معرّف المستند مطلوب.');
    if (!amount.isFinite || amount <= 0) {
      errors.add('قيمة التخصيص يجب أن تكون أكبر من صفر.');
    }
    return errors;
  }

  Map<String, Object?> toJson() => {
        'document_kind': documentKind,
        'document_id': documentId,
        'allocated_amount': amount,
        'notes': _clean(notes),
      };

  static String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}

class ErpSettlementDraft {
  ErpSettlementDraft({
    required this.companyId,
    required this.partyId,
    required this.cashboxId,
    required this.settlementNumber,
    required this.kind,
    required this.paymentMethod,
    required this.amount,
    required List<ErpSettlementAllocation> allocations,
    this.branchId,
    this.date,
    this.externalReference,
    this.notes,
    this.status = ErpSettlementStatus.draft,
  }) : allocations = List.unmodifiable(allocations);

  final String companyId;
  final String? branchId;
  final String partyId;
  final String cashboxId;
  final String settlementNumber;
  final ErpSettlementKind kind;
  final ErpPaymentMethod paymentMethod;
  final double amount;
  final List<ErpSettlementAllocation> allocations;
  final DateTime? date;
  final String? externalReference;
  final String? notes;
  final ErpSettlementStatus status;

  double get allocatedAmount =>
      allocations.fold<double>(0, (sum, item) => sum + item.amount);
  double get unallocatedAmount => amount - allocatedAmount;

  List<String> validate() {
    final errors = <String>[];
    if (companyId.trim().isEmpty) errors.add('الشركة مطلوبة.');
    if (partyId.trim().isEmpty) errors.add('المورد أو العميل مطلوب.');
    if (cashboxId.trim().isEmpty) errors.add('الخزينة أو الحساب البنكي مطلوب.');
    if (settlementNumber.trim().isEmpty) errors.add('رقم السند مطلوب.');
    if (!amount.isFinite || amount <= 0) errors.add('قيمة السند غير صالحة.');
    for (var i = 0; i < allocations.length; i++) {
      errors.addAll(
        allocations[i].validate().map((e) => 'التخصيص ${i + 1}: $e'),
      );
    }
    if (allocatedAmount.isFinite && amount.isFinite && allocatedAmount > amount) {
      errors.add('إجمالي التخصيصات يتجاوز قيمة السند.');
    }
    return errors;
  }

  Map<String, Object?> toJson() => {
        'company_id': companyId,
        'branch_id': branchId,
        'party_id': partyId,
        'cashbox_id': cashboxId,
        'settlement_number': settlementNumber,
        'settlement_date': _dateOnly(date ?? DateTime.now()),
        'settlement_kind': _kindValue(kind),
        'payment_method': _methodValue(paymentMethod),
        'status': status.name,
        'amount': amount,
        'external_reference': _clean(externalReference),
        'notes': _clean(notes),
      };

  static String _kindValue(ErpSettlementKind value) {
    switch (value) {
      case ErpSettlementKind.customerReceipt:
        return 'customer_receipt';
      case ErpSettlementKind.supplierPayment:
        return 'supplier_payment';
      case ErpSettlementKind.customerRefund:
        return 'customer_refund';
      case ErpSettlementKind.supplierRefund:
        return 'supplier_refund';
      case ErpSettlementKind.otherReceipt:
        return 'other_receipt';
      case ErpSettlementKind.otherPayment:
        return 'other_payment';
    }
  }

  static String _methodValue(ErpPaymentMethod value) {
    switch (value) {
      case ErpPaymentMethod.cash:
        return 'cash';
      case ErpPaymentMethod.bankTransfer:
        return 'bank_transfer';
      case ErpPaymentMethod.cheque:
        return 'cheque';
      case ErpPaymentMethod.wallet:
        return 'wallet';
      case ErpPaymentMethod.card:
        return 'card';
      case ErpPaymentMethod.other:
        return 'other';
    }
  }

  static String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
