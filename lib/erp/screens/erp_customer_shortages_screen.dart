import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/erp_quick_task_button.dart';

class ErpCustomerShortagesScreen extends StatefulWidget {
  const ErpCustomerShortagesScreen({super.key, this.companyId});
  final String? companyId;

  @override
  State<ErpCustomerShortagesScreen> createState() => _ErpCustomerShortagesScreenState();
}

class _ErpCustomerShortagesScreenState extends State<ErpCustomerShortagesScreen> {
  SupabaseClient? _db;
  String? _companyId;
  String? _customerId;
  String _status = 'all';
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  bool _loading = false;
  bool _saving = false;
  int _loadGeneration = 0;
  String? _error;
  String? _message;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _shortages = [];

  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) { _error = 'تعذر الاتصال بقاعدة البيانات.'; }
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpCustomerShortagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  @override
  Widget build(BuildContext context) {
    final customerNames = {for (final c in _customers) _s(c['id']): _s(c['party_name'])};
    final itemNames = {for (final i in _items) _s(i['id']): _s(i['item_name'])};
    final filtered = _filteredShortages;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: const Color(0xFF3E007D),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Row(children: [
                  Icon(Icons.playlist_remove_rounded, color: Color(0xFFFFA015), size: 26),
                  SizedBox(width: 8),
                  Expanded(child: Text('نواقص العملاء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21))),
                ]),
                const SizedBox(height: 8),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                  _task('تحديث', Icons.refresh, Colors.blue, _load),
                  _task('نسخ CSV لـ Excel', Icons.table_view, const Color(0xFF168447), _exportCsv),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null) _notice(_error!, true),
          if (_message != null) _notice(_message!, false),
          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 230, child: DropdownButtonFormField<String?>(
                value: _customerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'العميل', border: OutlineInputBorder(), isDense: true),
                items: [const DropdownMenuItem<String?>(value: null, child: Text('كل العملاء')), ..._customers.map((c) => DropdownMenuItem<String?>(value: _s(c['id']), child: Text(_s(c['party_name']), overflow: TextOverflow.ellipsis)))],
                onChanged: (v) => setState(() => _customerId = v),
              )),
              SizedBox(width: 170, child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كل الحالات')),
                  DropdownMenuItem(value: 'open', child: Text('مفتوح')),
                  DropdownMenuItem(value: 'partial', child: Text('منفذ جزئيًا')),
                  DropdownMenuItem(value: 'closed', child: Text('مغلق')),
                  DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'all'),
              )),
              SizedBox(width: 160, child: OutlinedButton.icon(onPressed: () => _chooseDate(true), icon: const Icon(Icons.calendar_month), label: Text('من ${_date(_from)}'))),
              SizedBox(width: 160, child: OutlinedButton.icon(onPressed: () => _chooseDate(false), icon: const Icon(Icons.event), label: Text('إلى ${_date(_to)}'))),
              SizedBox(width: 220, child: TextField(controller: _searchController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'بحث بالصنف أو العميل أو رقم المستند', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true))),
              OutlinedButton.icon(onPressed: () { setState(() { _customerId = null; _status = 'all'; _from = DateTime(DateTime.now().year, DateTime.now().month, 1); _to = DateTime.now(); _searchController.clear(); }); _load(); }, icon: const Icon(Icons.restart_alt), label: const Text('إعادة ضبط')),
            ]),
          )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('عدد السجلات: ${filtered.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3E007D)))),
            Text('مفتوح: ${filtered.where((r) => _s(r['status']) == 'open').length}  •  جزئي: ${filtered.where((r) => _s(r['status']) == 'partial').length}', style: const TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          if (_loading) const LinearProgressIndicator(),
          Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
            columns: const [
              DataColumn(label: Text('العميل')),
              DataColumn(label: Text('الصنف')),
              DataColumn(label: Text('رقم المستند')),
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('المطلوب')),
              DataColumn(label: Text('المنفذ')),
              DataColumn(label: Text('المتبقي')),
              DataColumn(label: Text('الحالة')),
              DataColumn(label: Text('إجراءات')),
            ],
            rows: filtered.map((r) {
              final requested = _n(r['requested_quantity']);
              final fulfilled = _n(r['fulfilled_quantity']);
              final status = _s(r['status']);
              return DataRow(cells: [
                DataCell(Text(customerNames[_s(r['customer_id'])] ?? 'عميل غير معروف')),
                DataCell(Text(itemNames[_s(r['item_id'])] ?? 'صنف غير معروف')),
                DataCell(Text(_s(r['source_document_number']).isEmpty ? '—' : _s(r['source_document_number']))),
                DataCell(Text(_s(r['source_date']))),
                DataCell(Text(requested.toStringAsFixed(2))),
                DataCell(Text(fulfilled.toStringAsFixed(2))),
                DataCell(Text((requested - fulfilled).clamp(0, double.infinity).toStringAsFixed(2))),
                DataCell(Chip(label: Text(_statusLabel(status)), backgroundColor: status == 'open' ? const Color(0xFFFFE6E6) : status == 'partial' ? const Color(0xFFFFF0D8) : const Color(0xFFE7F5EB))),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'تعديل الكمية المنفذة', onPressed: _saving || status == 'closed' || status == 'cancelled' ? null : () => _editFulfilled(r), icon: const Icon(Icons.edit_outlined, color: Color(0xFF3E007D))),
                  IconButton(tooltip: 'حذف النقص', onPressed: _saving ? null : () => _delete(r), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                ])),
              ]);
            }).toList(),
          ))),
          if (!_loading && filtered.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد نواقص مطابقة للفلاتر المحددة.'))),
        ],
      ),
    );
  }

  final TextEditingController _searchController = TextEditingController();
  String get _search => _searchController.text;

  List<Map<String, dynamic>> get _filteredShortages {
    final customerNames = {for (final c in _customers) _s(c['id']): _s(c['party_name'])};
    final itemNames = {for (final i in _items) _s(i['id']): _s(i['item_name'])};
    final query = _search.toLowerCase().trim();
    return _shortages.where((r) {
      if (_customerId != null && _s(r['customer_id']) != _customerId) return false;
      if (_status != 'all' && _s(r['status']) != _status) return false;
      final item = itemNames[_s(r['item_id'])] ?? '';
      final customer = customerNames[_s(r['customer_id'])] ?? '';
      return query.isEmpty || item.toLowerCase().contains(query) ||
          customer.toLowerCase().contains(query) ||
          _s(r['source_document_number']).toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final db = _db;
    if (db == null) { if (mounted) setState(() => _error = 'Supabase غير مهيأ.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      var company = (widget.companyId ?? '').trim();
      if (company.isEmpty) {
        final userId = db.auth.currentUser?.id;
        if (userId != null) {
          final memberships = await db.from('erp_company_members').select('company_id').eq('user_id', userId).eq('is_active', true).order('created_at').limit(1);
          if (!mounted || generation != _loadGeneration) return;
          if (memberships.isNotEmpty) company = _s(memberships.first['company_id']).trim();
        }
      }
      if (company.isEmpty) throw StateError('لا توجد شركة نشطة مرتبطة بالمستخدم.');
      final results = await Future.wait<dynamic>([
        db.from('erp_parties').select('id,party_name,party_code').eq('company_id', company).eq('is_active', true).inFilter('party_kind', ['customer','both']).order('party_name').limit(2000),
        db.from('erp_items').select('id,item_name,item_code').eq('company_id', company).order('item_name').limit(3000),
        db.from('erp_customer_shortages').select('id,company_id,customer_id,item_id,source_document_id,source_document_number,source_date,requested_quantity,fulfilled_quantity,status,created_at,closed_at').eq('company_id', company).gte('source_date', _date(_from)).lte('source_date', _date(_to)).order('source_date', ascending: false).order('created_at', ascending: false).limit(2000),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _companyId = company;
        _customers = (results[0] as List).map((v) => Map<String, dynamic>.from(v)).toList();
        _items = (results[1] as List).map((v) => Map<String, dynamic>.from(v)).toList();
        _shortages = (results[2] as List).map((v) => Map<String, dynamic>.from(v)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _loadGeneration) setState(() { _loading = false; _error = 'تعذر تحميل نواقص العملاء: $e'; });
    }
  }

  Future<void> _chooseDate(bool start) async {
    final selected = await showDatePicker(context: context, initialDate: start ? _from : _to, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (selected == null || !mounted) return;
    setState(() { if (start) { _from = selected; if (_to.isBefore(_from)) _to = _from; } else { _to = selected; if (_to.isBefore(_from)) _from = _to; } });
    await _load();
  }

  Future<void> _editFulfilled(Map<String, dynamic> row) async {
    final controller = TextEditingController(text: _n(row['fulfilled_quantity']).toString());
    final value = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تعديل الكمية المنفذة'),
      content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))], decoration: const InputDecoration(labelText: 'الكمية المنفذة', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { final v = double.tryParse(controller.text.trim()); if (v != null) Navigator.pop(ctx, v); }, child: const Text('حفظ'))],
    ));
    controller.dispose();
    if (value == null) return;
    final requested = _n(row['requested_quantity']);
    if (value < 0 || value > requested) { setState(() => _error = 'الكمية المنفذة يجب أن تكون بين صفر والكمية المطلوبة.'); return; }
    final status = value == 0 ? 'open' : value >= requested ? 'closed' : 'partial';
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _db!.from('erp_customer_shortages').update({'fulfilled_quantity': value, 'status': status, 'closed_at': status == 'closed' ? DateTime.now().toIso8601String() : null}).eq('company_id', _companyId!).eq('id', _s(row['id']));
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم تحديث النقص وحالته.'; });
      await _load();
    } catch (e) { if (mounted) setState(() { _saving = false; _error = 'تعذر تحديث النقص: $e'; }); }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد حذف النقص'),
      content: const Text('هل تريد حذف سجل النقص المحدد نهائيًا؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، احذف'))],
    ));
    if (yes != true || _companyId == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _db!.from('erp_customer_shortages').delete().eq('company_id', _companyId!).eq('id', _s(row['id']));
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم حذف سجل النقص.'; });
      await _load();
    } catch (e) { if (mounted) setState(() { _saving = false; _error = 'تعذر حذف النقص: $e'; }); }
  }

  Future<void> _exportCsv() async {
    final customerNames = {for (final c in _customers) _s(c['id']): _s(c['party_name'])};
    final itemNames = {for (final i in _items) _s(i['id']): _s(i['item_name'])};
    final rows = <List<String>>[
      ['العميل','الصنف','رقم المستند','التاريخ','المطلوب','المنفذ','المتبقي','الحالة'],
      ..._filteredShortages.map((r) {
        final requested = _n(r['requested_quantity']);
        final fulfilled = _n(r['fulfilled_quantity']);
        return [customerNames[_s(r['customer_id'])] ?? '', itemNames[_s(r['item_id'])] ?? '', _s(r['source_document_number']), _s(r['source_date']), requested.toString(), fulfilled.toString(), (requested-fulfilled).clamp(0,double.infinity).toString(), _statusLabel(_s(r['status']))];
      }),
    ];
    final csv = rows.map((row) => row.map((v) => '"${v.replaceAll('"','""')}"').join(',')).join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) setState(() => _message = 'تم نسخ CSV إلى الحافظة؛ الصقه في Excel.');
  }

  String _statusLabel(String status) => switch (status) { 'open' => 'مفتوح', 'partial' => 'منفذ جزئيًا', 'closed' => 'مغلق', 'cancelled' => 'ملغي', _ => status };
  Widget _notice(String text, bool error) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: error ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(text, style: TextStyle(color: error ? Colors.red.shade900 : Colors.green.shade900)));
  Widget _task(String label, IconData icon, Color color, VoidCallback action) => Padding(padding: const EdgeInsetsDirectional.only(end: 7), child: ErpQuickTaskButton(label: label, icon: icon, fallbackColor: color, onPressed: action));
}
