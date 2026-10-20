import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErpSalesFulfillmentScreen extends StatefulWidget {
  const ErpSalesFulfillmentScreen({
    super.key,
    required this.companyId,
    required this.kind,
  });

  final String companyId;
  final String kind; // preparation | delivery

  @override
  State<ErpSalesFulfillmentScreen> createState() => _ErpSalesFulfillmentScreenState();
}

class _ErpSalesFulfillmentScreenState extends State<ErpSalesFulfillmentScreen> {
  final _db = Supabase.instance.client;
  final Map<String, TextEditingController> _manualNumbers = {};
  final Map<String, TextEditingController> _weights = {};
  final Map<String, TextEditingController> _loads = {};
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _saved = [];
  List<Map<String, dynamic>> _preparations = [];
  final Set<String> _selectedInvoiceIds = {};
  final Set<String> _selectedPreparationIds = {};
  String _sourceMode = 'preparation';
  bool _loading = false;
  bool _saving = false;
  bool _canDirectLoad = false;
  String? _error;
  String? _message;

  bool get _isPreparation => widget.kind == 'preparation';
  String get _title => _isPreparation ? 'إذن التجهيز' : 'إذن التسليم';
  String _s(dynamic value) => (value ?? '').toString();
  double _n(dynamic value) => value is num ? value.toDouble() : double.tryParse(_s(value)) ?? 0;
  String _money(dynamic value) => _n(value).toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _sourceMode = _isPreparation ? 'invoice' : 'preparation';
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._manualNumbers.values, ..._weights.values, ..._loads.values]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(Map<String, TextEditingController> map, String key, [String initial = '']) {
    return map.putIfAbsent(key, () => TextEditingController(text: initial));
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final result = await _db.from('erp_sales_documents')
          .select('id, auto_number, document_number, document_date, customer_id, grand_total, status')
          .eq('company_id', widget.companyId)
          .eq('document_type', 'invoice')
          .inFilter('status', ['draft', 'approved', 'posted'])
          .order('document_date', ascending: false)
          .limit(1000);
      final parties = await _db.from('erp_parties')
          .select('id, party_name, area, district, governorate')
          .eq('company_id', widget.companyId)
          .eq('is_active', true)
          .limit(3000);
      final saved = await _db.from('erp_sales_fulfillment_documents')
          .select('*')
          .eq('company_id', widget.companyId)
          .eq('kind', widget.kind)
          .order('created_at', ascending: false)
          .limit(1000);
      final prep = _isPreparation ? <Map<String, dynamic>>[] : (await _db
          .from('erp_sales_fulfillment_documents')
          .select('id, invoice_id, manual_number, customer_name, invoice_amount, weight_kg, load_kg, status')
          .eq('company_id', widget.companyId)
          .eq('kind', 'preparation')
          .inFilter('status', ['draft', 'completed'])
          .order('created_at', ascending: false)
          .limit(1000)).map((e) => Map<String, dynamic>.from(e)).toList();
      final userId = _db.auth.currentUser?.id;
      var canDirect = false;
      if (userId != null) {
        final member = await _db.from('erp_company_members')
            .select('member_role')
            .eq('company_id', widget.companyId)
            .eq('user_id', userId)
            .eq('is_active', true)
            .maybeSingle();
        final role = _s(member?['member_role']).toLowerCase();
        canDirect = role == 'owner' || role == 'admin';
        if (!canDirect) {
          final permission = await _db.from('erp_user_permissions')
              .select('allow_access,can_edit')
              .eq('company_id', widget.companyId)
              .eq('user_id', userId)
              .eq('menu_key', 'المبيعات والعملاء::حركات::إذن التسليم')
              .maybeSingle();
          canDirect = permission?['allow_access'] == true && permission?['can_edit'] == true;
        }
      }
      if (!mounted) return;
      setState(() {
        _invoices = result.map((e) => Map<String, dynamic>.from(e)).toList();
        _parties = parties.map((e) => Map<String, dynamic>.from(e)).toList();
        _saved = saved.map((e) => Map<String, dynamic>.from(e)).toList();
        _preparations = prep;
        _canDirectLoad = canDirect;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل مستندات البيع: $e'; });
    }
  }

  String _customer(String? id) {
    final rows = _parties.where((p) => _s(p['id']) == id);
    return rows.isEmpty ? 'عميل غير محدد' : _s(rows.first['party_name']);
  }

  String _area(String? id) {
    final rows = _parties.where((p) => _s(p['id']) == id);
    if (rows.isEmpty) return '—';
    final p = rows.first;
    return [_s(p['area']), _s(p['district']), _s(p['governorate'])]
        .where((v) => v.trim().isNotEmpty).join(' / ').ifEmpty('—');
  }

  Future<void> _pickInvoices() async {
    final chosen = <String>{..._selectedInvoiceIds};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('جلب فواتير البيع — F1'),
        content: SizedBox(width: 700, height: 420, child: Column(children: [
          Row(children: [
            Text('المحدد: ${chosen.length}'),
            const Spacer(),
            TextButton(onPressed: () => setDialogState(() => chosen.addAll(_invoices.map((r) => _s(r['id'])))), child: const Text('تحديد الكل')),
            TextButton(onPressed: () => setDialogState(chosen.clear), child: const Text('مسح التحديد')),
          ]),
          Expanded(child: ListView.builder(
            itemCount: _invoices.length,
            itemBuilder: (context, index) {
              final row = _invoices[index];
              final id = _s(row['id']);
              return CheckboxListTile(
                value: chosen.contains(id),
                title: Text('مسلسل ${_s(row['auto_number'])} • فاتورة ${_s(row['document_number'])}'),
                subtitle: Text('${_customer(_s(row['customer_id']))} • ${_area(_s(row['customer_id']))} • ${_money(row['grand_total'])} ج.م'),
                onChanged: (v) => setDialogState(() { if (v == true) chosen.add(id); else chosen.remove(id); }),
              );
            },
          )),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            setState(() {
              _selectedInvoiceIds
                ..clear()
                ..addAll(chosen);
              for (final id in chosen) {
                final invoice = _invoices.firstWhere((r) => _s(r['id']) == id);
                _controller(_manualNumbers, id);
                _controller(_weights, id, '0');
                _controller(_loads, id, '0');
              }
            });
            Navigator.pop(dialogContext);
          }, child: const Text('اعتماد الاختيار')),
        ],
      )),
    );
  }

  Future<void> _pickPreparations() async {
    final chosen = <String>{..._selectedPreparationIds};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('جلب أذون التجهيز — F1'),
        content: SizedBox(width: 650, height: 400, child: ListView.builder(
          itemCount: _preparations.length,
          itemBuilder: (context, index) {
            final row = _preparations[index];
            final id = _s(row['id']);
            final invoice = _invoices.where((i) => _s(i['id']) == _s(row['invoice_id']));
            final invoiceText = invoice.isEmpty ? _s(row['invoice_id']) : 'فاتورة ${_s(invoice.first['document_number'])}';
            return CheckboxListTile(
              value: chosen.contains(id),
              title: Text('إذن تجهيز ${_s(row['manual_number'])} • $invoiceText'),
              subtitle: Text('${_s(row['customer_name'])} • ${_money(row['invoice_amount'])} ج.م • وزن ${_money(row['weight_kg'])} كجم'),
              onChanged: (v) => setDialogState(() { if (v == true) chosen.add(id); else chosen.remove(id); }),
            );
          },
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            setState(() {
              _selectedPreparationIds..clear()..addAll(chosen);
              _selectedInvoiceIds
                ..clear()
                ..addAll(_preparations.where((p) => chosen.contains(_s(p['id']))).map((p) => _s(p['invoice_id'])));
              for (final id in _selectedInvoiceIds) {
                _controller(_manualNumbers, id);
                _controller(_weights, id, '0');
                _controller(_loads, id, '0');
              }
            });
            Navigator.pop(dialogContext);
          }, child: const Text('اعتماد الاختيار')),
        ],
      )),
    );
  }

  Future<void> _save() async {
    if (_selectedInvoiceIds.isEmpty) {
      setState(() => _error = 'استخدم F1 لاختيار فاتورة أو أكثر.');
      return;
    }
    if (!_isPreparation && _sourceMode == 'direct' && !_canDirectLoad) {
      setState(() => _error = 'التحميل بدون تجهيز يحتاج صلاحية خاصة من شاشة صلاحيات المستخدمين.');
      return;
    }
    for (final invoiceId in _selectedInvoiceIds) {
      if (_controller(_manualNumbers, invoiceId).text.trim().isEmpty) {
        setState(() => _error = 'رقم الإذن اليدوي مطلوب لكل فاتورة.');
        return;
      }
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      for (final invoiceId in _selectedInvoiceIds) {
        final invoice = _invoices.firstWhere((r) => _s(r['id']) == invoiceId);
        final prepIds = _isPreparation ? <String>[] : _selectedPreparationIds.toList();
        await _db.from('erp_sales_fulfillment_documents').upsert({
          'company_id': widget.companyId,
          'kind': widget.kind,
          'invoice_id': invoiceId,
          'source_fulfillment_ids': prepIds,
          'source_mode': _isPreparation ? 'invoice' : _sourceMode,
          'manual_number': _controller(_manualNumbers, invoiceId).text.trim(),
          'customer_name': _customer(_s(invoice['customer_id'])),
          'area_name': _area(_s(invoice['customer_id'])),
          'invoice_amount': _n(invoice['grand_total']),
          'weight_kg': double.tryParse(_controller(_weights, invoiceId).text) ?? 0,
          'load_kg': double.tryParse(_controller(_loads, invoiceId).text) ?? 0,
          'status': 'draft',
          'created_by': _db.auth.currentUser?.id,
        }, onConflict: 'company_id,kind,invoice_id');
      }
      if (mounted) setState(() { _saving = false; _message = 'تم حفظ ${_selectedInvoiceIds.length} إذن بنجاح. أرقام الأذون اليدوية فريدة على مستوى الشركة ونوع الإذن.'; });
      await _load();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'تعذر حفظ الإذن؛ تأكد من عدم تكرار رقم الإذن اليدوي: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1) {
            if (!_isPreparation && _sourceMode == 'preparation') { _pickPreparations(); }
            else { _pickInvoices(); }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Card(color: const Color(0xFF3E007D), child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.local_shipping_outlined, color: Color(0xFFFFA015), size: 32),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const Text('سلسلة • بنربط السوق ببعضه', style: TextStyle(color: Colors.white70)),
              ])),
              IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, color: Colors.white), tooltip: 'تحديث'),
            ]),
          )),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(10), child: Text(_error!, style: const TextStyle(color: Colors.red)))),
          if (_message != null) Card(color: Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(10), child: Text(_message!))),
          if (!_isPreparation) ...[
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('مصدر إذن التسليم', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3E007D))),
              RadioListTile<String>(value: 'preparation', groupValue: _sourceMode, title: const Text('إذن تجهيز أو أكثر'), onChanged: (v) => setState(() { _sourceMode = v!; _selectedInvoiceIds.clear(); _selectedPreparationIds.clear(); })),
              RadioListTile<String>(value: 'direct', groupValue: _sourceMode, title: const Text('تحميل بدون تجهيز'), subtitle: Text(_canDirectLoad ? 'متاح بصلاحيتك' : 'مقيد بصلاحية خاصة'), onChanged: _canDirectLoad ? (v) => setState(() { _sourceMode = v!; _selectedInvoiceIds.clear(); _selectedPreparationIds.clear(); }) : null),
              OutlinedButton.icon(onPressed: _loading ? null : (_sourceMode == 'preparation' ? _pickPreparations : _pickInvoices), icon: const Icon(Icons.file_open_outlined), label: Text(_sourceMode == 'preparation' ? 'جلب أذون التجهيز F1' : 'جلب فواتير البيع F1')),
            ]))),
          ],
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(_isPreparation ? 'الفواتير المطلوب تجهيزها' : 'الفواتير المطلوب تسليمها', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
              FilledButton.tonalIcon(onPressed: _loading ? null : (!_isPreparation && _sourceMode == 'preparation' ? _pickPreparations : _pickInvoices), icon: const Icon(Icons.search), label: const Text('جلب فواتير F1')),
            ]),
            const SizedBox(height: 8),
            if (_selectedInvoiceIds.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('لم يتم اختيار فواتير. اضغط F1 لجلب الفواتير أو أذون التجهيز.', textAlign: TextAlign.center)),
            if (_selectedInvoiceIds.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              columns: const [
                DataColumn(label: Text('مسلسل الفاتورة')),
                DataColumn(label: Text('اسم العميل')),
                DataColumn(label: Text('المنطقة')),
                DataColumn(label: Text('قيمة الفاتورة')),
                DataColumn(label: Text('الوزن كجم')),
                DataColumn(label: Text('الحمولة كجم')),
                DataColumn(label: Text('رقم الإذن اليدوي *')),
              ],
              rows: _selectedInvoiceIds.map((id) {
                final invoice = _invoices.firstWhere((r) => _s(r['id']) == id);
                return DataRow(cells: [
                  DataCell(Text(_s(invoice['auto_number']).isEmpty ? _s(invoice['document_number']) : _s(invoice['auto_number']))),
                  DataCell(SizedBox(width: 180, child: Text(_customer(_s(invoice['customer_id'])), overflow: TextOverflow.ellipsis))),
                  DataCell(SizedBox(width: 150, child: Text(_area(_s(invoice['customer_id'])), overflow: TextOverflow.ellipsis))),
                  DataCell(Text('${_money(invoice['grand_total'])} ج.م')),
                  DataCell(SizedBox(width: 95, child: TextField(controller: _controller(_weights, id, '0'), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                  DataCell(SizedBox(width: 95, child: TextField(controller: _controller(_loads, id, '0'), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))),
                  DataCell(SizedBox(width: 145, child: TextField(controller: _controller(_manualNumbers, id), decoration: const InputDecoration(isDense: true, hintText: 'رقم غير مكرر', border: OutlineInputBorder())))),
                ]);
              }).toList(),
            )),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _saving || _loading ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ $_title')),
          ]))),
          const SizedBox(height: 8),
          const Text('الأذون المحفوظة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ..._saved.map((row) => Card(child: ListTile(
            leading: Icon(_isPreparation ? Icons.inventory_2_outlined : Icons.local_shipping_outlined, color: const Color(0xFF3E007D)),
            title: Text('${_title} رقم ${_s(row['manual_number'])} • مسلسل فاتورة ${_s(row['invoice_id'])}'),
            subtitle: Text('${_s(row['customer_name'])} • ${_s(row['area_name'])} • ${_money(row['invoice_amount'])} ج.م • وزن ${_money(row['weight_kg'])} كجم • حمولة ${_money(row['load_kg'])} كجم'),
          ))),
        ]),
      ),
    );
  }
}

extension _StringIfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
