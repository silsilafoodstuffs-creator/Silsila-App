/// Inventory-control domain models for Silsila ERP.
///
/// These classes validate and format data locally only. They do not access
/// Supabase or post stock movements. Production writes must be authorized and
/// committed by a trusted backend after company/branch/warehouse validation.
enum ErpStockCountStatus {
  draft,
  counting,
  review,
  approved,
  posted,
  cancelled,
}

enum ErpExpiryStatus {
  expired,
  withinSevenDays,
  withinThirtyDays,
  valid,
}

class ErpStockCountLine {
  const ErpStockCountLine({
    required this.itemId,
    required this.itemName,
    required this.systemQuantity,
    this.countedQuantity,
    this.batchNumber,
    this.expiryDate,
    this.unitCost = 0,
    this.notes,
  });

  final String itemId;
  final String itemName;
  final double systemQuantity;
  final double? countedQuantity;
  final String? batchNumber;
  final DateTime? expiryDate;
  final double unitCost;
  final String? notes;

  double? get variance =>
      countedQuantity == null ? null : countedQuantity! - systemQuantity;

  double? get varianceValue =>
      variance == null ? null : variance! * unitCost;

  List<String> validate() {
    final errors = <String>[];
    if (itemId.trim().isEmpty) errors.add('معرّف الصنف مطلوب.');
    if (itemName.trim().isEmpty) errors.add('اسم الصنف مطلوب.');
    if (!systemQuantity.isFinite || systemQuantity < 0) {
      errors.add('كمية النظام يجب أن تكون رقمًا صالحًا وغير سالبة.');
    }
    if (countedQuantity != null &&
        (!countedQuantity!.isFinite || countedQuantity! < 0)) {
      errors.add('الكمية الفعلية يجب أن تكون رقمًا صالحًا وغير سالبة.');
    }
    if (!unitCost.isFinite || unitCost < 0) {
      errors.add('تكلفة الوحدة يجب أن تكون رقمًا صالحًا وغير سالبة.');
    }
    return errors;
  }

  Map<String, Object?> toJson() => {
        'item_id': itemId,
        'system_quantity': systemQuantity,
        'counted_quantity': countedQuantity,
        'batch_number': _trimOrNull(batchNumber),
        'expiry_date': expiryDate == null ? null : _dateOnly(expiryDate!),
        'unit_cost': unitCost,
        'notes': _trimOrNull(notes),
      };

  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class ErpReorderRule {
  const ErpReorderRule({
    required this.companyId,
    required this.warehouseId,
    required this.itemId,
    required this.minimumQuantity,
    required this.targetQuantity,
    required this.reorderQuantity,
    this.branchId,
    this.active = true,
  });

  final String companyId;
  final String? branchId;
  final String warehouseId;
  final String itemId;
  final double minimumQuantity;
  final double targetQuantity;
  final double reorderQuantity;
  final bool active;

  List<String> validate() {
    final errors = <String>[];
    if (companyId.trim().isEmpty) errors.add('الشركة مطلوبة.');
    if (warehouseId.trim().isEmpty) errors.add('المخزن مطلوب.');
    if (itemId.trim().isEmpty) errors.add('الصنف مطلوب.');
    for (final entry in <String, double>{
      'الحد الأدنى': minimumQuantity,
      'المستوى المستهدف': targetQuantity,
      'كمية إعادة الطلب': reorderQuantity,
    }.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        errors.add('${entry.key} يجب أن تكون رقمًا صالحًا وغير سالب.');
      }
    }
    if (targetQuantity.isFinite &&
        minimumQuantity.isFinite &&
        targetQuantity < minimumQuantity) {
      errors.add('المستوى المستهدف لا يمكن أن يقل عن الحد الأدنى.');
    }
    return errors;
  }

  bool needsReorder(double quantityOnHand) =>
      active &&
      quantityOnHand.isFinite &&
      quantityOnHand <= minimumQuantity;

  double suggestedOrder(double quantityOnHand) {
    if (!quantityOnHand.isFinite || quantityOnHand < 0) return 0;
    if (!needsReorder(quantityOnHand)) return 0;
    final toTarget = targetQuantity - quantityOnHand;
    return <double>[toTarget, reorderQuantity, 0]
        .reduce((a, b) => a > b ? a : b);
  }
}

class ErpInventoryExpiryAlert {
  const ErpInventoryExpiryAlert({
    required this.itemId,
    required this.itemName,
    required this.expiryDate,
    required this.quantityOnHand,
    this.batchNumber,
  });

  final String itemId;
  final String itemName;
  final DateTime expiryDate;
  final double quantityOnHand;
  final String? batchNumber;

  int daysUntilExpiry({DateTime? today}) {
    final now = today ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(date).inDays;
  }

  ErpExpiryStatus status({DateTime? today}) {
    final days = daysUntilExpiry(today: today);
    if (days < 0) return ErpExpiryStatus.expired;
    if (days <= 7) return ErpExpiryStatus.withinSevenDays;
    if (days <= 30) return ErpExpiryStatus.withinThirtyDays;
    return ErpExpiryStatus.valid;
  }

  bool get hasPositiveStock =>
      quantityOnHand.isFinite && quantityOnHand > 0;
}
