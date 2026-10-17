import 'package:flutter/material.dart';
import '../services/erp_operational_documents_repository.dart';

class ErpOperationalDocumentsScreen extends StatefulWidget {
  const ErpOperationalDocumentsScreen({
    super.key,
    this.initialCompanyId,
    this.kind = ErpOperationalKind.purchase,
  });
  final String? initialCompanyId;
  final ErpOperationalKind kind;

  @override
  State<ErpOperationalDocumentsScreen> createState() => _ErpOperationalDocumentsScreenState();
}

class _ErpOperationalDocumentsScreenState extends State<ErpOperationalDocumentsScreen> {
  final _repo = ErpOperationalDocumentsRepository();
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
  }
  @override
  void dispose() {
    _company.dispose(); _documentNumber.dispose(); _notes.dispose(); _quantity.dispose();
    _unitPrice.dispose(); _discount.dispose(); _tax.dispose(); super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة أولًا.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
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
      setState(() { _saving = false; _selectedDocumentId = id; _message = 'تم إنشاء مسودة المستند. أضف البنود ثم رحّلها.'; });
      await _load();
      if (mounted) setState(() => _selectedDocumentId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر إنشاء المسودة: $e'; });
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
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة البند: $e'; });
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
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر ترحيل المستند: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftCount = _rows.where((r) => ['draft','approved'].contains(_s(r['status']))).length;
    return Directionality(textDirection: TextDirection.rtl, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_title, style: const TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('عرض المستندات المسجلة وترحيل المستندات المؤهلة إلى دفتر المخزون من خلال معاملة خادمية واحدة.',
          style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 12),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل المستندات')),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),

        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إنشاء مستند جديد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 8),
            TextField(controller: _documentNumber, decoration: const InputDecoration(labelText: 'رقم المستند *', border: OutlineInputBorder())),
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
              FilledButton.icon(onPressed: _saving ? null : _addLine, icon: const Icon(Icons.playlist_add), label: const Text('إضافة البند')),
            ],
          ))),
        ..._rows.map((r) {
          final status = _s(r['status']);
          final type = _s(r['document_type']);
          final eligibleType = widget.kind == ErpOperationalKind.purchase
              ? ['receipt','invoice','return'].contains(type)
              : ['delivery','invoice','return'].contains(type);
          final canPost = ['draft','approved'].contains(status) && eligibleType;
          final date = _s(r['document_date']);
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
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
              if (!canPost && ['draft','approved'].contains(status)) const Padding(padding: EdgeInsets.only(top: 6), child: Text('هذا النوع لا ينشئ حركة مخزنية مباشرة، لذلك لا يظهر له زر الترحيل هنا.', style: TextStyle(color: Colors.black54, fontSize: 12))),
              if (canPost) Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
                onPressed: _loading ? null : () => _post(r),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('ترحيل وتسجيل حركة المخزون'),
              )),
            ],
          )));
        }),
      ],
    ));
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
