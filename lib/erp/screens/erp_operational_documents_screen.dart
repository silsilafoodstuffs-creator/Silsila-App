import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _partyCode = TextEditingController();
  final _notes = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _tax = TextEditingController(text: '0');
  final _invoiceDiscountAmount = TextEditingController(text: '0');
  final _invoiceDiscountPercent = TextEditingController(text: '0');
  DateTime _documentDate = DateTime.now();
  bool _isTaxInvoice = false;
  List<Map<String, dynamic>> _representatives = [];
  String? _salesRepId;
  bool _canChangeSalesRep = false;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _allWarehouses = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _lines = [];
  // Rows chosen in the item picker remain a local invoice preview until the user confirms saving them.
  List<Map<String, dynamic>> _pendingLines = [];
  Map<String, List<Map<String, dynamic>>> _unitsByItem = {};
  String? _partyId;
  String? _warehouseId;
  String? _itemId;
  String? _selectedDocumentId;
  String _documentType = 'invoice';
  String _sourceChannel = 'manual';
  List<String> _sourceDocumentIds = <String>[];
  bool _saving = false;
  bool _loading = false;
  String? _error;
  String? _message;

  String get _title {
    if (widget.kind == ErpOperationalKind.purchase) return 'مستندات المشتريات';
    return _salesDocumentTitle(_documentType);
  }

  String _salesDocumentTitle(String type) => const <String, String>{
    'quotation': 'عرض سعر',
    'order': 'أمر بيع',
    'invoice': 'فاتورة بيع',
    'return': 'مرتجع البيع',
    'delivery': 'إذن التسليم',
  }[type] ?? 'مستندات المبيعات';

  Future<void> _pickSourceDocuments() async {
    if (widget.kind != ErpOperationalKind.sales ||
        !['invoice', 'order'].contains(_documentType) ||
        _company.text.trim().isEmpty) return;
    final sourceType = _documentType == 'invoice' ? 'order' : 'quotation';
    final sourceLabel = sourceType == 'order' ? 'أوامر البيع' : 'عروض الأسعار';
    try {
      final raw = await Supabase.instance.client
          .from('erp_sales_documents')
          .select('id, document_number, auto_number, document_date, customer_id, grand_total, status')
          .eq('company_id', _company.text.trim())
          .eq('document_type', sourceType)
          .inFilter('status', ['draft', 'approved', 'posted'])
          .order('document_date', ascending: false)
          .limit(500);
      final docs = raw.map((r) => Map<String, dynamic>.from(r)).toList();
      final chosen = <String>{..._sourceDocumentIds};
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('جلب $sourceLabel — F1'),
            content: SizedBox(
              width: 620,
              height: 420,
              child: docs.isEmpty
                  ? const Center(child: Text('لا توجد مستندات مصدر متاحة.'))
                  : Column(children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(spacing: 8, children: [
                          TextButton(onPressed: () => setDialogState(() => chosen.addAll(docs.map((d) => _s(d['id'])))), child: const Text('تحديد الكل')),
                          TextButton(onPressed: () => setDialogState(chosen.clear), child: const Text('مسح التحديد')),
                          Text('المحدد: ${chosen.length}'),
                        ]),
                      ),
                      Expanded(child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final d = docs[index];
                          final id = _s(d['id']);
                          return CheckboxListTile(
                            dense: true,
                            value: chosen.contains(id),
                            title: Text('${_s(d['document_number'])} • مسلسل ${_s(d['auto_number'])}'),
                            subtitle: Text('${_s(d['document_date'])} • ${_money(d['grand_total'])} ج.م • ${_s(d['status'])}'),
                            onChanged: (v) => setDialogState(() {
                              if (v == true) chosen.add(id); else chosen.remove(id);
                            }),
                          );
                        },
                      )),
                    ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(onPressed: () {
                setState(() {
                  _sourceDocumentIds = chosen.toList();
                  _sourceChannel = chosen.isEmpty ? 'manual' : 'documents';
                });
                Navigator.pop(dialogContext);
              }, child: const Text('اعتماد المصادر')),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر جلب $sourceLabel: $error');
    }
  }
  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _documentType = widget.initialDocumentType ?? 'invoice';
    _selectedDocumentId = widget.initialDocumentId;
    if (widget.initialDocumentId != null) {
      // Load once when opening a specific document; scheduling a second load
      // here can race the initial company load and overwrite selected state.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _load(clearMessage: false);
        if (!mounted || _selectedDocumentId == null) return;
        final selected = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
        if (selected.isNotEmpty) {
          setState(() => _documentType = _s(selected.first['document_type']));
          await _loadLines(_selectedDocumentId!);
        }
      });
    } else if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }
  @override
  void dispose() {
    _company.dispose(); _documentNumber.dispose(); _partyCode.dispose(); _notes.dispose(); _quantity.dispose();
    _unitPrice.dispose(); _discount.dispose(); _tax.dispose(); _invoiceDiscountAmount.dispose(); _invoiceDiscountPercent.dispose(); super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);

  double get _pendingGross => _pendingLines.fold<double>(
    0, (sum, line) => sum + _n(line['quantity']) * _n(line['unit_price']),
  );
  double get _pendingLineDiscounts => _pendingLines.fold<double>(
    0, (sum, line) => sum + _n(line['discount']),
  );
  double get _invoiceDiscountValue => double.tryParse(_invoiceDiscountAmount.text.trim()) ?? 0;

  double _invoiceDiscountForLine(int index) {
    if (index < 0 || index >= _pendingLines.length || _pendingGross <= 0) return 0;
    final gross = _n(_pendingLines[index]['quantity']) * _n(_pendingLines[index]['unit_price']);
    if (index == _pendingLines.length - 1) {
      final allocated = _pendingLines.take(index).fold<double>(0, (sum, line) {
        final lineGross = _n(line['quantity']) * _n(line['unit_price']);
        return sum + (_invoiceDiscountValue * lineGross / _pendingGross * 100).roundToDouble() / 100;
      });
      return (_invoiceDiscountValue - allocated).clamp(0, double.infinity);
    }
    return (_invoiceDiscountValue * gross / _pendingGross * 100).roundToDouble() / 100;
  }

  void _recalculatePendingTax() {
    for (var index = 0; index < _pendingLines.length; index++) {
      final line = _pendingLines[index];
      final gross = _n(line['quantity']) * _n(line['unit_price']);
      final invoiceDiscount = _invoiceDiscountForLine(index);
      final taxable = (gross - _n(line['discount']) - invoiceDiscount).clamp(0, double.infinity);
      final rate = _isTaxInvoice ? _n(line['tax_rate']) : 0.0;
      line['tax'] = (taxable * rate / 100 * 100).roundToDouble() / 100;
    }
  }

  void _updatePendingLine(
    int index, {
    double? quantity,
    double? discountAmount,
    double? discountPercent,
    String? unitId,
  }) {
    if (index < 0 || index >= _pendingLines.length) return;
    setState(() {
      final line = Map<String, dynamic>.from(_pendingLines[index]);
      final oldGross = _n(line['quantity']) * _n(line['unit_price']);
      if (quantity != null) line['quantity'] = quantity < 0 ? 0.0 : quantity;
      if (unitId != null) {
        final options = _unitsByItem[_s(line['item_id'])] ?? [];
        if (options.isNotEmpty) {
          final unit = options.firstWhere((row) => _s(row['id']) == unitId, orElse: () => options.first);
          final oldFactor = _n(line['conversion_factor']) <= 0 ? 1.0 : _n(line['conversion_factor']);
          final newFactor = _n(unit['conversion_factor']) <= 0 ? 1.0 : _n(unit['conversion_factor']);
          final ratio = oldFactor / newFactor;
          line['base_price'] = _n(line['base_price']) * ratio;
          line['policy_price'] = _n(line['policy_price']) * ratio;
          line['adjusted_price'] = _n(line['adjusted_price']) * ratio;
          line['unit_price'] = _n(line['unit_price']) * ratio;
          line['conversion_factor'] = newFactor;
          line['unit_id'] = unitId.isEmpty ? null : unitId;
          line['unit_name'] = _s(unit['unit_name']).isEmpty ? _s(unit['unit_code']) : _s(unit['unit_name']);
        }
      }
      final gross = _n(line['quantity']) * _n(line['unit_price']);
      if (discountAmount != null) {
        line['discount'] = discountAmount.clamp(0, gross);
        line['discount_percent'] = gross <= 0 ? 0.0 : _n(line['discount']) * 100 / gross;
      } else if (discountPercent != null) {
        final percent = discountPercent.clamp(0, 100);
        line['discount_percent'] = percent;
        line['discount'] = gross * percent / 100;
      } else if (quantity != null || unitId != null) {
        final percent = _n(line['discount_percent']);
        line['discount'] = gross * percent / 100;
      }
      line['adjusted_price'] = _n(line['unit_price']) - (_n(line['quantity']) <= 0 ? 0 : _n(line['discount']) / _n(line['quantity']));
      _pendingLines[index] = line;
      final subtotal = _pendingGross;
      final currentPercent = double.tryParse(_invoiceDiscountPercent.text.trim()) ?? 0;
      if (currentPercent > 0 && subtotal >= 0) {
        _invoiceDiscountAmount.text = (subtotal * currentPercent / 100).toStringAsFixed(2);
      } else if (oldGross != gross && _invoiceDiscountValue > subtotal) {
        _invoiceDiscountAmount.text = _money(subtotal);
        _invoiceDiscountPercent.text = subtotal <= 0 ? '0' : '100';
      }
      _recalculatePendingTax();
    });
  }

  Future<void> _load({bool clearMessage = true}) async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة أولًا.');
      return;
    }
    setState(() { _loading = true; _error = null; if (clearMessage) _message = null; });
    final loadIssues = <String>[];
    Future<List<Map<String, dynamic>>> safeLoad(
      String label,
      Future<List<Map<String, dynamic>>> Function() action,
    ) async {
      try {
        return await action();
      } catch (error) {
        loadIssues.add('$label: $error');
        return <Map<String, dynamic>>[];
      }
    }
    final results = await Future.wait<List<Map<String, dynamic>>>([
      safeLoad('المستندات', () => _repo.fetchDocuments(companyId: _company.text, kind: widget.kind)),
      safeLoad('العملاء/الموردون', () => _repo.fetchParties(_company.text, widget.kind)),
      safeLoad('المخازن', () => _repo.fetchWarehouses(_company.text)),
      safeLoad('الأصناف', () => _repo.fetchItems(_company.text)),
    ]);
    if (!mounted) return;
    setState(() {
      _rows = widget.kind == ErpOperationalKind.sales
          ? results[0].where((r) => _s(r['document_type']) == (widget.initialDocumentType ?? _documentType)).toList()
          : results[0];
      _parties = results[1];
      _allWarehouses = results[2];
      _warehouses = results[2];
      _items = results[3];
      if (!_parties.any((r) => _s(r['id']) == _partyId)) {
        _partyId = _parties.isEmpty ? null : _s(_parties.first['id']);
      }
      final selectedParty = _parties.where((r) => _s(r['id']) == _partyId);
      _partyCode.text = selectedParty.isEmpty ? '' : _s(selectedParty.first['party_code']);
      if (!_warehouses.any((r) => _s(r['id']) == _warehouseId)) {
        _warehouseId = _warehouses.isEmpty ? null : _s(_warehouses.first['id']);
      }
      if (!_items.any((r) => _s(r['id']) == _itemId)) _itemId = _items.isEmpty ? null : _s(_items.first['id']);
      if (_selectedDocumentId != null && !_rows.any((r) => _s(r['id']) == _selectedDocumentId)) _selectedDocumentId = null;
      if (_selectedDocumentId != null) {
        final current = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
        if (current.isNotEmpty) {
          final documentPartyId = _s(widget.kind == ErpOperationalKind.purchase
              ? current.first['supplier_id']
              : current.first['customer_id']);
          final documentWarehouseId = _s(current.first['warehouse_id']);
          _partyId = _parties.any((r) => _s(r['id']) == documentPartyId) ? documentPartyId : null;
          _warehouseId = _warehouses.any((r) => _s(r['id']) == documentWarehouseId) ? documentWarehouseId : null;
          final currentParty = _parties.where((r) => _s(r['id']) == _partyId);
          _partyCode.text = currentParty.isEmpty ? '' : _s(currentParty.first['party_code']);
        }
      }
      _loading = false;
      _error = loadIssues.isEmpty ? null : 'تعذر تحميل بعض البيانات: ${loadIssues.join(' • ')}';
    });
    if (widget.kind == ErpOperationalKind.sales) {
      try {
        final reps = await _repo.fetchRepresentatives(_company.text.trim());
        final canChangeRep = await _resolveSalesRepChangePermission(_company.text.trim());
        if (mounted) setState(() {
          _canChangeSalesRep = canChangeRep;
          _representatives = reps;
          final selectedParty = _parties.where((party) => _s(party['id']) == _partyId);
          if (selectedParty.isNotEmpty) {
            final defaultRep = _s(selectedParty.first['sales_rep_id']);
            _salesRepId = reps.any((rep) => _s(rep['id']) == defaultRep) ? defaultRep : null;
          }
        });
      } catch (error) {
        if (mounted) setState(() {
          _representatives = [];
          _error = '${_error == null ? '' : '$_error • '}تعذر تحميل مندوبي المبيعات: $error';
        });
      }
      if (_selectedDocumentId == null && mounted) await _applyCustomerWarehouseRules(_partyId);
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

  Future<void> _applyCustomerWarehouseRules(String? partyId) async {
    if (widget.kind != ErpOperationalKind.sales) return;
    if (partyId == null || partyId.isEmpty) {
      if (mounted) setState(() {
        _warehouses = List<Map<String, dynamic>>.from(_allWarehouses);
        _warehouseId = _warehouses.isEmpty ? null : _s(_warehouses.first['id']);
      });
      return;
    }
    try {
      final allowedIds = await _repo.fetchPartyWarehouseIds(
        companyId: _company.text.trim(),
        partyId: partyId,
      );
      final party = _parties.firstWhere(
        (row) => _s(row['id']) == partyId,
        orElse: () => <String, dynamic>{},
      );
      final defaultId = _s(party['default_warehouse_id']);
      if (!mounted || _partyId != partyId) return;
      setState(() {
        // An empty permission list means no warehouse restrictions have been
        // configured for this customer yet; retain all active warehouses.
        _warehouses = allowedIds.isEmpty
            ? List<Map<String, dynamic>>.from(_allWarehouses)
            : _allWarehouses.where((warehouse) => allowedIds.contains(_s(warehouse['id']))).toList();
        if (defaultId.isNotEmpty && _warehouses.any((row) => _s(row['id']) == defaultId)) {
          _warehouseId = defaultId;
        } else if (!_warehouses.any((row) => _s(row['id']) == _warehouseId)) {
          _warehouseId = _warehouses.isEmpty ? null : _s(_warehouses.first['id']);
        }
      });
    } catch (error) {
      if (!mounted || _partyId != partyId) return;
      setState(() {
        // Fail closed: if access rules cannot be read, do not expose selectable warehouses.
        _warehouses = [];
        _warehouseId = null;
        _error = 'تعذر قراءة مخازن العميل المسموح بها؛ أوقف النظام اختيار المخزن حتى يمكن التحقق من الصلاحيات: $error';
      });
    }
  }

  Future<void> _onPartyChanged(String? value) async {
    setState(() {
      _partyId = value;
      final matches = _parties.where((party) => _s(party['id']) == value);
      _partyCode.text = matches.isEmpty ? '' : _s(matches.first['party_code']);
      final defaultRep = matches.isEmpty ? '' : _s(matches.first['sales_rep_id']);
      _salesRepId = defaultRep.isNotEmpty && _representatives.any((rep) => _s(rep['id']) == defaultRep)
          ? defaultRep
          : null;
      _warehouses = [];
      _warehouseId = null;
    });
    await _applyCustomerWarehouseRules(value);
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
        documentDate: _documentDate, salesRepId: _salesRepId, isTaxInvoice: _isTaxInvoice,
        sourceChannel: _sourceChannel, sourceDocumentIds: _sourceDocumentIds,
      );
      if (!mounted) return;
      _documentNumber.clear(); _notes.clear();
      setState(() { _saving = false; _selectedDocumentId = id; _lines = []; _pendingLines = []; _message = 'تم إنشاء مسودة المستند. أضف البنود ثم رحّلها.'; });
      await _load(clearMessage: false);
      if (mounted) setState(() => _selectedDocumentId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر إنشاء المسودة: $e'; });
    }
  }

  Future<bool> _resolveSalesRepChangePermission(String companyId) async {
    try {
      final db = Supabase.instance.client;
      final userId = db.auth.currentUser?.id;
      if (userId == null) return false;
      final membership = await db.from('erp_company_members')
          .select('member_role')
          .eq('company_id', companyId)
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();      if (membership == null) return false;      final role = _s(membership['member_role']).toLowerCase();      if (role == 'owner' || role == 'admin') return true;
      final permission = await db.from('erp_user_permissions')
          .select('allow_access,can_edit')
          .eq('company_id', companyId)
          .eq('user_id', userId)
          .eq('menu_key', 'المبيعات والعملاء::حركات::فاتورة مبيعات')
          .maybeSingle();
      return permission != null &&
          permission['allow_access'] == true &&
          permission['can_edit'] == true;
    } catch (_) {
      // Fail closed: when permissions cannot be verified, do not permit changing the rep.
      return false;
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

  Future<void> _openCampaignPicker(String campaignType) async {
    if (widget.kind != ErpOperationalKind.sales || _company.text.trim().isEmpty || _partyId == null) {
      setState(() => _error = 'اختر العميل وحمّل بيانات الشركة قبل جلب العروض.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final fetchedCampaigns = await _repo.fetchSalesCampaigns(companyId: _company.text.trim(), campaignType: campaignType);
      final partyRows = _parties.where((p) => _s(p['id']) == _partyId);
      final party = partyRows.isEmpty ? <String,dynamic>{} : partyRows.first;
      final warehouseRows = _allWarehouses.where((w) => _s(w['id']) == _warehouseId);
      final warehouse = warehouseRows.isEmpty ? <String,dynamic>{} : warehouseRows.first;
      bool targetMatches(dynamic raw, String actual) {
        final values = raw is List ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : <String>[];
        return values.isEmpty || (actual.isNotEmpty && values.contains(actual));
      }
      final campaigns = fetchedCampaigns.where((campaign) {
        final owner = _s(campaign['owner_party_id']);
        if (owner.isNotEmpty && owner != _partyId) return false;
        if (!targetMatches(campaign['target_customer_ids'], _s(_partyId))) return false;
        if (!targetMatches(campaign['target_warehouse_ids'], _s(_warehouseId))) return false;
        if (!targetMatches(campaign['target_branch_ids'], _s(warehouse['branch_id']))) return false;
        if (!targetMatches(campaign['target_governorates'], _s(party['governorate']))) return false;
        if (!targetMatches(campaign['target_districts'], _s(party['district']))) return false;
        if (!targetMatches(campaign['target_areas'], _s(party['area']))) return false;
        if (!targetMatches(campaign['target_centers'], _s(party['center']))) return false;
        if (!targetMatches(campaign['target_customer_types'], _s(party['customer_type']))) return false;
        return true;
      }).toList();
      if (!mounted) return;
      setState(() => _loading = false);
      if (campaigns.isEmpty) {
        setState(() => _message = 'لا توجد عروض متاحة حاليًا من هذا النوع.');
        return;
      }
      final heading = campaignType == 'customer_magazine' ? 'مجلات عروض العملاء المتاحة'
          : campaignType == 'promotion' ? 'عروض الترويج المتاحة' : 'عروض الرواكد المتاحة';
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(heading, style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900)),
            content: SizedBox(width: 680, child: ListView.separated(
              shrinkWrap: true, itemCount: campaigns.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = campaigns[index];
                final owner = _s(c['owner_label']);
                return ListTile(
                  leading: const Icon(Icons.local_offer_outlined, color: Color(0xFF3E007D)),
                  title: Text(_s(c['title']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('الفترة: ' + _s(c['start_date']) + ' إلى ' + _s(c['end_date']) +
                    (owner.isEmpty || campaignType == 'customer_magazine' ? '' : '\n' + (campaignType == 'promotion' ? 'المورد: ' : 'مسؤول الشراء: ') + owner)),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.pop(dialogContext, c),
                );
              },
            )),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء'))],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      setState(() { _loading = true; _error = null; });
      final lines = await _repo.fetchSalesCampaignItems(companyId: _company.text.trim(), campaignId: _s(selected['id']));
      final sourceItems = <Map<String, dynamic>>[];
      for (final line in lines) {
        final base = _items.where((item) => _s(item['id']) == _s(line['item_id']));
        final remaining = line['remaining_quantity'];
        final configuredMax = line['max_quantity'];
        final maxAllowed = remaining == null ? configuredMax : (configuredMax == null ? remaining : (_n(remaining) < _n(configuredMax) ? remaining : configuredMax));
        if (base.isNotEmpty && (remaining == null || _n(remaining) > 0)) {
          sourceItems.add({...base.first, ...line, 'id': _s(base.first['id']), 'campaign_item_id': _s(line['id']), 'max_quantity': maxAllowed, 'offer_title': _s(selected['title']), 'offer_type': campaignType});
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
      if (sourceItems.isEmpty) {
        setState(() => _error = 'العرض المحدد لا يحتوي على أصناف نشطة مرتبطة بقاعدة بيانات الأصناف.');
        return;
      }
      await _openItemPicker(sourceItems: sourceItems, sourceTitle: _s(selected['title']));
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل العروض وأصنافها: ' + error.toString(); });
    }
  }

  Future<void> _openCustomerShortages() async {
    if (widget.kind != ErpOperationalKind.sales || _company.text.trim().isEmpty || _partyId == null) {
      setState(() => _error = 'اختر العميل وحمّل بيانات الشركة قبل جلب نواقص العميل.');
      return;
    }
    DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime to = DateTime.now();
    var loading = false;
    var didInitialLoad = false;
    String? loadError;
    var shortages = <Map<String, dynamic>>[];
    Future<void> reload(void Function(void Function()) refresh) async {
      refresh(() { loading = true; loadError = null; });
      try {
        final rows = await _repo.fetchCustomerShortages(companyId: _company.text.trim(), customerId: _partyId!, from: from, to: to);
        final result = <Map<String, dynamic>>[];
        for (final row in rows) {
          final item = _items.where((v) => _s(v['id']) == _s(row['item_id']));
          if (item.isNotEmpty) result.add({...row, ...item.first});
        }
        refresh(() { shortages = result; loading = false; });
      } catch (e) {
        refresh(() { loading = false; loadError = 'تعذر تحميل النواقص: ' + e.toString(); });
      }
    }
    await showDialog<void>(
      context: context, barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (context, refresh) {
          Future<void> pickDate(bool isFrom) async {
            final d = await showDatePicker(context: dialogContext, initialDate: isFrom ? from : to, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (d == null) return;
            if (isFrom) { from = d; if (from.isAfter(to)) to = from; }
            else { to = d; if (to.isBefore(from)) from = to; }
            await reload(refresh);
          }
          if (!didInitialLoad && !loading && shortages.isEmpty && loadError == null) {
            didInitialLoad = true;
            WidgetsBinding.instance.addPostFrameCallback((_) { if (dialogContext.mounted) reload(refresh); });
          }
          return AlertDialog(
            title: const Text('نواقص العميل المفتوحة', style: TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900)),
            content: SizedBox(width: 1050, height: 560, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.date_range), label: Text('من: ' + from.toIso8601String().substring(0, 10))),
                OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text('إلى: ' + to.toIso8601String().substring(0, 10))),
                FilledButton.tonalIcon(onPressed: () => reload(refresh), icon: const Icon(Icons.refresh), label: const Text('تحديث')),
              ]),
              const SizedBox(height: 8),
              if (loadError != null) Text(loadError!, style: const TextStyle(color: Colors.red)),
              if (loading) const LinearProgressIndicator(),
              if (!loading) Expanded(child: shortages.isEmpty ? const Center(child: Text('لا توجد نواقص مفتوحة في الفترة المحددة.')) :
                SingleChildScrollView(child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                  columns: const [DataColumn(label: Text('م. تنازلي')), DataColumn(label: Text('تاريخ')), DataColumn(label: Text('رقم الفاتورة')), DataColumn(label: Text('كود الصنف')), DataColumn(label: Text('الصنف')), DataColumn(label: Text('مطلوب')), DataColumn(label: Text('منفذ')), DataColumn(label: Text('متبقي')), DataColumn(label: Text('إجراءات'))],
                  rows: List<DataRow>.generate(shortages.length, (index) {
                    final row = shortages[index];
                    final remaining = (_n(row['requested_quantity']) - _n(row['fulfilled_quantity'])).clamp(0, double.infinity);
                    return DataRow(cells: [
                      DataCell(Text((shortages.length - index).toString())),
                      DataCell(Text(_s(row['source_date']))),
                      DataCell(Text(_s(row['source_document_number']))),
                      DataCell(Text(_s(row['item_code']))),
                      DataCell(Text(_s(row['item_name']))),
                      DataCell(Text(_money(row['requested_quantity']))),
                      DataCell(Text(_money(row['fulfilled_quantity']))),
                      DataCell(Text(_money(remaining))),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'جلب الصنف', onPressed: remaining <= 0 ? null : () async {
                          Navigator.pop(dialogContext);
                          await _openItemPicker(sourceItems: [{...row, 'id': _s(row['item_id']), 'shortage_id': _s(row['id']), 'offer_price': _n(row['sale_price']), 'min_quantity': 0.0001, 'max_quantity': remaining, 'offer_title': 'نواقص العميل'}], sourceTitle: 'نواقص العميل');
                        }, icon: const Icon(Icons.playlist_add, color: Color(0xFF3E007D))),
                        IconButton(tooltip: 'حذف النقص', onPressed: () async {
                          final yes = await showDialog<bool>(context: dialogContext, builder: (c) => AlertDialog(
                            title: const Text('تأكيد حذف النقص'),
                            content: Text('هل تريد حذف نقص الصنف «' + _s(row['item_name']) + '»؟ لا يمكن التراجع عن الحذف.'),
                            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('نعم، حذف'))],
                          ));
                          if (yes != true) return;
                          try {
                            await _repo.deleteCustomerShortage(companyId: _company.text.trim(), shortageId: _s(row['id']));
                            await reload(refresh);
                          } catch (e) { refresh(() => loadError = 'تعذر حذف النقص: ' + e.toString()); }
                        }, icon: const Icon(Icons.delete_outline, color: Colors.red)),
                      ])),
                    ]);
                  }),
                ))),
            ])),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
          );
        }),
      ),
    );
  }

  Future<void> _openItemPicker({List<Map<String, dynamic>>? sourceItems, String? sourceTitle}) async {
    final pickerItems = sourceItems ?? _items;
    if (_saving || _loading) return;
    var selectedDoc = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
    if (selectedDoc.isEmpty || _s(selectedDoc.first['status']) != 'draft') {
      if (!(widget.kind == ErpOperationalKind.sales && _documentType == 'invoice')) {
        setState(() => _error = 'أنشئ مسودة أو اختر مستندًا بحالة مسودة أولًا.');
        return;
      }
      if (_company.text.trim().isEmpty) {
        setState(() => _error = 'أدخل معرّف الشركة ثم اضغط تحديث قبل جلب الأصناف.');
        return;
      }
      if (_partyId == null || _warehouseId == null) {
        setState(() => _error = 'اختر العميل والمخزن أولًا. تأكد من تحميل بيانات الشركة.');
        return;
      }
      if (_documentNumber.text.trim().isEmpty) {
        _documentNumber.text = 'S-' + DateTime.now().millisecondsSinceEpoch.toString();
      }
      await _createDraft();
      if (!mounted || _selectedDocumentId == null) return;
      selectedDoc = _rows.where((r) => _s(r['id']) == _selectedDocumentId);
      if (selectedDoc.isEmpty || _s(selectedDoc.first['status']) != 'draft') {
        setState(() => _error = 'لم يتم إنشاء مسودة صالحة؛ راجع رسالة الخطأ قبل اختيار الأصناف.');
        return;
      }
    }
    if (_warehouseId == null || _partyId == null || pickerItems.isEmpty) {
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
    if (mounted) setState(() => _unitsByItem = unitsByItem);

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
    final quantityFocusNodes = <String, FocusNode>{};
    final unitFocusNodes = <String, FocusNode>{};
    final selectedUnits = <String, String>{};
    final search = TextEditingController();
    final searchFocusNode = FocusNode();
    for (final item in pickerItems) {
      final id = _s(item['id']);
      final suggestedQuantity = sourceTitle == 'نواقص العميل'
          ? (_n(item['requested_quantity']) - _n(item['fulfilled_quantity'])).clamp(0, double.infinity)
          : 0.0;
      quantities[id] = TextEditingController(text: suggestedQuantity > 0 ? suggestedQuantity.toString() : '');
      quantityFocusNodes[id] = FocusNode(debugLabel: 'quantity-$id');
      unitFocusNodes[id] = FocusNode(debugLabel: 'unit-$id');
      final options = unitsByItem[id] ?? [];
      final base = options.where((unit) => unit['is_base_unit'] == true);
      selectedUnits[id] = base.isNotEmpty ? _s(base.first['id']) : (options.isNotEmpty ? _s(options.first['id']) : '');
    }

    List<Map<String, dynamic>>? picked;
    try {
      picked = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (context, refresh) {
          final query = search.text.trim().toLowerCase();
          final visibleItems = pickerItems.where((item) {
            final haystack = '${_s(item['item_code'])} ${_s(item['item_name'])} ${_s(item['barcode'])}'.toLowerCase();
            return query.isEmpty || haystack.contains(query);
          }).toList();
          final selectedItems = pickerItems.where((item) {
            final quantity = double.tryParse(quantities[_s(item['id'])]!.text.trim()) ?? 0;
            return quantity > 0;
          }).toList();
          void focusQuantityAt(int index) {
            if (visibleItems.isEmpty) return;
            final safeIndex = index.clamp(0, visibleItems.length - 1);
            quantityFocusNodes[_s(visibleItems[safeIndex]['id'])]?.requestFocus();
          }
          void focusUnitAt(int index) {
            if (visibleItems.isEmpty) return;
            final safeIndex = index.clamp(0, visibleItems.length - 1);
            unitFocusNodes[_s(visibleItems[safeIndex]['id'])]?.requestFocus();
          }

          List<Map<String, dynamic>> optionsFor(Map<String, dynamic> item) {
            final options = unitsByItem[_s(item['id'])] ?? [];
            if (options.isNotEmpty) return options;
            final base = _s(item['base_unit']).isEmpty ? 'وحدة' : _s(item['base_unit']);
            return [{'id': '', 'unit_code': base, 'unit_name': base, 'conversion_factor': 1, 'is_base_unit': true}];
          }

          List<Map<String, dynamic>> buildPickedResult() {
            final result = <Map<String, dynamic>>[];
            for (final item in selectedItems) {
              final id = _s(item['id']);
              final qty = double.tryParse(quantities[id]!.text.trim()) ?? 0;
              final options = optionsFor(item);
              final unitId = selectedUnits[id] ?? '';
              final unit = options.firstWhere((row) => _s(row['id']) == unitId, orElse: () => options.first);
              final factor = _n(unit['conversion_factor']) <= 0 ? 1.0 : _n(unit['conversion_factor']);
              final basePrice = widget.kind == ErpOperationalKind.purchase ? _n(item['purchase_price']) : _n(item['sale_price']);
              final offerPrice = sourceItems == null ? basePrice : _n(item['offer_price']);
              final minQuantity = sourceItems == null ? null : item['min_quantity'];
              final maxQuantity = sourceItems == null ? null : item['max_quantity'];
              final selectedUnitPrice = factor > 1 ? offerPrice / factor : offerPrice;
              result.add({
                'item_id': id,
                'quantity': qty,
                'unit_id': unitId,
                'unit_name': _s(unit['unit_name']).isEmpty ? _s(unit['unit_code']) : _s(unit['unit_name']),
                'conversion_factor': factor,
                'unit_price': selectedUnitPrice,
                'fixed_unit_price': sourceItems == null ? null : selectedUnitPrice,
                'min_quantity': minQuantity,
                'max_quantity': maxQuantity == null ? null : (_n(maxQuantity) / factor),
                'representative_incentive': _n(item['representative_incentive']),
                'customer_incentive': _n(item['customer_incentive']),
                'offer_title': sourceTitle,
                'shortage_id': item['shortage_id'],
                'campaign_item_id': item['campaign_item_id'],
                'discount': 0.0,
                'tax': 0.0,
              });
            }
            return result;
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1) {
                if (selectedItems.isNotEmpty) Navigator.pop(dialogContext, buildPickedResult());
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: AlertDialog(
            title: Row(children: [
              Expanded(child: Text(sourceTitle == null ? 'اختيار الأصناف — F1' : 'اختيار الأصناف — ' + sourceTitle + ' (F1)', style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900))),
              Chip(label: Text('${selectedItems.length} صنف')),
            ]),
            content: SizedBox(
              width: 1240,
              height: 650,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: search,
                  focusNode: searchFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => focusQuantityAt(0),
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
                  child: Column(children: visibleItems.asMap().entries.map((entry) {
                    final itemIndex = entry.key;
                    final item = entry.value;
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
                    final baseDisplayPrice = sourceItems != null ? _n(item['offer_price']) : (widget.kind == ErpOperationalKind.purchase
                        ? _n(item['purchase_price']) : _n(item['sale_price']));
                    final price = factor > 1 ? baseDisplayPrice / factor : baseDisplayPrice;
                    final sourceDetails = sourceItems == null ? '' :
                        'سعر الصنف: ' + _money(item['sale_price']) + ' | سعر العرض: ' + _money(item['offer_price']) +
                        ' | أقل كمية: ' + _money(item['min_quantity']) + ' | أعلى كمية: ' +
                        (_s(item['max_quantity']).isEmpty ? 'مفتوح' : _money(item['max_quantity'])) +
                        (_s(item['offer_type']) == 'slow_moving' ? ' | حافز المندوب: ' + _money(item['representative_incentive']) + ' | حافز العميل: ' + _money(item['customer_incentive']) : '');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (quantities[id]!.text.trim().isNotEmpty ? const Color(0xFFFFF3DB) : Colors.white),
                        border: const Border(bottom: BorderSide(color: Color(0xFFE9E2EF))),
                      ),
                      child: Row(children: [
                        SizedBox(width: 95, child: Text(_s(item['item_code']), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 190, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_s(item['item_name']), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (sourceItems != null) Text(sourceDetails, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF3E007D))),
                        ])),
                        SizedBox(width: 85, child: Text(_money(price))),
                        SizedBox(width: 85, child: Text(_money(onHand))),
                        SizedBox(width: 85, child: Text(_money(held), style: const TextStyle(color: Color(0xFFB56B00)))),
                        SizedBox(width: 85, child: Text(_money(available), style: TextStyle(color: available < 0 ? Colors.red : const Color(0xFF3E007D), fontWeight: FontWeight.w800))),
                        SizedBox(width: 190, child: Focus(
                          focusNode: unitFocusNodes[id],
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.enter ||
                                  event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                                  event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                quantityFocusNodes[id]?.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                focusUnitAt(itemIndex - 1);
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                focusUnitAt(itemIndex + 1);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: DropdownButtonFormField<String>(
                            value: selectedUnitId,
                            isDense: true,
                            isExpanded: true,
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7)),
                            items: options.map((unit) => DropdownMenuItem<String>(
                              value: _s(unit['id']),
                              child: Text(_s(unit['unit_name']).isEmpty ? _s(unit['unit_code']) : _s(unit['unit_name']), overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (value) => refresh(() => selectedUnits[id] = value ?? ''),
                          ),
                        )),
                        const SizedBox(width: 8),
                        SizedBox(width: 102, child: Focus(
                          focusNode: quantityFocusNodes[id],
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.enter ||
                                  event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                focusQuantityAt(itemIndex + 1);
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                if (itemIndex == 0) {
                                  searchFocusNode.requestFocus();
                                } else {
                                  focusQuantityAt(itemIndex - 1);
                                }
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                unitFocusNodes[id]?.requestFocus();
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: quantities[id],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => focusQuantityAt(itemIndex + 1),
                            onChanged: (_) => refresh(() {}),
                            decoration: const InputDecoration(hintText: '0', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                          ),
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
                  height: 145,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFF8F5FC), borderRadius: BorderRadius.circular(8)),
                  child: selectedItems.isEmpty
                      ? const Center(child: Text('اكتب كمية بجوار الصنف لإضافته إلى المعاينة.'))
                      : Column(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            color: const Color(0xFFF2EAFB),
                            child: const Row(children: [
                              SizedBox(width: 85, child: Text('الكود', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                              Expanded(child: Text('اسم الصنف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                              SizedBox(width: 90, child: Text('الوحدة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                              SizedBox(width: 68, child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                              SizedBox(width: 78, child: Text('السعر', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                              SizedBox(width: 40, child: Text('حذف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                            ]),
                          ),
                          Expanded(child: ListView(children: selectedItems.map((item) {
                            final id = _s(item['id']);
                            final qty = double.tryParse(quantities[id]!.text.trim()) ?? 0;
                            final options = optionsFor(item);
                            final unitId = selectedUnits[id] ?? '';
                            final unit = options.firstWhere((row) => _s(row['id']) == unitId, orElse: () => options.first);
                            final factor = _n(unit['conversion_factor']) <= 0 ? 1.0 : _n(unit['conversion_factor']);
                            final itemPrice = sourceItems != null ? _n(item['offer_price']) : (widget.kind == ErpOperationalKind.purchase ? _n(item['purchase_price']) : _n(item['sale_price']));
                            final unitPrice = factor > 1 ? itemPrice / factor : itemPrice;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE9E2EF)))),
                              child: Row(children: [
                                SizedBox(width: 85, child: Text(_s(item['item_code']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                                Expanded(child: Text(_s(item['item_name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                                SizedBox(width: 90, child: Text(_s(unit['unit_name']).isEmpty ? _s(unit['unit_code']) : _s(unit['unit_name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                                SizedBox(width: 68, child: Text(_money(qty), style: const TextStyle(fontSize: 11))),
                                SizedBox(width: 78, child: Text(_money(unitPrice), style: const TextStyle(fontSize: 11))),
                                SizedBox(width: 40, child: IconButton(
                                  tooltip: 'حذف من المعاينة',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () { quantities[id]!.clear(); refresh(() {}); },
                                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                                )),
                              ]),
                            );
                          }).toList())),
                        ]),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton.icon(
                onPressed: selectedItems.isEmpty ? null : () => Navigator.pop(dialogContext, buildPickedResult()),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('موافق وإضافة البنود (F1)'),
              ),
            ],
          ),
          );
          }),
        ),
      );
    } finally {
      search.dispose();
      searchFocusNode.dispose();
      for (final controller in quantities.values) {
        controller.dispose();
      }
      for (final node in quantityFocusNodes.values) {
        node.dispose();
      }
      for (final node in unitFocusNodes.values) {
        node.dispose();
      }
    }

    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final selectedPartyId = _s(widget.kind == ErpOperationalKind.purchase
          ? selectedDoc.first['supplier_id']
          : selectedDoc.first['customer_id']);
      if (selectedPartyId.isEmpty) {
        throw StateError('المستند لا يحتوي على مورد أو عميل صالح للتسعير.');
      }
      final pricedLines = <Map<String, Object?>>[];
      for (final line in picked) {
        final itemId = _s(line['item_id']);
        final quantity = _n(line['quantity']);
        final factor = _n(line['conversion_factor']) <= 0 ? 1.0 : _n(line['conversion_factor']);
        final fixedOfferPrice = line['fixed_unit_price'];
        if (fixedOfferPrice != null) {
          final minQty = line['min_quantity'] == null ? 0.0 : _n(line['min_quantity']);
          final maxQty = line['max_quantity'] == null || _s(line['max_quantity']).isEmpty ? double.infinity : _n(line['max_quantity']);
          if (quantity < minQty || quantity > maxQty) {
            throw ArgumentError('كمية الصنف $itemId يجب أن تكون بين ${minQty.toStringAsFixed(2)} و ${maxQty.isInfinite ? 'غير محدد' : maxQty.toStringAsFixed(2)} حسب شروط العرض.');
          }
        }
        final resolved = fixedOfferPrice != null ? <String, dynamic>{
          'base_unit_price': fixedOfferPrice,
          'net_unit_price': fixedOfferPrice,
          'discount_percent': 0,
        } : await _repo.resolvePrice(
          companyId: _company.text.trim(),
          itemId: itemId,
          kind: widget.kind == ErpOperationalKind.purchase ? 'purchase' : 'sale',
          quantity: quantity * factor,
          partyId: selectedPartyId,
        );
        if (resolved == null) {
          throw StateError('لم يتمكن النظام من تحديد سياسة التسعير للصنف $itemId.');
        }
        final unitPrice = fixedOfferPrice != null ? _n(fixedOfferPrice) : _n(resolved['base_unit_price']) / factor;
        final discountPercent = fixedOfferPrice != null ? 0.0 : _n(resolved['discount_percent']);
        final discount = quantity * unitPrice * discountPercent / 100;
        final item = _items.firstWhere((row) => _s(row['id']) == itemId, orElse: () => <String, dynamic>{});
        final basePrice = (widget.kind == ErpOperationalKind.purchase ? _n(item['purchase_price']) : _n(item['sale_price'])) / factor;
        final adjustedPrice = fixedOfferPrice != null ? _n(fixedOfferPrice) : _n(resolved['net_unit_price']) / factor;
        final taxRate = widget.kind == ErpOperationalKind.sales ? _n(item['tax_rate']) : 0.0;
        final tax = ((quantity * unitPrice - discount).clamp(0, double.infinity)) * (_isTaxInvoice ? taxRate : 0.0) / 100;
        pricedLines.add({
          'item_id': itemId,
          'quantity': quantity,
          'unit_id': _s(line['unit_id']).isEmpty ? null : line['unit_id'],
          'base_price': basePrice,
          'policy_price': unitPrice,
          'adjusted_price': adjustedPrice,
          'discount_percent': discountPercent,
          'discount_limit': _n(item['discount_limit']),
          'conversion_factor': factor,
          'unit_price': unitPrice,
          'discount': discount,
          'tax': tax,
          'tax_rate': taxRate,
          'representative_incentive': _n(line['representative_incentive']),
          'customer_incentive': _n(line['customer_incentive']),
          'offer_title': _s(line['offer_title']),
          'campaign_item_id': line['campaign_item_id'],
          'shortage_id': line['shortage_id'],
        });
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pendingLines = [
          ..._pendingLines,
          ...pricedLines.map((line) => <String, dynamic>{
            ...line,
            'item_code': _s(_items.firstWhere((item) => _s(item['id']) == _s(line['item_id']), orElse: () => {})['item_code']),
            'item_name': _s(_items.firstWhere((item) => _s(item['id']) == _s(line['item_id']), orElse: () => {})['item_name']),
            'unit_name': _s(picked!.firstWhere((pickedLine) => _s(pickedLine['item_id']) == _s(line['item_id']), orElse: () => {})['unit_name']),
          }),
        ];
        final subtotal = _pendingLines.fold<double>(0, (sum, line) => sum + _n(line['quantity']) * _n(line['unit_price']));
        final percent = double.tryParse(_invoiceDiscountPercent.text.trim()) ?? 0;
        if (percent > 0) {
          _invoiceDiscountAmount.text = (subtotal * percent / 100).toStringAsFixed(2);
        }
        _recalculatePendingTax();
        _message = 'تم نقل الأصناف إلى جريد معاينة الفاتورة. لن تُحفظ في قاعدة البيانات إلا بعد الضغط على «موافقة وحفظ الأصناف».';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'لم تُحفظ البنود المحددة؛ ألغت قاعدة البيانات العملية كاملة عند فشل التحقق أو الحجز: $error'; });
    }
  }

  Future<void> _savePendingLines() async {
    if (_selectedDocumentId == null || _pendingLines.isEmpty) {
      setState(() => _error = 'اختر الأصناف باستخدام F1 أولًا قبل الحفظ.');
      return;
    }
    final selected = _rows.where((row) => _s(row['id']) == _selectedDocumentId);
    if (selected.isEmpty || _s(selected.first['status']) != 'draft') {
      setState(() => _error = 'لا يمكن حفظ الأصناف إلا داخل فاتورة بحالة مسودة.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final grossTotal = _pendingLines.fold<double>(0, (sum, line) => sum + _n(line['quantity']) * _n(line['unit_price']));
      final currentLineDiscounts = _pendingLines.fold<double>(0, (sum, line) => sum + _n(line['discount']));
      final invoiceDiscount = widget.kind == ErpOperationalKind.sales && _documentType == 'invoice'
          ? (double.tryParse(_invoiceDiscountAmount.text.trim()) ?? 0)
          : 0.0;
      final maxDiscount = (grossTotal - currentLineDiscounts).clamp(0, double.infinity);
      if (invoiceDiscount < 0 || invoiceDiscount > maxDiscount + 0.005) {
        throw ArgumentError('خصم الفاتورة يجب أن يكون بين صفر وصافي قيمة الأصناف بعد خصوماتها؛ الحد المتاح ${maxDiscount.toStringAsFixed(2)}.');
      }
      var remainingInvoiceDiscount = invoiceDiscount;
      final payload = <Map<String, Object?>>[];
      for (var index = 0; index < _pendingLines.length; index++) {
        final line = _pendingLines[index];
        final gross = _n(line['quantity']) * _n(line['unit_price']);
        final allocatedDiscount = index == _pendingLines.length - 1
            ? remainingInvoiceDiscount
            : (grossTotal <= 0 ? 0.0 : (invoiceDiscount * gross / grossTotal * 100).roundToDouble() / 100);
        remainingInvoiceDiscount = (remainingInvoiceDiscount - allocatedDiscount).clamp(0, double.infinity);
        final totalDiscount = _n(line['discount']) + allocatedDiscount;
        if (totalDiscount > gross + 0.005) throw ArgumentError('خصم السطر أكبر من قيمة الصنف.');
        final taxRate = widget.kind == ErpOperationalKind.sales && _isTaxInvoice ? _n(line['tax_rate']) : 0.0;
        final taxableBase = (gross - totalDiscount).clamp(0, double.infinity);
        final taxAmount = (taxableBase * taxRate / 100 * 100).roundToDouble() / 100;
        payload.add({
          'item_id': line['item_id'],
          'quantity': line['quantity'],
          'unit_id': line['unit_id'],
          'unit_price': line['unit_price'],
          'discount': totalDiscount,
          'tax': taxAmount,
          'campaign_item_id': line['campaign_item_id'],
          'shortage_id': line['shortage_id'],
        });
      }
      final count = await _repo.addLinesAtomically(
        documentId: _selectedDocumentId!,
        kind: widget.kind,
        lines: payload,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pendingLines = [];
        _invoiceDiscountAmount.text = '0';
        _invoiceDiscountPercent.text = '0';
        _message = 'تم حفظ $count صنفًا في الفاتورة بنجاح.';
      });
      await _load(clearMessage: false);
      if (mounted && _selectedDocumentId != null) await _loadLines(_selectedDocumentId!);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذر حفظ الأصناف؛ ما زالت بيانات المعاينة موجودة ولم يتم حذفها: $error';
      });
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
    final number = _s(row['document_number']);    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الترحيل'),
      content: Text('سيتم ترحيل المستند $number وإنشاء حركات مخزنية فعلية. لا يمكن إعادة ترحيله بعد نجاح العملية.'),      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ترحيل')),      ],
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

  Widget _invoiceCard(String title, IconData icon, Widget child) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE8E1F0))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF3E007D), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF3E007D), fontSize: 15, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }

  Widget _invoiceMetric(String label, String value, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: strong ? const Color(0xFFF5EFFB) : const Color(0xFFFAF8FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E1F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: strong ? const Color(0xFF3E007D) : const Color(0xFF241735), fontWeight: FontWeight.w900, fontSize: strong ? 16 : 13)),
      ]),
    );
  }

  Widget _buildSalesInvoiceScreen(BuildContext context) {
    final matches = _rows.where((row) => _s(row['id']) == _selectedDocumentId);
    final doc = matches.isEmpty ? <String, dynamic>{} : matches.first;
    final hasDraft = doc.isNotEmpty && _s(doc['status']) == 'draft';
    final status = doc.isEmpty ? 'فاتورة جديدة' : hasDraft ? 'مسودة' : _s(doc['status']) == 'posted' ? 'معتمدة / مرحلة' : _s(doc['status']);
    final parties = _parties.where((row) => _s(row['id']) == _partyId);
    final party = parties.isEmpty ? <String, dynamic>{} : parties.first;
    final gross = _pendingGross;
    final lineDiscounts = _pendingLineDiscounts;
    final invoiceDiscount = _invoiceDiscountValue.clamp(0, (gross - lineDiscounts).clamp(0, double.infinity));
    final taxTotal = _isTaxInvoice ? _pendingLines.fold<double>(0, (sum, line) => sum + _n(line['tax'])) : 0.0;
    final net = (gross - lineDiscounts - invoiceDiscount + taxTotal).clamp(0, double.infinity);
    final dateText = _documentDate.day.toString().padLeft(2, '0') + '/' + _documentDate.month.toString().padLeft(2, '0') + '/' + _documentDate.year.toString();
    InputDecoration field(String label, {Widget? suffix}) => InputDecoration(
      labelText: label, suffixIcon: suffix, isDense: true, filled: true, fillColor: const Color(0xFFFCFBFE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFE1D9EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFE1D9EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF3E007D), width: 1.5)),
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.f1) {
              _openItemPicker();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.f5 ||
                (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyS)) {
              if (hasDraft && _pendingLines.isNotEmpty) { _savePendingLines(); }
              else if (doc.isEmpty) { _createDraft(); }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0xFF3E007D), Color(0xFF54209A)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x183E007D), blurRadius: 16, offset: Offset(0, 5))],
            ),
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFFFA015), size: 26)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_salesDocumentTitle(_documentType), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                  const SizedBox(height: 3),
                  const Text('سلسلة • بنربط السوق ببعضه', style: TextStyle(color: Color(0xFFE9DDF8), fontSize: 12)),
                ]),
              ]),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(avatar: const Icon(Icons.circle, size: 9, color: Color(0xFFFFA015)), label: Text(status), backgroundColor: Colors.white, side: BorderSide.none),
                OutlinedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), label: const Text('تحديث')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFA015), foregroundColor: const Color(0xFF241735)),
                  onPressed: _saving ? null : () => setState(() {
                    _selectedDocumentId = null; _pendingLines = []; _lines = []; _documentNumber.clear(); _notes.clear();
                    _invoiceDiscountAmount.text = '0'; _invoiceDiscountPercent.text = '0'; _isTaxInvoice = false; _error = null; _message = null;
                  }),
                  icon: const Icon(Icons.add_rounded), label: Text('${_salesDocumentTitle(_documentType)} جديد'),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          if (_error != null) _notice(_error!, Colors.red),
          if (_message != null) _notice(_message!, Colors.green),
          _invoiceCard('بيانات ${_salesDocumentTitle(_documentType)}', Icons.description_outlined, LayoutBuilder(builder: (context, constraints) {
            final count = constraints.maxWidth > 850 ? 4 : 2;
            final width = (constraints.maxWidth - (count - 1) * 10) / count;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: width, child: TextField(controller: _documentNumber, decoration: field('رقم ${_salesDocumentTitle(_documentType)} *'))),
              SizedBox(width: width, child: InkWell(
                onTap: _saving ? null : () async {
                  final chosen = await showDatePicker(context: context, initialDate: _documentDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (chosen != null && mounted) setState(() => _documentDate = chosen);
                },
                child: InputDecorator(decoration: field('تاريخ الفاتورة', suffix: const Icon(Icons.calendar_month_outlined)),
                  child: Text(dateText, style: const TextStyle(fontWeight: FontWeight.w800))),
              )),
              SizedBox(width: width, child: _invoiceMetric('المسلسل الآلي', doc.isEmpty ? 'يصدر بعد الحفظ' : _s(doc['auto_number']))),
              SizedBox(width: width, child: _invoiceMetric('نوع المستند', _salesDocumentTitle(_documentType))),
              SizedBox(width: width, child: DropdownButtonFormField<String>(
                value: _sourceChannel,
                isExpanded: true,
                decoration: field('مصدر المستند'),
                items: const [
                  DropdownMenuItem(value: 'app', child: Text('التطبيق')),
                  DropdownMenuItem(value: 'manual', child: Text('يدوي')),
                  DropdownMenuItem(value: 'crm', child: Text('علاقات العملاء')),
                  DropdownMenuItem(value: 'documents', child: Text('مستند مصدر')),
                ],
                onChanged: hasDraft || _sourceDocumentIds.isNotEmpty ? null : (value) => setState(() => _sourceChannel = value ?? 'manual'),
              )),
              if (['invoice', 'order'].contains(_documentType))
                SizedBox(width: width, child: OutlinedButton.icon(
                  onPressed: hasDraft || _saving ? null : _pickSourceDocuments,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(_documentType == 'invoice' ? 'جلب أمر بيع F1' : 'جلب عرض سعر F1'),
                )),
              if (_sourceDocumentIds.isNotEmpty)
                SizedBox(width: width, child: _invoiceMetric('المستندات المرتبطة', _sourceDocumentIds.length.toString())),
            ]);
          })),
          const SizedBox(height: 10),
          _invoiceCard('بيانات العميل والبيع', Icons.storefront_outlined, LayoutBuilder(builder: (context, constraints) {
            final count = constraints.maxWidth > 850 ? 4 : 2;
            final width = (constraints.maxWidth - (count - 1) * 10) / count;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: width, child: TextField(
                controller: _partyCode, decoration: field('كود العميل', suffix: const Icon(Icons.search_rounded)),
                onChanged: (code) {
                  final normalized = code.trim().toLowerCase();
                  final found = _parties.where((p) => _s(p['party_code']).trim().toLowerCase() == normalized);
                  if (normalized.isEmpty || found.isEmpty) {
                    setState(() {
                      _partyId = null; _salesRepId = null; _warehouses = List<Map<String, dynamic>>.from(_allWarehouses);
                      if (!_warehouses.any((w) => _s(w['id']) == _warehouseId)) _warehouseId = _warehouses.isEmpty ? null : _s(_warehouses.first['id']);
                    });
                  } else if (found.length == 1 && _partyId != _s(found.first['id'])) {
                    final selected = found.first;
                    setState(() {
                      _partyId = _s(selected['id']);
                      final rep = _s(selected['sales_rep_id']);
                      _salesRepId = rep.isNotEmpty && _representatives.any((r) => _s(r['id']) == rep) ? rep : null;
                      _warehouses = []; _warehouseId = null;
                    });
                    _applyCustomerWarehouseRules(_s(selected['id']));
                  }
                },
                onSubmitted: (code) {
                  final found = _parties.where((p) => _s(p['party_code']).trim().toLowerCase() == code.trim().toLowerCase());
                  if (found.isEmpty) { setState(() => _error = 'كود العميل غير موجود أو العميل غير نشط.'); }
                  else { _onPartyChanged(_s(found.first['id'])); }
                },
              )),
              SizedBox(width: width, child: DropdownButtonFormField<String>(
                value: _parties.any((p) => _s(p['id']) == _partyId) ? _partyId : null, isExpanded: true, decoration: field('اسم العميل'),
                hint: Text(_parties.isEmpty ? 'لا توجد بيانات عملاء نشطة' : 'اختر العميل'),
                items: _parties.map((p) => DropdownMenuItem<String>(value: _s(p['id']), child: Text(_partyLabel(_s(p['id'])), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _parties.isEmpty || hasDraft ? null : _onPartyChanged,
              )),
              SizedBox(width: width, child: DropdownButtonFormField<String>(
                value: _warehouses.any((w) => _s(w['id']) == _warehouseId) ? _warehouseId : null, isExpanded: true, decoration: field('المخزن المسموح للعميل'),
                items: _warehouses.map((w) => DropdownMenuItem<String>(value: _s(w['id']), child: Text(_warehouseLabel(_s(w['id'])), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _warehouses.isEmpty || hasDraft ? null : (value) => setState(() => _warehouseId = value),
              )),
              SizedBox(width: width, child: DropdownButtonFormField<String>(
                value: _representatives.any((r) => _s(r['id']) == _salesRepId) ? _salesRepId : null, isExpanded: true, decoration: field('مندوب المبيعات'),
                items: _representatives.map((r) => DropdownMenuItem<String>(value: _s(r['id']), child: Text(_s(r['rep_code']) + ' — ' + _s(r['rep_name']), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _canChangeSalesRep && !hasDraft ? (value) => setState(() => _salesRepId = value) : null,
              )),
              SizedBox(width: width, child: _invoiceMetric('نوع العميل', _s(party['party_kind']).isEmpty ? '—' : _s(party['party_kind']))),
              SizedBox(width: width, child: _invoiceMetric('مندوب افتراضي', _s(party['sales_rep_id']).isEmpty ? 'غير محدد' : 'مرتبط بملف العميل')),
              SizedBox(width: width, child: _invoiceMetric('المخزن الافتراضي', _warehouseLabel(_s(party['default_warehouse_id'])))),
              SizedBox(width: width, child: _invoiceMetric('حالة العميل', party.isEmpty ? 'لم يتم الاختيار' : 'تم الاختيار')),
            ]);
          })),
          const SizedBox(height: 10),
          _invoiceCard('تفاصيل الأصناف', Icons.inventory_2_outlined, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: _saving || _loading ? null : _openItemPicker, icon: const Icon(Icons.playlist_add_rounded), label: const Text('جلب الأصناف  F1')),
              if (widget.kind == ErpOperationalKind.sales && _documentType == 'invoice') ...[
                FilledButton.tonalIcon(onPressed: _saving || _loading ? null : () => _openCampaignPicker('customer_magazine'), icon: const Icon(Icons.menu_book_outlined), label: const Text('جلب من عروض عملاء')),
                FilledButton.tonalIcon(onPressed: _saving || _loading ? null : () => _openCampaignPicker('promotion'), icon: const Icon(Icons.campaign_outlined), label: const Text('جلب من عروض ترويج')),
                FilledButton.tonalIcon(onPressed: _saving || _loading ? null : () => _openCampaignPicker('slow_moving'), icon: const Icon(Icons.inventory_2_outlined), label: const Text('جلب من عروض رواكد')),
                FilledButton.tonalIcon(onPressed: _saving || _loading ? null : _openCustomerShortages, icon: const Icon(Icons.playlist_remove_outlined), label: const Text('جلب من نواقص عميل')),
              ],
              if (_pendingLines.isNotEmpty) FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFA015), foregroundColor: const Color(0xFF241735)),
                onPressed: _saving || _loading || !hasDraft ? null : _savePendingLines,
                icon: const Icon(Icons.check_circle_outline), label: const Text('حفظ الأصناف المحددة')),
            ]),
            const SizedBox(height: 10),
            if (_pendingLines.isEmpty && _lines.isEmpty)
              Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: const Color(0xFFFAF8FC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8E1F0))),
                child: const Column(children: [
                  Icon(Icons.inventory_2_outlined, size: 34, color: Color(0xFF9B8BAE)),
                  SizedBox(height: 8), Text('لم تتم إضافة أصناف بعد', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 4), Text('اضغط F1 أو زر اختيار الأصناف لفتح نافذة الاختيار.', style: TextStyle(color: Colors.black54, fontSize: 12)),
                ])),
            if (_pendingLines.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
              headingTextStyle: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900, fontSize: 12),
              dataRowMinHeight: 52, dataRowMaxHeight: 62, columnSpacing: 16,
              columns: const [DataColumn(label: Text('م.')), DataColumn(label: Text('الكود')), DataColumn(label: Text('الصنف')), DataColumn(label: Text('الوحدة')), DataColumn(label: Text('الكمية')), DataColumn(label: Text('سعر الوحدة')), DataColumn(label: Text('الخصم')), DataColumn(label: Text('خصم %')), DataColumn(label: Text('الضريبة')), DataColumn(label: Text('الإجمالي')), DataColumn(label: Text(''))],
              rows: List<DataRow>.generate(_pendingLines.length, (index) {
                final line = _pendingLines[index];
                final lineGross = _n(line['quantity']) * _n(line['unit_price']);
                final total = (lineGross - _n(line['discount']) - _invoiceDiscountForLine(index) + _n(line['tax'])).clamp(0, double.infinity);
                final units = _unitsByItem[_s(line['item_id'])] ?? [];
                return DataRow(cells: [
                  DataCell(Text((index + 1).toString())),
                  DataCell(Text(_s(line['item_code']))),
                  DataCell(SizedBox(width: 170, child: Text(_s(line['item_name']), maxLines: 2, overflow: TextOverflow.ellipsis))),
                  DataCell(SizedBox(width: 110, child: DropdownButtonFormField<String>(
                    value: units.any((u) => _s(u['id']) == _s(line['unit_id'])) ? _s(line['unit_id']) : (units.isNotEmpty ? _s(units.first['id']) : null),
                    isDense: true, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 5)),
                    items: units.map((u) => DropdownMenuItem<String>(value: _s(u['id']), child: Text(_s(u['unit_name']).isEmpty ? _s(u['unit_code']) : _s(u['unit_name']), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: units.isEmpty ? null : (value) { if (value != null) _updatePendingLine(index, unitId: value); },
                  ))),
                  DataCell(SizedBox(width: 78, child: TextFormField(key: ValueKey('sale-qty-' + index.toString() + _s(line['item_id'])), initialValue: _money(line['quantity']), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: (v) => _updatePendingLine(index, quantity: double.tryParse(v) ?? 0)))),
                  DataCell(Text(_money(line['unit_price']))),
                  DataCell(SizedBox(width: 82, child: TextFormField(key: ValueKey('sale-disc-' + index.toString() + _s(line['item_id'])), initialValue: _money(line['discount']), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: (v) => _updatePendingLine(index, discountAmount: double.tryParse(v) ?? 0)))),
                  DataCell(SizedBox(width: 75, child: TextFormField(key: ValueKey('sale-discpct-' + index.toString() + _s(line['item_id'])), initialValue: _money(line['discount_percent']), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), onChanged: (v) => _updatePendingLine(index, discountPercent: double.tryParse(v) ?? 0)))),
                  DataCell(Text(_isTaxInvoice ? _money(line['tax']) : '—')),
                  DataCell(Text(_money(total), style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900))),
                  DataCell(IconButton(tooltip: 'حذف من المعاينة', icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _saving ? null : () => setState(() {
                    _pendingLines.removeAt(index);
                    if (_pendingGross <= 0) { _invoiceDiscountAmount.text = '0'; _invoiceDiscountPercent.text = '0'; }
                    else { final p = double.tryParse(_invoiceDiscountPercent.text) ?? 0; _invoiceDiscountAmount.text = (_pendingGross * p / 100).toStringAsFixed(2); }
                    _recalculatePendingTax();
                  }))),
                ]);
              }),
            )),
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('بنود محفوظة في ${_salesDocumentTitle(_documentType)}', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3E007D))),
              ..._lines.map((line) => ListTile(
                dense: true, leading: const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
                title: Text(_itemLabel(_s(line['item_id']))),
                subtitle: Text('الكمية: ' + _s(line['quantity']) + ' ' + _s(line['unit_code']) + ' • سعر الوحدة: ' + _money(line['unit_price']) + ' • الخصم: ' + _money(line['discount_amount'])),
                trailing: Text(_money(line['line_total']) + ' ج.م', style: const TextStyle(fontWeight: FontWeight.w900)),
              )),
            ],
            if (_documentType == 'invoice') CheckboxListTile(value: _isTaxInvoice, dense: true, contentPadding: EdgeInsets.zero, activeColor: const Color(0xFF3E007D),
              title: const Text('فاتورة ضريبية'), subtitle: const Text('غير ضريبية افتراضيًا؛ تُحسب الضريبة وفق بيانات الصنف عند التفعيل.'),
              onChanged: hasDraft ? (v) => setState(() { _isTaxInvoice = v ?? false; _recalculatePendingTax(); }) : null),
          ])),
          const SizedBox(height: 10),
          _invoiceCard('الخصم والملاحظات', Icons.tune_rounded, LayoutBuilder(builder: (context, constraints) {
            final count = constraints.maxWidth > 700 ? 3 : 1;
            final width = (constraints.maxWidth - (count - 1) * 10) / count;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: width, child: TextField(controller: _invoiceDiscountAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: field('خصم الفاتورة بالقيمة'), onChanged: (v) {
                final amount = double.tryParse(v) ?? 0; _invoiceDiscountPercent.text = gross <= 0 ? '0' : (amount * 100 / gross).toStringAsFixed(2); setState(_recalculatePendingTax);
              })),
              SizedBox(width: width, child: TextField(controller: _invoiceDiscountPercent, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: field('خصم الفاتورة %'), onChanged: (v) {
                final percent = (double.tryParse(v) ?? 0).clamp(0, 100); _invoiceDiscountAmount.text = (gross * percent / 100).toStringAsFixed(2); setState(_recalculatePendingTax);
              })),
              SizedBox(width: width, child: TextField(controller: _notes, decoration: field('ملاحظات / بيان الفاتورة'))),
            ]);
          })),
          const SizedBox(height: 10),
          _invoiceCard('ملخص الحسابات', Icons.calculate_outlined, LayoutBuilder(builder: (context, constraints) {
            final count = constraints.maxWidth > 800 ? 5 : 2;
            final width = (constraints.maxWidth - (count - 1) * 10) / count;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: width, child: _invoiceMetric('إجمالي الأصناف', _money(gross) + ' ج.م')),
              SizedBox(width: width, child: _invoiceMetric('خصم الأصناف', _money(lineDiscounts) + ' ج.م')),
              SizedBox(width: width, child: _invoiceMetric('خصم الفاتورة', _money(invoiceDiscount) + ' ج.م')),
              SizedBox(width: width, child: _invoiceMetric('الضريبة', _money(taxTotal) + ' ج.م')),
              SizedBox(width: width, child: _invoiceMetric('صافي الفاتورة', _money(net) + ' ج.م', strong: true)),
            ]);
          })),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _saving || _loading || hasDraft || doc.isNotEmpty ? null : _createDraft, icon: const Icon(Icons.save_outlined), label: Text('حفظ مسودة ${_salesDocumentTitle(_documentType)}')),
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFA015), foregroundColor: const Color(0xFF241735)),
              onPressed: _saving || _loading || !hasDraft || _pendingLines.isEmpty ? null : _savePendingLines, icon: const Icon(Icons.playlist_add_check), label: const Text('حفظ البنود')),
            FilledButton.icon(onPressed: _saving || _loading || !hasDraft ? null : () => _post(doc), icon: const Icon(Icons.verified_outlined), label: const Text('اعتماد المستند')),
            OutlinedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.history_rounded), label: const Text('الفواتير السابقة')),
            OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ErpOperationalAccountMappingsScreen(initialCompanyId: _company.text.trim()))), icon: const Icon(Icons.account_tree_outlined), label: const Text('خريطة الحسابات')),
          ]),
          const SizedBox(height: 10),
          _invoiceCard('إعدادات الاتصال والفواتير السابقة', Icons.settings_suggest_outlined, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _company, decoration: field('معرّف الشركة (UUID)')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _invoiceMetric('عدد الفواتير', _rows.length.toString()),
              _invoiceMetric('المسودات', _rows.where((r) => _s(r['status']) == 'draft').length.toString()),
              _invoiceMetric('المعتمدة / المرحلة', _rows.where((r) => _s(r['status']) == 'posted').length.toString()),
            ]),
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._rows.map((row) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: _s(row['id']) == _selectedDocumentId ? const Color(0xFFF5EFFB) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8E1F0))),
                child: ListTile(
                  dense: true, leading: const Icon(Icons.receipt_outlined, color: Color(0xFF3E007D)),
                  title: Text(_s(row['document_number']) + ' • مسلسل ' + _s(row['auto_number']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(_s(row['document_date']) + ' • ' + _s(row['status']) + ' • ' + _money(row['grand_total']) + ' ج.م'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () async {
                    setState(() {
                      _selectedDocumentId = _s(row['id']); _lines = []; _pendingLines = []; _documentType = _s(row['document_type']);
                      _partyId = _s(row['customer_id']); final p = _parties.where((item) => _s(item['id']) == _partyId);
                      _partyCode.text = p.isEmpty ? '' : _s(p.first['party_code']);
                      _warehouseId = _s(row['warehouse_id']); _documentNumber.text = _s(row['document_number']); _notes.text = _s(row['notes']);
                      _documentDate = DateTime.tryParse(_s(row['document_date'])) ?? _documentDate;
                      _salesRepId = _s(row['sales_rep_id']).isEmpty ? null : _s(row['sales_rep_id']); _isTaxInvoice = row['is_tax_invoice'] == true;
                    });
                    await _loadLines(_s(row['id'])); await _applyCustomerWarehouseRules(_partyId);
                  },
                ),
              )),
            ],
          ])),
          const SizedBox(height: 8),
          const Text('اختصارات: F1 اختيار الأصناف • F5 أو Ctrl+S حفظ المسودة أو الأصناف المحددة • Esc لإغلاق نافذة الاختيار.',
            style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == ErpOperationalKind.sales) {
      return _buildSalesInvoiceScreen(context);
    }
    final draftCount = _rows.where((r) => _s(r['status']) == 'draft').length;
    return Directionality(textDirection: TextDirection.rtl, child: Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1) {
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
            Text(widget.kind == ErpOperationalKind.sales && _documentType == 'invoice' ? 'بيانات رأس فاتورة البيع' : 'إنشاء مستند جديد', style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 8),
            if (widget.kind == ErpOperationalKind.sales && _documentType == 'invoice')
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF5EFFB), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // RTL: date and the selected customer warehouse stay at the upper-right.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saving ? null : () async {
                              final chosen = await showDatePicker(context: context, initialDate: _documentDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (chosen != null && mounted) setState(() => _documentDate = chosen);
                            },
                            icon: const Icon(Icons.calendar_month_outlined, size: 18),
                            label: Text('التاريخ: ${_documentDate.year}-${_documentDate.month.toString().padLeft(2,'0')}-${_documentDate.day.toString().padLeft(2,'0')}'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المخزن الافتراضي / المحدد',
                            style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          DropdownButtonFormField<String>(
                            value: _warehouses.any((row) => _s(row['id']) == _warehouseId) ? _warehouseId : null,
                            isExpanded: true,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                            items: _warehouses.map((row) => DropdownMenuItem<String>(
                              value: _s(row['id']),
                              child: Text(_warehouseLabel(_s(row['id'])), overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (value) => setState(() => _warehouseId = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مسلسل الفاتورة: ${_rows.where((row) => _s(row['id']) == _selectedDocumentId).isEmpty ? 'يُنشأ عند الحفظ' : _s(_rows.where((row) => _s(row['id']) == _selectedDocumentId).first['auto_number'])}',
                            style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'قيمة الأصناف: ${_money(_pendingGross)} ج.م',
                            style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(child: TextField(
                              controller: _invoiceDiscountAmount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'خصم الفاتورة بالقيمة', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                              onChanged: (value) {
                                final subtotal = _pendingGross;
                                final amount = double.tryParse(value) ?? 0;
                                _invoiceDiscountPercent.text = subtotal <= 0 ? '0' : (amount * 100 / subtotal).toStringAsFixed(2);
                                setState(_recalculatePendingTax);
                              },
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: TextField(
                              controller: _invoiceDiscountPercent,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'خصم الفاتورة %', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                              onChanged: (value) {
                                _invoiceDiscountAmount.text = (_pendingGross * ((double.tryParse(value) ?? 0) / 100)).toStringAsFixed(2);
                                setState(_recalculatePendingTax);
                              },
                            )),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextField(controller: _documentNumber, decoration: const InputDecoration(labelText: 'رقم المستند / المسلسل اليدوي *', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 4),
            const Text('المسلسل الآلي يصدر من قاعدة البيانات، ورقم المستند اليدوي يمكن إدخاله هنا.', style: TextStyle(fontSize: 12, color: Colors.black54)),
            if (widget.kind == ErpOperationalKind.sales && _documentType == 'invoice') ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _isTaxInvoice,
                title: const Text('فاتورة ضريبية'),
                subtitle: const Text('الافتراضي فاتورة غير ضريبية؛ عند التفعيل تُحتسب ضريبة الأصناف وفق بياناتها.'),
                onChanged: (value) => setState(() {
                  _isTaxInvoice = value ?? false;
                  _recalculatePendingTax();
                }),
              ),
            ],
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
            if (widget.kind == ErpOperationalKind.sales) ...[
              TextField(
                controller: _partyCode,
                decoration: const InputDecoration(labelText: 'كود العميل', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.person_search_outlined)),
                onChanged: (code) {
                  final normalized = code.trim().toLowerCase();
                  if (normalized.isEmpty) {
                    setState(() {
                      _partyId = null;
                      _salesRepId = null;
                      _warehouses = List<Map<String, dynamic>>.from(_allWarehouses);
                      if (!_warehouses.any((row) => _s(row['id']) == _warehouseId)) {
                        _warehouseId = _warehouses.isEmpty ? null : _s(_warehouses.first['id']);
                      }
                    });
                    return;
                  }
                  final matches = _parties.where((party) => _s(party['party_code']).trim().toLowerCase() == normalized);
                  if (matches.isEmpty) {
                    setState(() {
                      _partyId = null;
                      _salesRepId = null;
                      _warehouses = List<Map<String, dynamic>>.from(_allWarehouses);
                      if (!_warehouses.any((row) => _s(row['id']) == _warehouseId)) {
                        _warehouseId = _warehouses.isEmpty ? null : _s(_warehouses.first['id']);
                      }
                    });
                    return;
                  }
                  if (matches.length == 1) {
                    final party = matches.first;
                    final id = _s(party['id']);
                    if (_partyId != id) {
                      setState(() {
                        _partyId = id;
                        final defaultRep = _s(party['sales_rep_id']);
                        _salesRepId = defaultRep.isNotEmpty && _representatives.any((rep) => _s(rep['id']) == defaultRep)
                            ? defaultRep
                            : null;
                      });
                      _applyCustomerWarehouseRules(id);
                    }
                  }
                },
                onSubmitted: (code) {
                  final matches = _parties.where((party) => _s(party['party_code']).trim().toLowerCase() == code.trim().toLowerCase());
                  if (matches.isEmpty) {
                    setState(() => _error = 'كود العميل غير موجود أو العميل غير نشط.');
                    return;
                  }
                  final party = matches.first;
                  setState(() {
                    _partyId = _s(party['id']);
                    final defaultRep = _s(party['sales_rep_id']);
                    _salesRepId = defaultRep.isNotEmpty && _representatives.any((rep) => _s(rep['id']) == defaultRep)
                        ? defaultRep
                        : null;
                    _error = null;
                  });
                  _applyCustomerWarehouseRules(_s(party['id']));
                },
              ),
              const SizedBox(height: 6),
            ],
            DropdownButtonFormField<String>(
              value: _partyId, isExpanded: true,
              decoration: InputDecoration(labelText: widget.kind == ErpOperationalKind.purchase ? 'المورد' : 'اختيار العميل بالاسم أو الكود', border: const OutlineInputBorder()),
              items: _parties.map((r) => DropdownMenuItem<String>(value: _s(r['id']), child: Text(_partyLabel(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _onPartyChanged,
            ),
            if (widget.kind == ErpOperationalKind.sales) ...[
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: Text(
                'اسم العميل: ${_partyLabel(_partyId)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3E007D)),
              )),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _representatives.any((rep) => _s(rep['id']) == _salesRepId) ? _salesRepId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'مندوب المبيعات', border: OutlineInputBorder(), isDense: true),
                items: _representatives.map((rep) => DropdownMenuItem<String>(
                  value: _s(rep['id']),
                  child: Text('${_s(rep['rep_code'])} — ${_s(rep['rep_name'])}', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: _canChangeSalesRep ? (value) => setState(() => _salesRepId = value) : null,
              ),
              if (!_canChangeSalesRep) const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('تغيير المندوب مقيد بصلاحية تعديل فاتورة المبيعات.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ],
            const SizedBox(height: 8),
            if (!(widget.kind == ErpOperationalKind.sales && _documentType == 'invoice')) ...[
              DropdownButtonFormField<String>(
                value: _warehouses.any((row) => _s(row['id']) == _warehouseId) ? _warehouseId : null, isExpanded: true,
                decoration: const InputDecoration(labelText: 'المخزن', border: OutlineInputBorder()),
                items: _warehouses.map((r) => DropdownMenuItem<String>(value: _s(r['id']), child: Text(_warehouseLabel(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _warehouseId = v),
              ),
              Align(alignment: Alignment.centerRight, child: Text('المخزن المحدد: ${_warehouseLabel(_warehouseId)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3E007D)))),
            ],
            const SizedBox(height: 8),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _saving ? null : _createDraft, icon: const Icon(Icons.add), label: const Text('إنشاء المسودة')),
          ],
        ))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          _metric('المستندات', '${_rows.length}'),
          _metric('جاهز للترحيل', '$draftCount'),          _metric('مرحّل', '${_rows.where((r) => _s(r['status']) == 'posted').length}'),
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
                label: const Text('اختيار عدة أصناف — F1'),
              ),
              if (!(widget.kind == ErpOperationalKind.sales && _documentType == 'invoice')) ...[
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
            ],
          ))),
        if (_selectedDocumentId != null && _pendingLines.isNotEmpty) ...[
          const SizedBox(height: 10),          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Text('جريد معاينة أصناف الفاتورة', style: TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900, fontSize: 16))),
                  Chip(label: Text('${_pendingLines.length} سطر')),
                ]),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF2EAFB)),
                    columns: const [
                      DataColumn(label: Text('م')),
                      DataColumn(label: Text('كود الصنف')),
                      DataColumn(label: Text('اسم الصنف')),
                      DataColumn(label: Text('الكمية')),
                      DataColumn(label: Text('الوحدة')),
                      DataColumn(label: Text('السعر الأساسي')),
                      DataColumn(label: Text('سعر قائمة العميل')),
                      DataColumn(label: Text('سعر البيع المعدل')),
                      DataColumn(label: Text('خصم القيمة')),
                      DataColumn(label: Text('خصم %')),
                      DataColumn(label: Text('نسبة الضريبة')),
                      DataColumn(label: Text('قيمة الضريبة')),
                      DataColumn(label: Text('قيمة الصنف')),
                      DataColumn(label: Text('')),
                    ],
                    rows: List<DataRow>.generate(_pendingLines.length, (index) {
                      final line = _pendingLines[index];
                      final gross = _n(line['quantity']) * _n(line['unit_price']);
                      final total = (gross - _n(line['discount']) - _invoiceDiscountForLine(index) + _n(line['tax'])).clamp(0, double.infinity);
                      return DataRow(cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(_s(line['item_code']))),
                        DataCell(Text(_s(line['item_name']))),
                        DataCell(SizedBox(
                          width: 84,
                          child: TextFormField(
                            key: ValueKey('preview-qty-$index-${_s(line['item_id'])}'),
                            initialValue: _money(line['quantity']),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), border: OutlineInputBorder()),
                            onChanged: (value) => _updatePendingLine(index, quantity: double.tryParse(value) ?? 0),
                          ),
                        )),
                        DataCell(SizedBox(
                          width: 135,
                          child: DropdownButtonFormField<String>(
                            value: (_unitsByItem[_s(line['item_id'])] ?? []).any((unit) => _s(unit['id']) == _s(line['unit_id']))
                                ? _s(line['unit_id'])
                                : ((_unitsByItem[_s(line['item_id'])] ?? []).isNotEmpty ? _s((_unitsByItem[_s(line['item_id'])]!).first['id']) : null),
                            isDense: true,
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6), border: OutlineInputBorder()),
                            items: (_unitsByItem[_s(line['item_id'])] ?? []).map((unit) => DropdownMenuItem<String>(
                              value: _s(unit['id']),
                              child: Text(_s(unit['unit_name']).isEmpty ? _s(unit['unit_code']) : _s(unit['unit_name']), overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (_unitsByItem[_s(line['item_id'])] ?? []).isEmpty ? null : (value) { if (value != null) _updatePendingLine(index, unitId: value); },
                          ),
                        )),
                        DataCell(Text(_money(line['base_price'] ?? line['unit_price']))),
                        DataCell(Text(_money(line['policy_price'] ?? line['unit_price']))),
                        DataCell(Text(_money(line['adjusted_price'] ?? line['unit_price']))),
                        DataCell(SizedBox(
                          width: 95,
                          child: TextFormField(
                            key: ValueKey('preview-disc-$index-${_s(line['item_id'])}'),
                            initialValue: _money(line['discount']),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), border: OutlineInputBorder()),
                            onChanged: (value) => _updatePendingLine(index, discountAmount: double.tryParse(value) ?? 0),
                          ),
                        )),
                        DataCell(SizedBox(
                          width: 78,
                          child: TextFormField(
                            key: ValueKey('preview-disc-pct-$index-${_s(line['item_id'])}'),
                            initialValue: _money(line['discount_percent']),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), border: OutlineInputBorder()),
                            onChanged: (value) => _updatePendingLine(index, discountPercent: double.tryParse(value) ?? 0),
                          ),
                        )),
                        DataCell(Text(_isTaxInvoice ? '${_money(line['tax_rate'])}%' : '—')),
                        DataCell(Text(_isTaxInvoice ? _money(line['tax']) : '—')),
                        DataCell(Text(_money(total), style: const TextStyle(fontWeight: FontWeight.w900))),
                        DataCell(IconButton(
                          tooltip: 'حذف من المعاينة',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: _saving ? null : () => setState(() {
                            _pendingLines.removeAt(index);
                            if (_pendingGross <= 0) {
                              _invoiceDiscountAmount.text = '0';
                              _invoiceDiscountPercent.text = '0';
                            } else {
                              final percent = double.tryParse(_invoiceDiscountPercent.text.trim()) ?? 0;
                              _invoiceDiscountAmount.text = (_pendingGross * percent / 100).toStringAsFixed(2);
                            }
                            _recalculatePendingTax();
                          }),
                        )),
                      ]);
                    }),
                  ),
                ),
                const Divider(),
                Row(children: [
                  const Expanded(child: Text('قيمة الأصناف قبل خصم الفاتورة', style: TextStyle(fontWeight: FontWeight.w900))),
                  Text('${_money(_pendingGross - _pendingLineDiscounts)} ج.م', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Expanded(child: Text('ضريبة الأصناف', style: TextStyle(fontWeight: FontWeight.w700))),
                  Text('${_money(_isTaxInvoice ? _pendingLines.fold<double>(0, (sum, line) => sum + _n(line['tax'])) : 0)} ج.م'),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Expanded(child: Text('خصم الفاتورة', style: TextStyle(fontWeight: FontWeight.w700))),
                  Text('${_money(_invoiceDiscountValue)} ج.م'),
                ]),
                const Divider(),
                Row(children: [
                  const Expanded(child: Text('صافي الإجمالي بالمعاينة', style: TextStyle(fontWeight: FontWeight.w900))),
                  Text(
                    '${_money((_pendingGross - _pendingLineDiscounts - _invoiceDiscountValue + (_isTaxInvoice ? _pendingLines.fold<double>(0, (sum, line) => sum + _n(line['tax'])) : 0)).clamp(0, double.infinity))} ج.م',
                    style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving || _loading ? null : _savePendingLines,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('موافقة وحفظ الأصناف في الفاتورة'),
                ),
                const Text('الأصناف في هذا الجدول معاينة مؤقتة؛ لن تُحفظ إلا بعد الموافقة.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
          ),
        ],
        if (_selectedDocumentId != null && _lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('بنود المستند المحدد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ..._lines.map((line) => Card(child: ListTile(
            title: Text(_itemLabel(_s(line['item_id']))),
            subtitle: Text('الكمية: ' + _s(line['quantity']) + ' ' + _s(line['unit_code']) + ' • الأساس: ' + _money(line['base_quantity']) + ' • السعر: ' + _money(line['unit_price']) +
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
          return Card(color: _s(r['id']) == _selectedDocumentId ? const Color(0xFFF0E8FA) : null, child: InkWell(onTap: () async { setState(() {
            _selectedDocumentId = _s(r['id']);
            _lines = [];
            _pendingLines = [];
            _documentType = _s(r['document_type']);
            _partyId = _s(widget.kind == ErpOperationalKind.purchase ? r['supplier_id'] : r['customer_id']);
            final partyMatches = _parties.where((party) => _s(party['id']) == _partyId);
            _partyCode.text = partyMatches.isEmpty ? '' : _s(partyMatches.first['party_code']);
            _warehouseId = _s(r['warehouse_id']);
            if (_s(r['document_date']).isNotEmpty) _documentDate = DateTime.tryParse(_s(r['document_date'])) ?? _documentDate;
            _salesRepId = _s(r['sales_rep_id']).isEmpty ? null : _s(r['sales_rep_id']);
            _isTaxInvoice = r['is_tax_invoice'] == true;
          }); await _loadLines(_s(r['id'])); }, child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.description_outlined, color: Color(0xFF3E007D)),
                const SizedBox(width: 8),
                Expanded(child: Text('مسلسل آلي ${_s(r['auto_number'])} • رقم المستند ${_s(r['document_number'])}', style: const TextStyle(fontWeight: FontWeight.w900))),
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