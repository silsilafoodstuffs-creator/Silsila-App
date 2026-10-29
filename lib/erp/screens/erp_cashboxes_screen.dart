import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_keyboard_navigation.dart';
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
  final _codeFocus = FocusNode();
  final _name = TextEditingController();
  final _nameEn = TextEditingController();
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
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _isBank = widget.initialBankOnly;
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }
  @override
  void dispose() {
    _company.dispose(); _codeFocus.dispose(); _code.dispose(); _name.dispose(); _nameEn.dispose(); _bankName.dispose(); _maskedNumber.dispose(); super.dispose();
  }
  String _s(dynamic v) => (v ?? '').toString();

  Future<void> _load({bool clearMessage = true}) async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; if (clearMessage) _message = null; });
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
      await _generateNextCode();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل الخزائن والحسابات البنكية: $e'; });
    }
  }

  Future<void> _generateNextCode() async {
    if (_code.text.trim().isNotEmpty || _company.text.trim().isEmpty) return;
    try {
      final rows = await _repo.fetchCashboxes(_company.text.trim());
      var max = 0;
      for (final row in rows) {
        final match = RegExp(r'^[A-Za-z]+-?(\d+)$').firstMatch(_s(row['cashbox_code']));
        final number = match == null ? 0 : (int.tryParse(match.group(1) ?? '') ?? 0);
        if (number > max) max = number;
      }
      if (mounted && _code.text.trim().isEmpty) {
        setState(() => _code.text = 'CSH-' + (max + 1).toString().padLeft(4, '0'));
      }
    } catch (_) {
      if (mounted && _code.text.trim().isEmpty) setState(() => _code.text = 'CSH-0001');
    }
  }

  void _newCashbox() {
    if (_saving || _loading) return;
    final hasUnsavedInput = [_code.text, _name.text, _nameEn.text, _bankName.text, _maskedNumber.text]
        .any((value) => value.trim().isNotEmpty);
    if (hasUnsavedInput) {
      setState(() {
        _error = 'احفظ البيانات الحالية باستخدام F8 قبل بدء سجل جديد؛ لم يتم مسح أي بيانات.';
        _message = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _message = 'نموذج جديد جاهز. أدخل البيانات ثم اضغط F8 للحفظ.';
    });
    _codeFocus.requestFocus();
    _generateNextCode();
  }

  Future<void> _create() async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createCashbox(companyId: _company.text, code: _code.text, name: _name.text, nameEn: _nameEn.text,
        accountId: _accountId ?? '', branchId: _branchId, isBank: _isBank,
        bankName: _bankName.text, accountNumberMasked: _maskedNumber.text);
      if (!mounted) return;
      _code.clear(); _name.clear(); _nameEn.clear(); _bankName.clear(); _maskedNumber.clear();
      setState(() { _saving = false; _message = 'تمت إضافة ' + (_isBank ? 'الحساب البنكي.' : 'الخزينة.'); });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة الخزينة أو البنك: $e'; });
    }
  }

  Future<void> _seedDefaultCashboxes() async {
    if (_saving || _loading || _company.text.trim().isEmpty) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final companyId = _company.text.trim();
      final accounts = await _repo.fetchAccounts(companyId);
      if (accounts.isEmpty) {
        throw StateError('لا يوجد حساب أستاذ عام نشط وقابل للترحيل. أنشئ حساب الخزينة أولًا ثم أعد المحاولة.');
      }
      final branches = (await _repo.fetchBranches(companyId))
          .where((b) => _s(b['branch_code']).isNotEmpty)
          .toList()
        ..sort((a, b) => _s(a['branch_code']).compareTo(_s(b['branch_code'])));
      if (branches.isEmpty) {
        throw StateError('لا توجد فروع نشطة. يجب إعداد الفروع أولًا.');
      }
      final rows = await _repo.fetchCashboxes(companyId);
      var next = 0;
      for (final row in rows) {
        final digits = _s(row['cashbox_code']).replaceAll(RegExp('[^0-9]'), '');
        final n = int.tryParse(digits) ?? 0;
        if (n > next) next = n;
      }
      final targets = <Map<String, dynamic>>[
        {'branchId': null, 'ar': 'الخزينة الرئيسية - الإدارة المركزية', 'en': 'Central Administration Main Treasury'},
        ...branches.take(3).map((b) => {
          'branchId': _s(b['id']),
          'ar': 'خزينة فرع \${_s(b['branch_name'])}',
          'en': '\${_s(b['branch_name'])} Branch Treasury',
        }),
      ];
      var created = 0;
      for (final target in targets) {
        final branchId = target['branchId'] as String?;
        final exists = rows.any((row) =>
            row['is_bank_account'] != true &&
            (branchId == null
                ? _s(row['branch_id']).isEmpty
                : _s(row['branch_id']) == branchId));
        if (exists) continue;
        next++;
        await _repo.createCashbox(
          companyId: companyId,
          code: 'CSH-\${next.toString().padLeft(4, '0')}',
          name: _s(target['ar']),
          nameEn: _s(target['en']),
          accountId: _s(accounts.first['id']),
          branchId: branchId,
          isBank: false,
        );
        created++;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = created == 0
            ? 'الخزائن الافتراضية موجودة بالفعل؛ لم يتم تكرار أي سجل.'
            : 'تم إنشاء \${created} خزينة افتراضية. لم يتم حذف أو تغيير أي خزينة موجودة.';
      });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت تهيئة الخزائن: \$e'; });
    }
  }

  Future<void> _setBranch(Map<String, dynamic> row, String? branchId) async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.setBranch(_s(row['id']), branchId);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم تحديث الإدارة / الفرع للخزينة.'; });
      await _load(clearMessage: false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تحديث الإدارة / الفرع: $e'; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.setActive(_s(row['id']), row['is_active'] != true);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم تحديث الحالة.'; });
      await _load(clearMessage: false);
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
    return rows.isEmpty ? 'الإدارة المركزية' : _s(rows.first['branch_code']) + ' — ' + _s(rows.first['branch_name']);
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewRecords(String title) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 720, child: _rows.isEmpty ? const Text('لا توجد بيانات محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _rows.take(100).map((r) => ListTile(
          dense: true,
          title: Text('${r['name'] ?? r['cashbox_name'] ?? r['code'] ?? r['cashbox_code'] ?? '—'}'),
          subtitle: Text('${r['code'] ?? r['cashbox_code'] ?? ''} • ${r['is_active'] == true ? 'نشط' : 'موقوف'}'),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(add: _newCashbox, save: _create);
    final visible = _rows.where((r) => widget.initialBankOnly ? r['is_bank_account'] == true : true).toList();
    return Directionality(textDirection: TextDirection.rtl, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(color: const Color(0xFF3E007D), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.initialBankOnly ? 'الحسابات البنكية' : 'الخزائن الرئيسية والفرعية',
              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const Text('ربط كل خزينة أو بنك بحساب أستاذ عام نشط وقابل للترحيل.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
              _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _saving ? null : _newCashbox),
              _quickTask('حفظ', Icons.save_outlined, const Color(0xFF168447), _saving ? null : _create),
              _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), () => _previewRecords(widget.initialBankOnly ? 'معاينة الحسابات البنكية' : 'معاينة الخزائن')),
              if (!widget.initialBankOnly) _quickTask('تهيئة الخزائن', Icons.account_balance_wallet_outlined, const Color(0xFF168447), _saving || _loading ? null : _seedDefaultCashboxes),
            ])),
          ]),
        )),
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
            TextField(controller: _code, focusNode: _codeFocus, decoration: const InputDecoration(labelText: 'الكود *')),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم بالعربية *')),
            TextField(controller: _nameEn, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية *')),
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
              decoration: const InputDecoration(labelText: 'الإدارة / الفرع'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('الإدارة المركزية')), ..._branches.map((b) => DropdownMenuItem<String>(value: _s(b['id']), child: Text(_branchLabel(_s(b['id'])))))],
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
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('م')),
                DataColumn(label: Text('كود الخزينة')),
                DataColumn(label: Text('الاسم العربي')),
                DataColumn(label: Text('الاسم الإنجليزي')),
                DataColumn(label: Text('الإدارة / الفرع')),
                DataColumn(label: Text('نشط')),
              ],
              rows: List<DataRow>.generate(visible.length, (index) {
                final r = visible[index];
                return DataRow(cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(_s(r['cashbox_code']))),
                  DataCell(Text(_s(r['cashbox_name']))),
                  DataCell(Text(_s(r['cashbox_name_en']))),
                  DataCell(SizedBox(
                    width: 210,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _s(r['branch_id']).isEmpty ? '' : _s(r['branch_id']),
                      items: [
                        const DropdownMenuItem<String>(value: '', child: Text('الإدارة المركزية', overflow: TextOverflow.ellipsis)),
                        ..._branches.map((b) => DropdownMenuItem<String>(
                          value: _s(b['id']),
                          child: Text(_branchLabel(_s(b['id'])), overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: _saving ? null : (value) => _setBranch(r, (value ?? '').isEmpty ? null : value),
                    ),
                  )),
                  DataCell(Checkbox(
                    value: r['is_active'] == true,
                    onChanged: _saving ? null : (_) => _toggle(r),
                    shape: const CircleBorder(),
                  )),
                ]);
              }),
            ),
          ),
        ),
      ],
    ));
  }

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
