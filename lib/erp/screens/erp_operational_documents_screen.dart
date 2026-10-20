import 'package:flutter/material.dart';
import '../services/erp_operational_documents_repository.dart';
import '../services/erp_operational_accounting_repository.dart';
import 'erp_operational_account_mappings_screen.dart';

class ErpOperationalDocumentsScreen extends StatefulWidget {
  const ErpOperationalDocumentsScreen({
    super.key,
    this.initialCompanyId,
    this.kind = ErpOperationalKind.purchase,
    this.initialDocumentType,
    this.initialDocumentId,
  });
  final String? initialCompanyId;
  final ErpOperationalKind kind;
  final String? initialDocumentType;
  final String? initialDocumentId;

  @override
  State<ErpOperationalDocumentsScreen> createState() => _ErpOperationalDocumentsScreenState();
}

class _ErpOperationalDocumentsScreenState extends State<ErpOperationalDocumentsScreen> {
  final _repo = ErpOperationalDocumentsRepository();
  final _accountingRepo = ErpOperationalAccountingRepository();
  final _company = TextEditingController();
  final _documentNumber = TextEditingController();
  final _notes = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _tax = TextEditingController(text: '0');
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _lines = [];
  String? _partyId;
  String? _warehouseId;
  String? _itemId;
  String? _selectedDocumentId;
  String _documentType = 'invoice';
  bool _saving = false;
  bool _loading = false;
  String? _error;
  String? _message;

  String get _title => widget.kind == ErpOperationalKind.purchase ? 'مستندات المشتريات' : 'مستندات المبيعات';
  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _documentType = widget.initialDocumentType ?? 'invoice';
    _selectedDocumentId = widget.initialDocumentId;
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    if (widget.initialDocumentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _load(clearMessage: false);
        if (mounted && _selectedDocumentId != null) {
          final selected = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
          if (selected.isNotEmpty) setState(() => _documentType = _s(selected.first['document_type']));
          await _loadLines(_selectedDocumentId!);
        }
      });
    }
  }
  @override
  void dispose() {
    _company.dispose(); _documentNumber.dispose(); _notes.dispose(); _quantity.dispose();
    _unitPrice.dispose(); _discount.dispose(); _tax.dispose(); super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);

  Future<void> _load({bool clearMessage = true}) async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة أولًا.');
      return;
    }
    setState(() { _loading = true; _error = null; if (clearMessage) _message = null; });
    try {
      final results = await Future.wait([
        _repo.fetchDocuments(companyId: _company.text, kind: widget.kind),
        _repo.fetchParties(_company.text, widget.kind),
        _repo.fetchWarehouses(_company.text),
        _repo.fetchItems(_company.text),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0]; _parties = results[1]; _warehouses = results[2]; _items = results[3];
        if (!_parties.any((r) => _s(r['id']) == _partyId)) _partyId = _parties.isEmpty ? null : _s(_parties.first['id']);
        if (!_warehouses.any((r) => _s(r['id']) == _warehouseId)) _warehouseId = _warehouses.isEmpty ? null : _s(_warehouses.first['id']);
        if (!_items.any((r) => _s(r['id']) == _itemId)) _itemId = _items.isEmpty ? null : _s(_items.first['id']);
        if (_selectedDocumentId != null && !_rows.any((r) => _s(r['id']) == _selectedDocumentId)) _selectedDocumentId = null;
        if (_selectedDocumentId != null) {
          final current = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
          if (current.isNotEmpty) {
            _partyId = _s(widget.kind == ErpOperationalKind.purchase ? current.first['supplier_id'] : current.first['customer_id']);
            _warehouseId = _s(current.first['warehouse_id']);
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل المستندات: $e'; });
    }
  }


  String _partyLabel(String? id) {
    final matches = _parties.where((r) => _s(r['id']) == id);
    return matches.isEmpty ? 'اختر الطرف' : _s(matches.first['party_code']) + ' — ' + _s(matches.first['party_name']);
  }
  String _warehouseLabel(String? id) {
    final matches = _warehouses.where((r) => _s(r['id']) == id);
    return matches.isEmpty ? 'اختر المخزن' : _s(matches.first['warehouse_code']) + ' — ' + _s(matches.first['warehouse_name']);
  }
  String _itemLabel(String? id) {
    final matches = _items.where((r) => _s(r['id']) == id);
    return matches.isEmpty ? 'اختر الصنف' : _s(matches.first['item_code']) + ' — ' + _s(matches.first['item_name']);
  }

  Future<void> _createDraft() async {
    if (_partyId == null || _warehouseId == null || _documentNumber.text.trim().isEmpty) {
      setState(() => _error = 'أكمل رقم المستند والطرف والمخزن.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final id = await _repo.createDraft(
        companyId: _company.text, kind: widget.kind, documentNumber: _documentNumber.text,
        documentType: _documentType, partyId: _partyId!, warehouseId: _warehouseId!, notes: _notes.text,
      );
      if (!mounted) return;
      _documentNumber.clear(); _notes.clear();
      setState(() { _saving = false; _selectedDocumentId = id; _lines = []; _message = 'تم إنشاء مسودة المستند. أضف البنود ثم رحّلها.'; });
      await _load(clearMessage: false);
      if (mounted) setState(() => _selectedDocumentId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر إنشاء المسودة: $e'; });
    }
  }

  Future<void> _applyPriceList() async {
    final quantity = double.tryParse(_quantity.text.trim()) ?? 0;
    final selected = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
    final partyId = selected.isNotEmpty
      ? _s(widget.kind == ErpOperationalKind.purchase ? selected.first['supplier_id'] : selected.first['customer_id'])
      : (_partyId ?? '');
    if (_itemId == null || partyId.isEmpty || quantity <= 0) {
      setState(() => _error = 'اختر مستندًا وطرفًا وصنفًا، وأدخل كمية صحيحة قبل جلب السعر.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final price = await _repo.resolvePrice(
        companyId: _company.text,
        itemId: _itemId!,
        kind: widget.kind == ErpOperationalKind.purchase ? 'purchase' : 'sale',
        quantity: quantity,
        partyId: partyId,
      );
      if (!mounted) return;
      if (price == null) {
        setState(() { _saving = false; _error = 'لم ترجع قاعدة البيانات سعرًا للصنف المحدد.'; });
        return;
      }
      final unit = _n(price['base_unit_price']);
      final percent = _n(price['discount_percent']);
      final amountDiscount = quantity * unit * percent / 100;
      setState(() {
        _unitPrice.text = unit.toStringAsFixed(4);
        _discount.text = amountDiscount.toStringAsFixed(2);
        _saving = false;
        _message = 'تم تطبيق سعر الوحدة والخصم من ' + _s(price['price_source']) +
          (_s(price['price_list_name']).isEmpty ? '' : ' • ' + _s(price['price_list_name']));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر جلب سعر القائمة: $e'; });
    }
  }

  Future<void> _openItemPicker() async {
    final selectedDoc = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
    if (selectedDoc.isEmpty || _s(selectedDoc.first['status']) != 'draft') {
      setState(() => _error = 'أنشئ مسودة أو اختر مستندًا بحالة مسودة أولًا.');
      return;
    }
    if (_warehouseId == null || _partyId == null || _items.isEmpty) {
      setState(() => _error = 'حمّل بيانات الشركة واختر العميل والمخزن قبل اختيار الأصناف.');
      return;
    }

    setState(() { _loading = true; _error = null; _message = null; });
    List<Map<String, dynamic>> unitRows = [];
    List<Map<String, dynamic>> balanceRows = [];
    List<Map<String, dynamic>> reservationRows = [];
    try {
      try {
        unitRows = await _repo.fetchUnits(
          companyId: _company.text.trim(),
          itemIds: _items.map((item) => _s(item['id'])).where((id) => id.isNotEmpty).toList(),
        );
      } catch (_) {
        // Older installations may not have optional packaging units configured yet.
        unitRows = [];
      }
      balanceRows = await _repo.fetchWarehouseBalances(
        companyId: _company.text.trim(), warehouseId: _warehouseId!,
      );
      reservationRows = await _repo.fetchActiveReservations(
        companyId: _company.text.trim(), warehouseId: _warehouseId!,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل أرصدة المخزن والحجوزات. طبّق ترحيل الوحدات والحجوزات قبل استخدام اختيار الأصناف: $error';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    final unitsByItem = <String, List<Map<String, dynamic>>>{};
    for (final unit in unitRows) {
      unitsByItem.putIfAbsent(_s(unit['item_id']), () => []).add(unit);
    }
    final actual = <String, double>{};
    final reserved = <String, double>{};
    for (final row in balanceRows) {
      final id = _s(row['item_id']);
      actual[id] = (actual[id] ?? 0) + _n(row['quantity_on_hand']);
    }
    for (final row in reservationRows) {
      final id = _s(row['item_id']);
      reserved[id] = (reserved[id] ?? 0) + _n(row['quantity_base']);
    }

    final quantities = <String, TextEditingController>{};
    final selectedUnits = <String, String>{};
    final search = TextEditingController();
    for (final item in _items) {
      final id = _s(item['id']);
      quantities[id] = TextEditingController();
      final options = unitsByItem[id] ?? [];
      final base = options.where((unit) => unit['is_base_unit'] == true);
      selectedUnits[id] = base.isNotEmpty ? _s(base.first['id']) : (options.isNotEmpty ? _s(options.first['id']) : '');
    }

    List<Map<String, dynamic>>? picked;
    try {
      picked = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) {
          final query = search.text.trim().toLowerCase();
          final visibleItems = _items.where((item) {
            final haystack = '${_s(item['item_code'])} ${_s(item['item_name'])} ${_s(item['barcode'])}'.toLowerCase();
            return query.isEmpty || haystack.contains(query);
          }).toList();
          final selectedItems = _items.where((item) {
            final quantity = double.tryParse(quantities[_s(item['id'])]!.text.trim()) ?? 0;
            return quantity > 0;
          }).toList();

          List<Map<String, dynamic>> optionsFor(Map<String, dynamic> item) {
            final options = unitsByItem[_s(item['id'])] ?? [];
            if (options.isNotEmpty) return options;
            final base = _s(item['base_unit']).isEmpty ? 'وحدة' : _s(item['base_unit']);
            return [{'id': '', 'unit_code': base, 'unit_name': base, 'conversion_factor': 1, 'is_base_unit': true}];
          }

          return AlertDialog(
            title: Row(children: [
              const Expanded(child: Text('اختيار الأصناف — F11', style: TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900))),
              Chip(label: Text('${selectedItems.length} صنف')),
            ]),
            content: SizedBox(
              width: 1240,
              height: 650,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: search,
                  autofocus: true,
                  onChanged: (_) => refresh(() {}),
                  decoration: const InputDecoration(
                    labelText: 'بحث بكود الصنف أو الاسم أو الباركود',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  color: const Color(0xFFF2EAFB),
                  child: const Row(children: [
                    SizedBox(width: 95, child: Text('الكود', style: TextStyle(fontWeight: FontWeight.w900))),
                    SizedBox(width: 190, child: Text('اسم الصنف', style: TextStyle(fontWeight: FontWeight.w900))),
                    SizedBox(width: 85, child: Text('سعر أساسي', style: TextStyle(fontWeight: FontWeight.w900))),
                    SizedBox(width: 85, child: Text('فعلي', style: TextStyle(fontWeight: FontWeight.w900))),
                    SizedBox(width: 85, child: Text('محجوز', style: TextStyle(fontWeight: FontWeight.w900))),
                    SizedBox(width: 85, child: Text('متاح', style: TextStyle(fontWeight: FontWeight.w900))),
                    SizedBox(width: 190, child: Text('الوحدة', style: TextStyle(fontWeight: FontWeight.w900))),
                    SizedBox(width: 110, child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.w900))),
                  ]),
                ),
                const SizedBox(height: 4),
                Expanded(child: SingleChildScrollView(
                  child: Column(children: visibleItems.map((item) {
                    final id = _s(item['id']);
                    final options = optionsFor(item);
                    final selectedUnitId = selectedUnits[id] ?? '';
                    final selectedUnit = options.firstWhere(
                      (unit) => _s(unit['id']) == selectedUnitId,
                      orElse: () => options.first,
                    );
                    final factor = _n(selectedUnit['conversion_factor']) <= 0 ? 1.0 : _n(selectedUnit['conversion_factor']);
                    final onHand = actual[id] ?? 0;
                    final held = reserved[id] ?? 0;
                    final available = onHand - held;
                    final price = widget.kind == ErpOperationalKind.purchase
                        ? _n(item['purchase_price']) : _n(item['sale_price']);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (quantities[id]!.text.trim().isNotEmpty ? const Color(0xFFFFF3DB) : Colors.white),
                        border: const Border(bottom: BorderSide(color: Color(0xFFE9E2EF))),
                      ),
                      child: Row(children: [
                        SizedBox(width: 95, child: Text(_s(item['item_code']), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 190, child: Text(_s(item['item_name']), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 85, child: Text(_money(price))),
                        SizedBox(width: 85, child: Text(_money(onHand))),
                        SizedBox(width: 85, child: Text(_money(held), style: const TextStyle(color: Color(0xFFB56B00)))),
                        SizedBox(width: 85, child: Text(_money(available), style: TextStyle(color: available < 0 ? Colors.red : const Color(0xFF3E007D), fontWeight: FontWeight.w800))),
                        SizedBox(width: 190, child: DropdownButtonFormField<String>(
                          value: selectedUnitId,
                          isDense: true,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7)),
                          items: options.map((unit) => DropdownMenuItem<String>(
                            value: _s(unit['id']),
                            child: Text(_s(unit['unit_name']).isEmpty ? _s(unit['unit_code']) : _s(unit['unit_name']), overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (value) => refresh(() => selectedUnits[id] = value ?? ''),
                        )),
                        const SizedBox(width: 8),
                        SizedBox(width: 102, child: TextField(
                          controller: quantities[id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => refresh(() {}),
                          decoration: const InputDecoration(hintText: '0', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                        )),
                        const SizedBox(width: 8),
                        SizedBox(width: 95, child: Text('× ${_money(factor)}', style: const TextStyle(color: Colors.black54, fontSize: 11))),
                      ]),
                    );
                  }).toList()),
                )),
                const SizedBox(height: 8),
                const Text('معاينة البنود المحددة', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3E007D))),
                const SizedBox(height: 4),
                Container(
                  height: 115,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFF8F5FC), borderRadius: BorderRadius.circular(8)),
                  child: selectedItems.isEmpty
                      ? const Center(child: Text('اكتب كمية بجوار الصنف لإضافته إلى المعاينة.'))
                      : ListView(children: selectedItems.map((item) {
                          final id = _s(item['id']);
                          final qty = double.tryParse(quantities[id]!.text.trim()) ?? 0;
                          final options = optionsFor(item);
                          final unitId = selectedUnits[id] ?? '';
                          final unit = options.firstWhere((row) => _s(row['id']) == unitId, orElse: () => options.first);
                          return ListTile(
                            dense: true,
                            title: Text('${_s(item['item_code'])} — ${_s(item['item_name'])}'),
                            subtitle: Text('الكمية: ${_money(qty)} ${_s(unit['unit_name']).isEmpty ? _s(unit['unit_code']) : _s(unit['unit_name'])} • الأساسي: ${_money(widget.kind == ErpOperationalKind.purchase ? item['purchase_price'] : item['sale_price'])}'),
                            trailing: IconButton(tooltip: 'إزالة من المعاينة', onPressed: () { quantities[id]!.clear(); refresh(() {}); }, icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
                          );
                        }).toList()),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton.icon(
                onPressed: selectedItems.isEmpty ? null : () {
                  final result = <Map<String, dynamic>>[];
                  for (final item in selectedItems) {
                    final id = _s(item['id']);
                    final qty = double.tryParse(quantities[id]!.text.trim()) ?? 0;
                    final options = optionsFor(item);
                    final unitId = selectedUnits[id] ?? '';
                    final unit = options.firstWhere((row) => _s(row['id']) == unitId, orElse: () => options.first);
                    final factor = _n(unit['conversion_factor']) <= 0 ? 1.0 : _n(unit['conversion_factor']);
                    final basePrice = widget.kind == ErpOperationalKind.purchase ? _n(item['purchase_price']) : _n(item['sale_price']);
                    result.add({
                      'item_id': id,
                      'quantity': qty,
                      'unit_id': unitId,
                      'unit_name': _s(unit['unit_name']).isEmpty ? _s(unit['unit_code']) : _s(unit['unit_name']),
                      'conversion_factor': factor,
                      'unit_price': basePrice * factor,
                      'discount': 0.0,
                      'tax': 0.0,
                    });
                  }
                  Navigator.pop(dialogContext, result);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('موافق وإضافة البنود'),
              ),
            ],
          );
        }),
      );
    } finally {
      search.dispose();
      for (final controller in quantities.values) {
        controller.dispose();
      }
    }

    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final count = await _repo.addLinesAtomically(
        documentId: _selectedDocumentId!,
        kind: widget.kind,
        lines: picked.map((line) => <String, Object?>{
          'item_id': line['item_id'],
          'quantity': line['quantity'],
          'unit_id': line['unit_id'],
          'unit_price': line['unit_price'],
          'discount': line['discount'],
          'tax': line['tax'],
        }).toList(),
      );
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تمت إضافة $count بندًا وحفظ الحجوزات المرتبطة بها في معاملة واحدة.'; });
      await _load(clearMessage: false);
      if (mounted && _selectedDocumentId != null) await _loadLines(_selectedDocumentId!);
    } catch (error) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'لم تُحفظ البنود المحددة؛ ألغت قاعدة البيانات العملية كاملة عند فشل التحقق أو الحجز: $error'; });
    }
  }

  Future<void> _addLine() async {
    final selected = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
    if (selected.isEmpty || _s(selected.first['status']) != 'draft') {
      setState(() => _error = 'اختر مستندًا بحالة مسودة لإضافة بند.');
      return;
    }
    final quantity = double.tryParse(_quantity.text.trim()) ?? -1;
    final price = double.tryParse(_unitPrice.text.trim()) ?? -1;
    final discount = double.tryParse(_discount.text.trim()) ?? -1;
    final tax = double.tryParse(_tax.text.trim()) ?? -1;
    if (_itemId == null) { setState(() => _error = 'اختر الصنف.'); return; }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.addLine(documentId: _selectedDocumentId!, kind: widget.kind,
        itemId: _itemId!, quantity: quantity, unitPrice: price, discount: discount, tax: tax);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تمت إضافة البند وتحديث إجمالي المستند.'; });
      await _load(clearMessage: false);
      if (mounted && _selectedDocumentId != null) await _loadLines(_selectedDocumentId!);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة البند: $e'; });
    }
  }

  Future<void> _loadLines(String documentId) async {
    try {
      final rows = await _repo.fetchLines(documentId, widget.kind);
      if (mounted) setState(() => _lines = rows);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل بنود المستند: $e');
    }
  }

  Future<void> _postAccounting(Map<String, dynamic> row) async {
    final number = _s(row['document_number']);
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ترحيل الأثر المحاسبي'),
      content: Text('سيُنشأ قيد يومية مرتبط بالمستند $number اعتمادًا على خريطة الحسابات التشغيلية وتكلفة حركات المخزون. يمكن تكرار الطلب بأمان بعد نجاحه.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء القيد')),
      ],
    ));
    if (yes != true || !mounted) return;
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final id = await _accountingRepo.postDocumentAccounting(
        _s(row['id']), widget.kind == ErpOperationalKind.purchase ? 'purchase' : 'sales',
      );
      if (!mounted) return;
      setState(() { _loading = false; _message = 'تم إنشاء/تأكيد القيد المحاسبي للمستند $number. رقم معرّف القيد: $id'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر ترحيل الأثر المحاسبي: $e'; });
    }
  }

  Future<void> _post(Map<String, dynamic> row) async {
    final number = _s(row['document_number']);
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الترحيل'),
      content: Text('سيتم ترحيل المستند $number وإنشاء حركات مخزنية فعلية. لا يمكن إعادة ترحيله بعد نجاح العملية.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ترحيل')),
      ],
    ));
    if (yes != true || !mounted) return;
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      await _repo.postDocument(_s(row['id']), widget.kind);
      if (!mounted) return;
      setState(() { _loading = false; _message = 'تم ترحيل المستند $number وتسجيل حركات المخزون.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر ترحيل المستند: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftCount = _rows.where((r) => _s(r['status']) == 'draft').length;
    return Directionality(textDirection: TextDirection.rtl, child: Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
          _openItemPicker();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_title, style: const TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('عرض المستندات المسجلة وترحيل المستندات المؤهلة إلى دفتر المخزون من خلال معاملة خادمية واحدة.',
          style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 12),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل المستندات'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ErpOperationalAccountMappingsScreen(initialCompanyId: _company.text.trim()),
            )),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('خريطة الحسابات'),
          )),
        ]),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),

        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إنشاء مستند جديد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 8),
            TextField(controller: _documentNumber, decoration: const InputDecoration(labelText: 'المسلسل اليدوي للمستند *', border: OutlineInputBorder())),
            const SizedBox(height: 4),
            const Text('المسلسل التلقائي والتاريخ والوقت الدقيق يُسجّلان من قاعدة البيانات عند الحفظ.', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _documentType, isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع المستند', border: OutlineInputBorder()),
              items: (widget.kind == ErpOperationalKind.purchase
                ? const <String, String>{'order':'طلب شراء','receipt':'استلام مشتريات','invoice':'فاتورة مشتريات','return':'مرتجع مشتريات'}
                : const <String, String>{'quotation':'عرض سعر','order':'أمر بيع','delivery':'إذن تحميل','invoice':'فاتورة مبيعات','return':'مرتجع مبيعات'})
                .entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _documentType = v ?? _documentType),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _partyId, isExpanded: true,
              decoration: InputDecoration(labelText: widget.kind == ErpOperationalKind.purchase ? 'المورد' : 'العميل', border: const OutlineInputBorder()),
              items: _parties.map((r) => DropdownMenuItem<String>(value: _s(r['id']), child: Text(_partyLabel(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _partyId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _warehouseId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'المخزن', border: OutlineInputBorder()),
              items: _warehouses.map((r) => DropdownMenuItem<String>(value: _s(r['id']), child: Text(_warehouseLabel(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _warehouseId = v),
            ),
            const SizedBox(height: 8),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _saving ? null : _createDraft, icon: const Icon(Icons.add), label: const Text('إنشاء المسودة')),
          ],
        ))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          _metric('المستندات', '${_rows.length}'),
          _metric('جاهز للترحيل', '$draftCount'),
          _metric('مرحّل', '${_rows.where((r) => _s(r['status']) == 'posted').length}'),
        ]),
        const SizedBox(height: 10),
        if (_rows.isEmpty && !_loading) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد مستندات للعرض؛ لم تُضف بيانات تجريبية.')),

        if (_selectedDocumentId != null && _rows.any((r) => _s(r['id']) == _selectedDocumentId && _s(r['status']) == 'draft'))
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة بند للمستند المحدد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _saving || _loading ? null : _openItemPicker,
                icon: const Icon(Icons.search_rounded),
                label: const Text('اختيار عدة أصناف — F11'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _itemId, isExpanded: true,
                decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
                items: _items.map((r) => DropdownMenuItem<String>(value: _s(r['id']), child: Text(_itemLabel(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _itemId = v),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _unitPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: widget.kind == ErpOperationalKind.purchase ? 'سعر الشراء' : 'سعر البيع', border: const OutlineInputBorder()))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الخصم', border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _tax, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الضريبة', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _saving ? null : _applyPriceList, icon: const Icon(Icons.price_check_outlined), label: const Text('جلب سعر القائمة للطرف والكمية')),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: _saving ? null : _addLine, icon: const Icon(Icons.playlist_add), label: const Text('إضافة البند')),
            ],
          ))),
        if (_selectedDocumentId != null && _lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('بنود المستند المحدد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ..._lines.map((line) => Card(child: ListTile(
            title: Text(_itemLabel(_s(line['item_id']))),
            subtitle: Text('الكمية: ' + _s(line['quantity']) + ' • السعر: ' + _money(line['unit_price']) +
              ' • خصم: ' + _money(line['discount_amount']) + ' • ضريبة: ' + _money(line['tax_amount'])),
            isThreeLine: false,
            trailing: Text(_money(line['line_total']) + ' ج.م', style: const TextStyle(fontWeight: FontWeight.w900)),
          ))),
        ],
        ..._rows.map((r) {
          final status = _s(r['status']);
          final type = _s(r['document_type']);
          final eligibleType = widget.kind == ErpOperationalKind.purchase
              ? ['receipt','invoice','return'].contains(type)
              : ['delivery','invoice','return'].contains(type);
          final canPost = status == 'draft' && eligibleType;
          final date = _s(r['document_date']);
          return Card(color: _s(r['id']) == _selectedDocumentId ? const Color(0xFFF0E8FA) : null, child: InkWell(onTap: () async { setState(() { _selectedDocumentId = _s(r['id']); _lines = []; _documentType = _s(r['document_type']); _partyId = _s(widget.kind == ErpOperationalKind.purchase ? r['supplier_id'] : r['customer_id']); _warehouseId = _s(r['warehouse_id']); }); await _loadLines(_s(r['id'])); }, child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.description_outlined, color: Color(0xFF3E007D)),
                const SizedBox(width: 8),
                Expanded(child: Text('مستند رقم ${_s(r['document_number'])}', style: const TextStyle(fontWeight: FontWeight.w900))),
                Chip(label: Text(status)),
              ]),
              const SizedBox(height: 4),
              Text('النوع: $type • التاريخ: $date'),
              const SizedBox(height: 4),
              Text('الإجمالي: ${_money(r['grand_total'])} ج.م • المدفوع: ${_money(r['paid_total'])} ج.م'),
              if (_s(r['notes']).isNotEmpty) Text('ملاحظات: ${_s(r['notes'])}'),
              if (!canPost && status == 'draft') const Padding(padding: EdgeInsets.only(top: 6), child: Text('هذا النوع لا ينشئ حركة مخزنية مباشرة، لذلك لا يظهر له زر الترحيل هنا.', style: TextStyle(color: Colors.black54, fontSize: 12))),
              if (canPost) Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
                onPressed: _loading ? null : () => _post(r),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('ترحيل وتسجيل حركة المخزون'),
              )),
              if (status == 'posted' && eligibleType) Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _postAccounting(r),
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('إنشاء / مراجعة القيد المحاسبي'),
              )),
            ],
          ))));
        }),
      ],
    )));
  }

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF7F5FA), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      Text(value, style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900, fontSize: 18)),
    ]),
  );
}
