import 'package:flutter/material.dart';
import '../services/erp_parties_repository.dart';

class ErpPartiesScreen extends StatefulWidget {
  const ErpPartiesScreen({super.key, this.initialCompanyId, this.initialKind = 'both'});
  final String? initialCompanyId;
  final String initialKind;
  @override
  State<ErpPartiesScreen> createState() => _ErpPartiesScreenState();
}

class _ErpPartiesScreenState extends State<ErpPartiesScreen> {
  final _repo = ErpPartiesRepository();
  final _company = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _governorate = TextEditingController();
  final _district = TextEditingController();
  final _center = TextEditingController();
  final _area = TextEditingController();
  final _customerType = TextEditingController();
  final _creditLimit = TextEditingController(text: '0');
  final _openingBalance = TextEditingController(text: '0');
  String _kind = 'customer';
  String _filter = 'both';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _filter = widget.initialKind;
    _kind = widget.initialKind == 'supplier' ? 'supplier' : 'customer';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _company.text.trim().isNotEmpty) _load();
    });
  }
  @override
  void dispose() {
    _company.dispose(); _code.dispose(); _name.dispose(); _phone.dispose(); _whatsapp.dispose();
    _email.dispose(); _address.dispose(); _governorate.dispose(); _district.dispose(); _center.dispose(); _area.dispose(); _customerType.dispose();
    _creditLimit.dispose(); _openingBalance.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _kindLabel(String value) => value == 'supplier' ? 'مورد' : value == 'customer' ? 'عميل' : 'مورد وعميل';

  Future<void> _load({bool clearMessage = true}) async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; if (clearMessage) _message = null; });
    try {
      final rows = await _repo.fetchParties(_company.text, kind: _filter);
      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل بيانات الأطراف: $e'; });
    }
  }

  Future<void> _create() async {
    final credit = double.tryParse(_creditLimit.text.trim()) ?? -1;
    final opening = double.tryParse(_openingBalance.text.trim()) ?? 0;
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty || credit < 0) {
      setState(() => _error = 'راجع كود الطرف والاسم وحد الائتمان.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createParty(companyId: _company.text, code: _code.text, name: _name.text,
        kind: _kind, phone: _phone.text, whatsapp: _whatsapp.text, email: _email.text,
        address: _address.text, governorate: _governorate.text, district: _district.text,
        center: _center.text, area: _area.text, customerType: _customerType.text,
        creditLimit: credit, openingBalance: opening);
      if (!mounted) return;
      _code.clear(); _name.clear(); _phone.clear(); _whatsapp.clear(); _email.clear(); _address.clear();
      _governorate.clear(); _district.clear(); _center.clear(); _area.clear(); _customerType.clear(); _creditLimit.text = '0'; _openingBalance.text = '0';
      setState(() { _saving = false; _message = 'تمت إضافة الطرف.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة الطرف: $e'; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.setActive(_s(row['id']), row['is_active'] != true);
      if (!mounted) return;
      setState(() { _saving = false; _message = row['is_active'] == true ? 'تم تعطيل الطرف.' : 'تم تنشيط الطرف.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تحديث الحالة: $e'; });
    }
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 5, top: 3, bottom: 3),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), visualDensity: VisualDensity.compact),
      onPressed: action, icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    ),
  );

  void _newParty() {
    _code.clear(); _name.clear(); _phone.clear(); _whatsapp.clear(); _email.clear(); _address.clear();
    _governorate.clear(); _district.clear(); _center.clear(); _area.clear(); _customerType.clear();
    _creditLimit.text = '0'; _openingBalance.text = '0';
    setState(() { _error = null; _message = 'نموذج إضافة طرف جديد جاهز.'; });
  }

  Future<void> _previewParties() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة دليل العملاء والموردين'),
      content: SizedBox(width: 760, child: _rows.isEmpty
        ? const Text('لا توجد أطراف محمّلة للمعاينة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _rows.take(100).map((r) => ListTile(
            dense: true,
            leading: Icon(r['party_kind'] == 'supplier' ? Icons.local_shipping_outlined : Icons.person_outline,
              color: const Color(0xFF3E007D)),
            title: Text('${_s(r['party_code'])} — ${_s(r['party_name'])}'),
            subtitle: Text('${_kindLabel(_s(r['party_kind']))} • ${_s(r['phone'])} • حد ائتمان ${_n(r['credit_limit']).toStringAsFixed(2)} • ${r['is_active'] == true ? 'نشط' : 'موقوف'}'),
          )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(color: const Color(0xFF3E007D), child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('دليل العملاء والموردين', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const Text('إدارة بيانات الأطراف وحدود الائتمان ووسائل الاتصال.', style: TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
            _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _newParty),
            _quickTask('حفظ', Icons.save_outlined, const Color(0xFF168447), _saving || _loading ? null : _create),
            _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewParties),
          ])),
        ]),
      )),
      const SizedBox(height: 10),
      TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _filter,
          decoration: const InputDecoration(labelText: 'تصفية الدليل', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'both', child: Text('الكل')),
            DropdownMenuItem(value: 'customer', child: Text('العملاء')),
            DropdownMenuItem(value: 'supplier', child: Text('الموردون')),
          ],
          onChanged: (v) => setState(() => _filter = v ?? _filter),
        )),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل')),
      ]),
      if (_loading || _saving) const LinearProgressIndicator(),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      const SizedBox(height: 10),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('إضافة عميل أو مورد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          DropdownButtonFormField<String>(
            value: _kind, decoration: const InputDecoration(labelText: 'نوع الطرف'),
            items: const [
              DropdownMenuItem(value: 'customer', child: Text('عميل')),
              DropdownMenuItem(value: 'supplier', child: Text('مورد')),
              DropdownMenuItem(value: 'both', child: Text('مورد وعميل')),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 8),
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'كود الطرف *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم التجاري / الشخص *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'واتساب', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _governorate, decoration: const InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder()))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _center, decoration: const InputDecoration(labelText: 'المركز', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _district, decoration: const InputDecoration(labelText: 'الحي / المركز المحلي', border: OutlineInputBorder()))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _area, decoration: const InputDecoration(labelText: 'المنطقة', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _customerType, decoration: const InputDecoration(labelText: 'تصنيف العميل (مثال: سوبر ماركت / بقالة / تاجر نصف جملة)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('تنبيه محاسبي: الرصيد الافتتاحي في بطاقة الطرف لا ينشئ قيد أستاذ عام. لا تستخدمه كرصيد معتمد قبل إدخال قيد افتتاحي متوازن ومراجعته.', style: TextStyle(color: Color(0xFF9A5700), fontSize: 12, height: 1.5)),
          ),
          Row(children: [
            Expanded(child: TextField(controller: _creditLimit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حد الائتمان', border: OutlineInputBorder()))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _openingBalance, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'رصيد افتتاحي', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _saving ? null : _create, icon: const Icon(Icons.person_add_alt_1), label: const Text('حفظ الطرف')),
        ],
      ))),
      const SizedBox(height: 10),
      Text('الأطراف المسجلة • ' + _rows.length.toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ..._rows.map((r) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFF0E8FA), child: Icon(_s(r['party_kind']) == 'supplier' ? Icons.local_shipping_outlined : Icons.storefront_outlined, color: const Color(0xFF3E007D))),
        title: Text(_s(r['party_code']) + ' — ' + _s(r['party_name'])),
        subtitle: Text(_kindLabel(_s(r['party_kind'])) + ' • ' + _s(r['phone']) + '\nحد الائتمان: ' + _n(r['credit_limit']).toStringAsFixed(2) + ' ج.م'),
        isThreeLine: true,
        trailing: IconButton(onPressed: _saving ? null : () => _toggle(r), icon: Icon(r['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline), tooltip: r['is_active'] == true ? 'تعطيل' : 'تنشيط'),
      ))),
    ],
  ));

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
