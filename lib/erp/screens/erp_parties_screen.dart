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
  }
  @override
  void dispose() {
    _company.dispose(); _code.dispose(); _name.dispose(); _phone.dispose(); _whatsapp.dispose();
    _email.dispose(); _address.dispose(); _governorate.dispose(); _district.dispose();
    _creditLimit.dispose(); _openingBalance.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _kindLabel(String value) => value == 'supplier' ? 'مورد' : value == 'customer' ? 'عميل' : 'مورد وعميل';

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
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
        creditLimit: credit, openingBalance: opening);
      if (!mounted) return;
      _code.clear(); _name.clear(); _phone.clear(); _whatsapp.clear(); _email.clear(); _address.clear();
      _governorate.clear(); _district.clear(); _creditLimit.text = '0'; _openingBalance.text = '0';
      setState(() { _saving = false; _message = 'تمت إضافة الطرف.'; });
      await _load();
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
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تحديث الحالة: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('دليل العملاء والموردين', style: TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('إضافة الأطراف وتحديد نوع التعامل وبيانات الاتصال وحد الائتمان.', style: TextStyle(color: Colors.black54, height: 1.5)),
      const SizedBox(height: 12),
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
            Expanded(child: TextField(controller: _district, decoration: const InputDecoration(labelText: 'المنطقة / المركز', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
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
