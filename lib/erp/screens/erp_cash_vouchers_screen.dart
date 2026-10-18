import 'package:flutter/material.dart';
import '../services/erp_cash_vouchers_repository.dart';

class ErpCashVouchersScreen extends StatefulWidget {
  const ErpCashVouchersScreen({super.key, this.initialCompanyId, this.initialType = 'receipt'});
  final String? initialCompanyId;
  final String initialType;
  @override
  State<ErpCashVouchersScreen> createState() => _ErpCashVouchersScreenState();
}

class _ErpCashVouchersScreenState extends State<ErpCashVouchersScreen> {
  final _repo = ErpCashVouchersRepository();
  final _company = TextEditingController();
  final _number = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  List<Map<String, dynamic>> _cashboxes = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _parties = [];
  List<Map<String, dynamic>> _vouchers = [];
  String _type = 'receipt';
  String? _sourceId;
  String? _destinationId;
  String? _accountId;
  String? _partyId;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _type = widget.initialType;
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }
  @override
  void dispose() {
    _company.dispose(); _number.dispose(); _amount.dispose(); _description.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);
  String _typeLabel(String v) => v == 'receipt' ? 'قبض' : v == 'payment' ? 'صرف' : 'تحويل';

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final results = await Future.wait([
        _repo.fetchCashboxes(_company.text),
        _repo.fetchAccounts(_company.text),
        _repo.fetchParties(_company.text),
        _repo.fetchVouchers(_company.text),
      ]);
      if (!mounted) return;
      setState(() {
        _cashboxes = results[0]; _accounts = results[1]; _parties = results[2]; _vouchers = results[3];
        if (!_cashboxes.any((r) => _s(r['id']) == _sourceId)) _sourceId = _cashboxes.isEmpty ? null : _s(_cashboxes.first['id']);
        if (!_cashboxes.any((r) => _s(r['id']) == _destinationId)) _destinationId = _cashboxes.length > 1 ? _s(_cashboxes[1]['id']) : null;
        if (!_accounts.any((r) => _s(r['id']) == _accountId)) _accountId = _accounts.isEmpty ? null : _s(_accounts.first['id']);
        if (!_parties.any((r) => _s(r['id']) == _partyId)) _partyId = _parties.isEmpty ? null : _s(_parties.first['id']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل سندات الخزائن: $e'; });
    }
  }

  Future<void> _createDraft() async {
    final amount = double.tryParse(_amount.text.trim());
    if (_sourceId == null || amount == null || amount <= 0 || _number.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'أكمل رقم السند والخزينة والقيمة والبيان.');
      return;
    }
    if (_type == 'transfer' && (_destinationId == null || _destinationId == _sourceId)) {
      setState(() => _error = 'اختر خزينة استلام مختلفة عن خزينة المصدر.');
      return;
    }
    if (_type != 'transfer' && _accountId == null) {
      setState(() => _error = 'اختر الحساب المقابل.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createDraft(
        companyId: _company.text, voucherNumber: _number.text, voucherType: _type,
        sourceCashboxId: _sourceId!, destinationCashboxId: _destinationId,
        counterAccountId: _accountId, partyId: _partyId, amount: amount,
        description: _description.text,
      );
      if (!mounted) return;
      _number.clear(); _amount.clear(); _description.clear();
      setState(() { _saving = false; _message = 'تم حفظ مسودة السند.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر حفظ المسودة: $e'; });
    }
  }

  Future<void> _post(Map<String, dynamic> voucher) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ترحيل سند الخزينة'),
      content: Text('سيُنشأ قيد يومية متوازن مرتبط بالسند رقم ${_s(voucher['voucher_number'])}.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ترحيل')),
      ],
    ));
    if (yes != true || !mounted) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.postVoucher(_s(voucher['id']));
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم ترحيل السند والقيد المحاسبي معًا.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر ترحيل السند: $e'; });
    }
  }

  String _cashboxName(String? id) {
    final r = _cashboxes.where((x) => _s(x['id']) == id);
    return r.isEmpty ? 'غير محدد' : '${_s(r.first['cashbox_code'])} — ${_s(r.first['cashbox_name'])}';
  }
  String _accountName(String? id) {
    final r = _accounts.where((x) => _s(x['id']) == id);
    return r.isEmpty ? 'غير محدد' : '${_s(r.first['account_code'])} — ${_s(r.first['account_name'])}';
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('سندات الخزائن والبنوك', style: TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('حفظ مسودة قبض أو صرف أو تحويل، ثم ترحيلها لإنشاء قيد يومية متوازن في نفس المعاملة.',
        style: TextStyle(color: Colors.black54, height: 1.5)),
      const SizedBox(height: 12),
      TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل الخزائن والحسابات والسندات')),
      if (_loading || _saving) const LinearProgressIndicator(),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('إنشاء مسودة سند', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'نوع السند', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'receipt', child: Text('سند قبض')),
              DropdownMenuItem(value: 'payment', child: Text('سند صرف')),
              DropdownMenuItem(value: 'transfer', child: Text('تحويل بين الخزائن')),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 8),
          TextField(controller: _number, decoration: const InputDecoration(labelText: 'رقم السند *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _sourceId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'خزينة المصدر', border: OutlineInputBorder()),
            items: _cashboxes.map((r) => DropdownMenuItem(value: _s(r['id']), child: Text(_cashboxName(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _sourceId = v),
          ),
          if (_type == 'transfer') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _destinationId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'خزينة الاستلام', border: OutlineInputBorder()),
              items: _cashboxes.where((r) => _s(r['id']) != _sourceId).map((r) => DropdownMenuItem(value: _s(r['id']), child: Text(_cashboxName(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _destinationId = v),
            ),
          ],
          if (_type != 'transfer') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _accountId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الحساب المقابل', border: OutlineInputBorder()),
              items: _accounts.map((r) => DropdownMenuItem(value: _s(r['id']), child: Text(_accountName(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _partyId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الطرف (اختياري)', border: OutlineInputBorder()),
              items: [const DropdownMenuItem<String>(value: null, child: Text('بدون طرف')), ..._parties.map((r) => DropdownMenuItem<String>(value: _s(r['id']), child: Text('${_s(r['party_code'])} — ${_s(r['party_name'])}', overflow: TextOverflow.ellipsis)))],
              onChanged: (v) => setState(() => _partyId = v),
            ),
          ],
          const SizedBox(height: 8),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'القيمة بالجنيه *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'البيان *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _saving ? null : _createDraft, icon: const Icon(Icons.save), label: const Text('حفظ المسودة')),
        ],
      ))),
      const SizedBox(height: 12),
      Text('السندات • ${_vouchers.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      if (_vouchers.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد سندات محملة.')),
      ..._vouchers.map((v) {
        final status = _s(v['status']);
        return Card(child: ListTile(
          leading: Icon(_s(v['voucher_type']) == 'receipt' ? Icons.call_received : _s(v['voucher_type']) == 'payment' ? Icons.call_made : Icons.swap_horiz, color: const Color(0xFF3E007D)),
          title: Text('${_typeLabel(_s(v['voucher_type']))} رقم ${_s(v['voucher_number'])}'),
          subtitle: Text('${_money(v['amount'])} ج.م • ${_s(v['voucher_date'])}\n${_s(v['description'])}\n${_cashboxName(_s(v['source_cashbox_id']))}'),
          isThreeLine: true,
          trailing: status == 'draft' ? FilledButton(onPressed: _saving ? null : () => _post(v), child: const Text('ترحيل')) : Chip(label: Text(status)),
        ));
      }),
    ],
  ));

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
