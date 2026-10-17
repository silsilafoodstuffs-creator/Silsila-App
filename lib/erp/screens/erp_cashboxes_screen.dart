import 'package:flutter/material.dart';
import '../services/erp_cashboxes_repository.dart';

class ErpCashboxesScreen extends StatefulWidget {
  const ErpCashboxesScreen({super.key, this.initialCompanyId, this.initialBankOnly = false});
  final String? initialCompanyId;
  final bool initialBankOnly;
  @override
  State<ErpCashboxesScreen> createState() => _ErpCashboxesScreenState();
}

class _ErpCashboxesScreenState extends State<ErpCashboxesScreen> {
  final _repo = ErpCashboxesRepository();
  final _company = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _bankName = TextEditingController();
  final _maskedNumber = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _branches = [];
  String? _accountId;
  String? _branchId;
  bool _isBank = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() { super.initState(); _company.text = widget.initialCompanyId ?? ''; _isBank = widget.initialBankOnly; }
  @override
  void dispose() {
    _company.dispose(); _code.dispose(); _name.dispose(); _bankName.dispose(); _maskedNumber.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final values = await Future.wait([
        _repo.fetchCashboxes(_company.text),
        _repo.fetchAccounts(_company.text),
        _repo.fetchBranches(_company.text),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = values[0]; _accounts = values[1]; _branches = values[2];
        if (!_accounts.any((a) => _s(a['id']) == _accountId)) _accountId = _accounts.isEmpty ? null : _s(_accounts.first['id']);
        if (!_branches.any((b) => _s(b['id']) == _branchId)) _branchId = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل الخزائن والحسابات البنكية: $e'; });
    }
  }

  Future<void> _create() async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createCashbox(companyId: _company.text, code: _code.text, name: _name.text,
        accountId: _accountId ?? '', branchId: _branchId, isBank: _isBank,
        bankName: _bankName.text, accountNumberMasked: _maskedNumber.text);
      if (!mounted) return;
      _code.clear(); _name.clear(); _bankName.clear(); _maskedNumber.clear();
      setState(() { _saving = false; _message = 'تمت إضافة ' + (_isBank ? 'الحساب البنكي.' : 'الخزينة.'); });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة الخزينة أو البنك: $e'; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.setActive(_s(row['id']), row['is_active'] != true);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم تحديث الحالة.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تحديث الحالة: $e'; });
    }
  }

  String _accountLabel(String? id) {
    final rows = _accounts.where((a) => _s(a['id']) == id);
    return rows.isEmpty ? 'اختر حساب الأستاذ' : _s(rows.first['account_code']) + ' — ' + _s(rows.first['account_name']);
  }
  String _branchLabel(String? id) {
    final rows = _branches.where((b) => _s(b['id']) == id);
    return rows.isEmpty ? 'بدون فرع' : _s(rows.first['branch_code']) + ' — ' + _s(rows.first['branch_name']);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _rows.where((r) => widget.initialBankOnly ? r['is_bank_account'] == true : true).toList();
    return Directionality(textDirection: TextDirection.rtl, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.initialBankOnly ? 'الحسابات البنكية' : 'الخزائن الرئيسية والفرعية',
          style: const TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('كل خزينة أو حساب بنكي يجب ربطه بحساب أستاذ عام نشط وقابل للترحيل.', style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 12),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل البيانات')),
        if (_loading || _saving) const LinearProgressIndicator(),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إضافة خزينة / بنك', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'الكود *')),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم *')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _accountId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'حساب الأستاذ المرتبط *'),
              items: _accounts.map((a) => DropdownMenuItem<String>(value: _s(a['id']), child: Text(_accountLabel(_s(a['id'])), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _branchId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الفرع (اختياري)'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('بدون فرع')), ..._branches.map((b) => DropdownMenuItem<String>(value: _s(b['id']), child: Text(_branchLabel(_s(b['id'])))))],
              onChanged: (v) => setState(() => _branchId = v),
            ),
            CheckboxListTile(value: _isBank, onChanged: widget.initialBankOnly ? null : (v) => setState(() => _isBank = v ?? false), title: const Text('هذا حساب بنكي'), contentPadding: EdgeInsets.zero),
            if (_isBank) ...[
              TextField(controller: _bankName, decoration: const InputDecoration(labelText: 'اسم البنك')),
              TextField(controller: _maskedNumber, decoration: const InputDecoration(labelText: 'رقم الحساب بشكل مخفي')),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _saving ? null : _create, icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('حفظ')),
          ],
        ))),
        const SizedBox(height: 10),
        Text('السجلات • ' + visible.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ...visible.map((r) => Card(child: ListTile(
          leading: Icon(r['is_bank_account'] == true ? Icons.account_balance : Icons.account_balance_wallet, color: const Color(0xFF3E007D)),
          title: Text(_s(r['cashbox_code']) + ' — ' + _s(r['cashbox_name'])),
          subtitle: Text(_s(r['bank_name']) + ' • حساب أستاذ: ' + _accountLabel(_s(r['account_id'])) + '\n' + _branchLabel(_s(r['branch_id']))),
          isThreeLine: true,
          trailing: IconButton(onPressed: _saving ? null : () => _toggle(r), icon: Icon(r['is_active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
        ))),
      ],
    ));
  }

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
