import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_keyboard_navigation.dart';

const _paymentPurple = Color(0xFF3E007D);
const _paymentOrange = Color(0xFFFFA015);

class ErpPaymentMethodsScreen extends StatefulWidget {
  const ErpPaymentMethodsScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpPaymentMethodsScreen> createState() => _ErpPaymentMethodsScreenState();
}

class _ErpPaymentMethodsScreenState extends State<ErpPaymentMethodsScreen> {
  SupabaseClient? _db;
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _cashboxes = [];
  String _type = 'cash';
  String? _cashboxId;
  String? _editingId;
  String? _selectedId;
  bool _allowReceipts = true;
  bool _allowPayments = true;
  bool _requiresReference = false;
  bool _active = true;
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _message;

  static const _types = <String, String>{
    'cash': 'نقدي',
    'bank_transfer': 'تحويل بنكي',
    'cheque': 'شيك',
    'card': 'بطاقة بنكية',
    'e_wallet': 'محفظة إلكترونية',
    'credit': 'آجل',
  };

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpPaymentMethodsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _search.dispose();
    super.dispose();
  }

  String _s(dynamic value) => (value ?? '').toString();

  Future<void> _load() async {
    final company = (widget.companyId ?? '').trim();
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    if (company.isEmpty || _db == null) {
      setState(() { _loading = false; _error = 'اختر الشركة النشطة وتأكد من تسجيل الدخول.'; });
      return;
    }
    try {
      final results = await Future.wait([
        _db!.from('erp_payment_methods')
            .select('id,payment_method_code,name_ar,name_en,method_type,cashbox_id,allow_receipts,allow_payments,requires_reference,is_active')
            .eq('company_id', company).order('payment_method_code'),
        _db!.from('erp_cashboxes')
            .select('id,cashbox_code,cashbox_name,is_bank_account')
            .eq('company_id', company).eq('is_active', true).order('cashbox_code'),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(results[0] as List);
        _cashboxes = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل طرق الدفع: $e'; });
    }
  }

  void _clear() {
    _editingId = null;
    _nameAr.clear();
    _nameEn.clear();
    _type = 'cash';
    _cashboxId = null;
    _allowReceipts = true;
    _allowPayments = true;
    _requiresReference = false;
    _active = true;
  }

  void _startNew() {
    if (_saving) return;
    setState(() { _clear(); _editing = true; _error = null; _message = null; });
  }

  void _edit(Map<String, dynamic> row) {
    setState(() {
      _editing = true;
      _selectedId = _s(row['id']);
      _editingId = _s(row['id']);
      _nameAr.text = _s(row['name_ar']);
      _nameEn.text = _s(row['name_en']);
      _type = _types.containsKey(_s(row['method_type'])) ? _s(row['method_type']) : 'cash';
      _cashboxId = _s(row['cashbox_id']).isEmpty ? null : _s(row['cashbox_id']);
      _allowReceipts = row['allow_receipts'] == true;
      _allowPayments = row['allow_payments'] == true;
      _requiresReference = row['requires_reference'] == true;
      _active = row['is_active'] == true;
      _error = null;
      _message = null;
    });
  }

  Future<void> _save() async {
    final company = (widget.companyId ?? '').trim();
    final ar = _nameAr.text.trim();
    if (!_editing) { setState(() => _error = 'اضغط إضافة أو تعديل أولًا.'); return; }
    if (company.isEmpty || _db == null) { setState(() => _error = 'لا توجد شركة نشطة أو اتصال بقاعدة البيانات.'); return; }
    if (ar.isEmpty) { setState(() => _error = 'اسم طريقة الدفع بالعربية مطلوب.'); return; }
    if (!_allowReceipts && !_allowPayments) { setState(() => _error = 'حدد استخدام طريقة الدفع في القبض أو الصرف على الأقل.'); return; }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final payload = <String, dynamic>{
        'company_id': company,
        'name_ar': ar,
        'name_en': _nameEn.text.trim(),
        'method_type': _type,
        'cashbox_id': _cashboxId,
        'allow_receipts': _allowReceipts,
        'allow_payments': _allowPayments,
        'requires_reference': _requiresReference,
        'is_active': _active,
      };
      if (_editingId == null) {
        await _db!.from('erp_payment_methods').insert(payload);
      } else {
        await _db!.from('erp_payment_methods').update(payload)
            .eq('id', _editingId!).eq('company_id', company);
      }
      if (!mounted) return;
      setState(() { _saving = false; _editing = false; _clear(); _message = 'تم حفظ طريقة الدفع.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر حفظ طريقة الدفع. تحقق من عدم تكرار الاسم والصلاحيات. $e'; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    final next = row['is_active'] != true;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(next ? 'تفعيل طريقة الدفع' : 'إيقاف طريقة الدفع'),
      content: Text(next ? 'هل تريد تفعيل طريقة الدفع؟' : 'سيتم إخفاؤها من الاختيارات الجديدة مع الاحتفاظ بالمستندات السابقة. هل تريد المتابعة؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
      ],
    ));
    if (yes != true || _db == null) return;
    try {
      await _db!.from('erp_payment_methods').update({'is_active': next})
          .eq('id', _s(row['id'])).eq('company_id', (widget.companyId ?? '').trim());
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تغيير الحالة: $e');
    }
  }

  Map<String, dynamic>? _rowById(String? id) {
    if (id == null) return null;
    for (final row in _rows) {
      if (_s(row['id']) == id) return row;
    }
    return null;
  }

  String _cashboxName(String? id) {
    if (id == null) return 'غير مرتبط';
    for (final row in _cashboxes) {
      if (_s(row['id']) == id) return '${_s(row['cashbox_code'])} — ${_s(row['cashbox_name'])}';
    }
    return 'غير مرتبط';
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) => [
      _s(r['payment_method_code']), _s(r['name_ar']), _s(r['name_en']), _types[_s(r['method_type'])] ?? ''
    ].join(' ').toLowerCase().contains(q)).toList(growable: false);
  }

  Widget _field(TextEditingController controller, String label) => TextField(
    controller: controller, enabled: _editing,
    decoration: InputDecoration(labelText: label, isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
  );

  Widget _task(String label, IconData icon, Color color, VoidCallback? onPressed) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: onPressed, fallbackColor: color);

  @override
  Widget build(BuildContext context) => ErpKeyboardActionRegistrar(
    add: _startNew, save: _save,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(color: _paymentPurple, child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [
                Icon(Icons.payments_outlined, color: _paymentOrange, size: 27),
                SizedBox(width: 9),
                Expanded(child: Text('دليل طرق الدفع', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _task('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
                _task(_editing ? 'حفظ' : 'إضافة', _editing ? Icons.save : Icons.add, const Color(0xFF168447), _saving ? null : (_editing ? _save : _startNew)),
                _task('تعديل', Icons.edit, const Color(0xFFEF9B13), _editing || _selectedId == null ? null : () { final row = _rowById(_selectedId); if (row != null) _edit(row); }),
                _task('إيقاف/تفعيل', Icons.toggle_on, const Color(0xFFEF9B13), _selectedId == null ? null : () { final row = _rows.where((r) => _s(r['id']) == _selectedId).firstOrNull; if (row != null) _toggle(row); }),
                _task('معاينة', Icons.visibility, const Color(0xFF6841A5), () => setState(() {})),
              ])),
            ]),
          )),
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Expanded(flex: 2, child: _field(_nameAr, 'اسم طريقة الدفع عربي *')),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _field(_nameEn, 'اسم طريقة الدفع إنجليزي')),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: DropdownButtonFormField<String>(
                  value: _type, isExpanded: true, decoration: const InputDecoration(labelText: 'نوع الطريقة', border: OutlineInputBorder(), isDense: true),
                  items: _types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: _editing ? (v) => setState(() => _type = v ?? 'cash') : null,
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(flex: 2, child: DropdownButtonFormField<String?>(
                  value: _cashboxId, isExpanded: true, decoration: const InputDecoration(labelText: 'الخزينة / الحساب البنكي المرتبط', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('بدون ربط')),
                    ..._cashboxes.map((r) => DropdownMenuItem<String?>(value: _s(r['id']), child: Text('${_s(r['cashbox_code'])} — ${_s(r['cashbox_name'])}', overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: _editing ? (v) => setState(() => _cashboxId = v) : null,
                )),
                const SizedBox(width: 8),
                Expanded(child: CheckboxListTile(
                  dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('يستخدم في القبض', style: TextStyle(fontSize: 12)),
                  value: _allowReceipts, onChanged: _editing ? (v) => setState(() => _allowReceipts = v ?? false) : null,
                )),
                Expanded(child: CheckboxListTile(
                  dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('يستخدم في الصرف', style: TextStyle(fontSize: 12)),
                  value: _allowPayments, onChanged: _editing ? (v) => setState(() => _allowPayments = v ?? false) : null,
                )),
              ]),
              Row(children: [
                Expanded(child: CheckboxListTile(
                  dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('يتطلب رقم مرجعي', style: TextStyle(fontSize: 12)),
                  value: _requiresReference, onChanged: _editing ? (v) => setState(() => _requiresReference = v ?? false) : null,
                )),
                Expanded(child: CheckboxListTile(
                  dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('نشط', style: TextStyle(fontSize: 12)),
                  value: _active, onChanged: _editing ? (v) => setState(() => _active = v ?? false) : null,
                )),
                const Spacer(),
                FilledButton.icon(onPressed: _editing && !_saving ? _save : null, icon: const Icon(Icons.save), label: Text(_saving ? 'جارٍ الحفظ' : 'حفظ')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _editing ? () => setState(() { _clear(); _editing = false; _error = null; }) : null, child: const Text('إلغاء')),
              ]),
              if (_error != null) Align(alignment: Alignment.centerRight, child: Text(_error!, style: const TextStyle(color: Colors.red))),
              if (_message != null) Align(alignment: Alignment.centerRight, child: Text(_message!, style: const TextStyle(color: Colors.green))),
            ]),
          )),
          const SizedBox(height: 10),
          TextField(controller: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'بحث في طرق الدفع', border: OutlineInputBorder(), isDense: true), onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) :
            _filtered.isEmpty ? Center(child: Text(_error ?? 'لا توجد طرق دفع مطابقة.')) :
            Card(clipBehavior: Clip.antiAlias, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
              columns: const [
                DataColumn(label: Text('م')), DataColumn(label: Text('الكود')),
                DataColumn(label: Text('اسم الطريقة')), DataColumn(label: Text('النوع')),
                DataColumn(label: Text('الخزينة المرتبطة')), DataColumn(label: Text('القبض')),
                DataColumn(label: Text('الصرف')), DataColumn(label: Text('مرجع')),
                DataColumn(label: Text('الحالة')), DataColumn(label: Text('إجراءات')),
              ],
              rows: [
                for (var i = 0; i < _filtered.length; i++)
                  DataRow(selected: _s(_filtered[i]['id']) == _selectedId, onSelectChanged: (selected) => setState(() { _selectedId = selected == true ? _s(_filtered[i]['id']) : null; }), cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text(_s(_filtered[i]['payment_method_code']))),
                    DataCell(Text(_s(_filtered[i]['name_ar']))),
                    DataCell(Text(_types[_s(_filtered[i]['method_type'])] ?? _s(_filtered[i]['method_type']))),
                    DataCell(Text(_cashboxName(_s(_filtered[i]['cashbox_id']).isEmpty ? null : _s(_filtered[i]['cashbox_id'])))),
                    DataCell(Icon(_filtered[i]['allow_receipts'] == true ? Icons.check_circle : Icons.remove_circle_outline, color: _filtered[i]['allow_receipts'] == true ? Colors.green : Colors.grey, size: 18)),
                    DataCell(Icon(_filtered[i]['allow_payments'] == true ? Icons.check_circle : Icons.remove_circle_outline, color: _filtered[i]['allow_payments'] == true ? Colors.green : Colors.grey, size: 18)),
                    DataCell(Text(_filtered[i]['requires_reference'] == true ? 'نعم' : 'لا')),
                    DataCell(Text(_filtered[i]['is_active'] == true ? 'نشطة' : 'موقوفة')),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'تعديل', onPressed: () => _edit(_filtered[i]), icon: const Icon(Icons.edit_outlined, color: _paymentPurple)),
                      IconButton(tooltip: 'تفعيل/إيقاف', onPressed: () => _toggle(_filtered[i]), icon: Icon(_filtered[i]['is_active'] == true ? Icons.toggle_on : Icons.toggle_off, color: _paymentOrange)),
                    ])),
                  ]),
              ],
            )))),
          ),
        ]),
      ),
    ),
  );
}
