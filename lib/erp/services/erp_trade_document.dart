/// Draft purchase/sales document calculations for Silsila ERP.
/// This is a local domain model only; it does not save, approve, post, or
/// change stock/financial balances. Those operations require a trusted backend.
enum ErpTradeDocumentKind { purchase, sale }

enum ErpTradeDocumentStatus { draft, approved, posted, cancelled }

class ErpTradeDocumentLine {
  const ErpTradeDocumentLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.batchNumber,
    this.expiryDate,
  });

  final String itemId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double taxAmount;
  final String? batchNumber;
  final DateTime? expiryDate;

  double get grossAmount => quantity * unitPrice;
  double get total => grossAmount - discountAmount + taxAmount;

  List<String> validate() {
    final errors = <String>[];
    if (itemId.trim().isEmpty) errors.add('الصنف مطلوب.');
    if (itemName.trim().isEmpty) errors.add('اسم الصنف مطلوب.');
    if (!quantity.isFinite || quantity <= 0) {
      errors.add('الكمية يجب أن تكون أكبر من صفر.');
    }
    if (!unitPrice.isFinite || unitPrice < 0) {
      errors.add('سعر الوحدة غير صالح.');
    }
    if (!discountAmount.isFinite || discountAmount < 0) {
      errors.add('الخصم غير صالح.');
    }
    if (!taxAmount.isFinite || taxAmount < 0) {
      errors.add('الضريبة غير صالحة.');
    }
    if (grossAmount.isFinite && discountAmount > grossAmount) {
      errors.add('الخصم لا يمكن أن يتجاوز إجمالي السطر.');
    }
    return errors;
  }

  Map<String, Object?> toJson() => {
        'item_id': itemId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'line_total': total,
        'batch_number': _clean(batchNumber),
        'expiry_date': expiryDate == null ? null : _dateOnly(expiryDate!),
      };

  static String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class ErpTradeDocumentDraft {
  ErpTradeDocumentDraft({
    required this.kind,
    required this.companyId,
    required this.documentNumber,
    required this.partyId,
    required this.warehouseId,
    required List<ErpTradeDocumentLine> lines,
    this.branchId,
    this.documentDate,
    this.dueDate,
    this.discountTotal = 0,
    this.taxTotal = 0,
    this.paidTotal = 0,
    this.notes,
    this.status = ErpTradeDocumentStatus.draft,
  }) : lines = List.unmodifiable(lines);

  final ErpTradeDocumentKind kind;
  final String companyId;
  final String documentNumber;
  final String partyId;
  final String warehouseId;
  final String? branchId;
  final DateTime? documentDate;
  final DateTime? dueDate;
  final List<ErpTradeDocumentLine> lines;
  final double discountTotal;
  final double taxTotal;
  final double paidTotal;
  final String? notes;
  final ErpTradeDocumentStatus status;

  double get subtotal => lines.fold<double>(0, (sum, line) => sum + line.grossAmount);
  double get lineDiscountTotal =>
      lines.fold<double>(0, (sum, line) => sum + line.discountAmount);
  double get lineTaxTotal =>
      lines.fold<double>(0, (sum, line) => sum + line.taxAmount);
  double get grandTotal =>
      subtotal - lineDiscountTotal - discountTotal + lineTaxTotal + taxTotal;
  double get remainingAmount => grandTotal - paidTotal;

  List<String> validate() {
    final errors = <String>[];
    if (companyId.trim().isEmpty) errors.add('الشركة مطلوبة.');
    if (documentNumber.trim().isEmpty) errors.add('رقم المستند مطلوب.');
    if (partyId.trim().isEmpty) {
      errors.add(kind == ErpTradeDocumentKind.purchase
          ? 'المورد مطلوب.'
          : 'العميل مطلوب.');
    }
    if (warehouseId.trim().isEmpty) errors.add('المخزن مطلوب.');
    if (lines.isEmpty) errors.add('أضف صنفًا واحدًا على الأقل.');
    for (var i = 0; i < lines.length; i++) {
      errors.addAll(lines[i].validate().map((e) => 'السطر ${i + 1}: $e'));
    }
    if (!discountTotal.isFinite || discountTotal < 0) {
      errors.add('خصم المستند غير صالح.');
    }
    if (!taxTotal.isFinite || taxTotal < 0) {
      errors.add('ضريبة المستند غير صالحة.');
    }
    if (!paidTotal.isFinite || paidTotal < 0) {
      errors.add('المبلغ المدفوع غير صالح.');
    }
    if (grandTotal.isFinite && discountTotal > subtotal - lineDiscountTotal) {
      errors.add('خصم المستند يتجاوز قيمة الأصناف بعد خصومات السطور.');
    }
    if (grandTotal.isFinite && paidTotal > grandTotal) {
      errors.add('المبلغ المدفوع لا يمكن أن يتجاوز إجمالي المستند.');
    }
    if (documentDate != null &&
        dueDate != null &&
        dueDate!.isBefore(documentDate!)) {
      errors.add('تاريخ الاستحقاق لا يمكن أن يسبق تاريخ المستند.');
    }
    return errors;
  }

  Map<String, Object?> toHeaderJson() => {
        'company_id': companyId,
        'branch_id': branchId,
        'warehouse_id': warehouseId,
        if (kind == ErpTradeDocumentKind.purchase) 'supplier_id': partyId,
        if (kind == ErpTradeDocumentKind.sale) 'customer_id': partyId,
        'document_number': documentNumber,
        'document_date': documentDate == null ? null : _dateOnly(documentDate!),
        'due_date': dueDate == null ? null : _dateOnly(dueDate!),
        'status': status.name,
        'subtotal': subtotal,
        'discount_total': discountTotal + lineDiscountTotal,
        'tax_total': taxTotal + lineTaxTotal,
        'grand_total': grandTotal,
        'paid_total': paidTotal,
        'notes': _clean(notes),
      };

  static String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
