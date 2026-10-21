import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_keyboard_navigation.dart';
import '../services/erp_payroll_repository.dart';

class ErpPayrollScreen extends StatefulWidget {
  const ErpPayrollScreen({super.key, this.initialCompanyId});
  final String? initialCompanyId;
  @override
  State<ErpPayrollScreen> createState() => _ErpPayrollScreenState();
}

class _ErpPayrollScreenState extends State<ErpPayrollScreen> {
  final _repo = ErpPayrollRepository();
  final _company = TextEditingController();
  final _runCode = TextEditingController();
  final _basic = TextEditingController(text: '0');
  final _allowances = TextEditingController(text: '0');
  final _commission = TextEditingController(text: '0');
  final _overtime = TextEditingController(text: '0');
  final _deductions = TextEditingController(text: '0');
  List<Map<String, dynamic>> _runs = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _lines = [];
  String? _selectedRunId;
  String? _employeeId;
  String? _expenseAccountId;
  String? _payableAccountId;
  String? _deductionsAccountId;
  DateTime _periodStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _periodEnd = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }
  @override
  void dispose() {
    _company.dispose(); _runCode.dispose(); _basic.dispose(); _allowances.dispose();
    _commission.dispose(); _overtime.dispose(); _deductions.dispose(); super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);
  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final results = await Future.wait([
        _repo.fetchRuns(_company.text),
        _repo.fetchEmployeeSalaries(_company.text),
        _repo.fetchAccounts(_company.text),
      ]);
      if (!mounted) return;
      setState(() {
        _runs = results[0]; _employees = results[1]; _accounts = results[2];
        if (!_employees.any((r) => _s(r['id']) == _employeeId)) _employeeId = _employees.isEmpty ? null : _s(_employees.first['id']);
        if (!_accounts.any((r) => _s(r['id']) == _expenseAccountId)) _expenseAccountId = _accounts.isEmpty ? null : _s(_accounts.first['id']);
        if (!_accounts.any((r) => _s(r['id']) == _payableAccountId)) _payableAccountId = _accounts.length > 1 ? _s(_accounts[1]['id']) : null;
        if (!_accounts.any((r) => _s(r['id']) == _deductionsAccountId)) _deductionsAccountId = _accounts.length > 2 ? _s(_accounts[2]['id']) : null;
        _loading = false;
        if (_selectedRunId != null && !_runs.any((r) => _s(r['id']) == _selectedRunId)) _selectedRunId = null;
      });
      await _loadLines();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل مسيرات الرواتب: $e'; });
    }
  }

  Future<void> _loadLines() async {
    final id = _selectedRunId;
    if (id == null) { if (mounted) setState(() => _lines = []); return; }
    try {
      final rows = await _repo.fetchLines(id);
      if (mounted) setState(() => _lines = rows);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل تفاصيل المسير: $e');
    }
  }

  Future<void> _pickDate(bool start) async {
    final selected = await showDatePicker(
      context: context, initialDate: start ? _periodStart : _periodEnd,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (selected == null || !mounted) return;
    setState(() { if (start) { _periodStart = selected; } else { _periodEnd = selected; } });
  }

  void _newPayrollRun() {
    if (_saving || _loading) return;
    if (_runCode.text.trim().isNotEmpty) {
      setState(() {
        _error = 'احفظ مسير الرواتب الحالي باستخدام زر حفظ أو F8 قبل بدء مسير جديد؛ لم يتم مسح أي بيانات.';
        _message = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _message = 'نموذج مسير جديد جاهز. أدخل الكود ثم اضغط F8 للحفظ.';
    });
  }

  Future<void> _createRun() async {
    if (_expenseAccountId == null || _payableAccountId == null || _deductionsAccountId == null) {
      setState(() => _error = 'يلزم تحميل واختيار ثلاثة حسابات محاسبية صالحة.');
      return;
    }
    if ({_expenseAccountId, _payableAccountId, _deductionsAccountId}.length != 3) {
      setState(() => _error = 'اختر حسابات مختلفة للمصروف والمستحقات والاستقطاعات.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createRun(companyId: _company.text, runCode: _runCode.text,
        start: _periodStart, end: _periodEnd,
        expenseAccountId: _expenseAccountId!, payableAccountId: _payableAccountId!,
        deductionsAccountId: _deductionsAccountId!);
      if (!mounted) return;
      _runCode.clear();
      setState(() { _saving = false; _message = 'تم إنشاء مسودة مسير الرواتب.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر إنشاء المسير: $e'; });
    }
  }

  Future<void> _addLine() async {
    final run = _runs.where((r) => _s(r['id']) == _selectedRunId);
    if (run.isEmpty || _s(run.first['status']) != 'draft') {
      setState(() => _error = 'اختر مسيرًا بحالة مسودة لإضافة الموظفين.');
      return;
    }
    if (_employeeId == null) { setState(() => _error = 'اختر الموظف.'); return; }
    final basic = double.tryParse(_basic.text) ?? -1;
    final allowances = double.tryParse(_allowances.text) ?? -1;
    final commission = double.tryParse(_commission.text) ?? -1;
    final overtime = double.tryParse(_overtime.text) ?? -1;
    final deductions = double.tryParse(_deductions.text) ?? -1;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.addLine(companyId: _company.text, runId: _selectedRunId!, employeeId: _employeeId!,
        basic: basic, allowances: allowances, commissions: commission, overtime: overtime, deductions: deductions);
      await _repo.recalculate(_selectedRunId!);
      if (!mounted) return;
      _basic.text = '0'; _allowances.text = '0'; _commission.text = '0'; _overtime.text = '0'; _deductions.text = '0';
      setState(() { _saving = false; _message = 'تمت إضافة الموظف إلى المسير وإعادة حساب الإجماليات.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذرت إضافة تفاصيل الراتب: $e'; });
    }
  }

  Future<void> _runAction(String action, Map<String, dynamic> run) async {
    final id = _s(run['id']);
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      if (action == 'recalculate') await _repo.recalculate(id);
      if (action == 'approve') await _repo.approve(id);
      if (action == 'post') await _repo.post(id);
      if (!mounted) return;
      setState(() { _saving = false; _selectedRunId = id; _message = action == 'approve' ? 'تم اعتماد مسير الرواتب.' : action == 'post' ? 'تم ترحيل مسير الرواتب وإنشاء قيد اليومية.' : 'تمت إعادة حساب المسير.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تنفيذ الإجراء: $e'; });
    }
  }

  String _employeeLabel(String id) {
    final rows = _employees.where((r) => _s(r['id']) == id);
    return rows.isEmpty ? id : '${_s(rows.first['employee_code'])} — ${_s(rows.first['full_name'])}';
  }
  String _accountLabel(String? id) {
    final rows = _accounts.where((r) => _s(r['id']) == id);
    return rows.isEmpty ? 'اختر الحساب' : '${_s(rows.first['account_code'])} — ${_s(rows.first['account_name'])}';
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewRuns() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة مسيرات الرواتب'),
      content: SizedBox(width: 760, child: _runs.isEmpty ? const Text('لا توجد مسيرات محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _runs.take(100).map((r) => ListTile(
          dense: true, title: Text('${_s(r['run_code'])} — ${_s(r['status'])}'),
          subtitle: Text('${_s(r['period_start'])} إلى ${_s(r['period_end'])}'),
          onTap: () { Navigator.pop(ctx); setState(() => _selectedRunId = _s(r['id'])); _loadLines(); },
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(add: _addLine, save: _createRun);
    final selected = _runs.where((r) => _s(r['id']) == _selectedRunId).toList();
    final selectedRun = selected.isEmpty ? null : selected.first;
    return Directionality(textDirection: TextDirection.rtl, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(color: const Color(0xFF3E007D), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('مسير الرواتب', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const Text('إنشاء مسير ومراجعته واعتماده محاسبيًا.', style: TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
              _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _saving || _loading ? null : _newPayrollRun),
              _quickTask('حفظ', Icons.save_outlined, const Color(0xFF168447), _saving || _loading ? null : _createRun),
              _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewRuns),
              _quickTask('طباعة', Icons.print_outlined, const Color(0xFF4056A1), _previewRuns),
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
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إنشاء مسودة مسير', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            TextField(controller: _runCode, decoration: const InputDecoration(labelText: 'كود المسير *')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _pickDate(true), child: Text('بداية الفترة: ${_date(_periodStart)}')),
            OutlinedButton(onPressed: () => _pickDate(false), child: Text('نهاية الفترة: ${_date(_periodEnd)}')),
            const SizedBox(height: 8),
            _accountDropdown('حساب مصروف الرواتب', _expenseAccountId, (v) => setState(() => _expenseAccountId = v)),
            const SizedBox(height: 8),
            _accountDropdown('حساب مستحقات الرواتب', _payableAccountId, (v) => setState(() => _payableAccountId = v)),
            const SizedBox(height: 8),
            _accountDropdown('حساب الاستقطاعات', _deductionsAccountId, (v) => setState(() => _deductionsAccountId = v)),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _saving ? null : _createRun, icon: const Icon(Icons.add), label: const Text('إنشاء المسير')),
          ],
        ))),
        const SizedBox(height: 12),
        Text('المسيرات • ${_runs.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ..._runs.map((r) {
          final isSelected = _s(r['id']) == _selectedRunId;
          final status = _s(r['status']);
          return Card(color: isSelected ? const Color(0xFFF0E8FA) : null, child: InkWell(
            onTap: () async { setState(() => _selectedRunId = _s(r['id'])); await _loadLines(); },
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('${_s(r['run_code'])} • $status', style: const TextStyle(fontWeight: FontWeight.w900))),
                Text('${_s(r['period_start'])} — ${_s(r['period_end'])}', style: const TextStyle(fontSize: 11)),
              ]),
              const SizedBox(height: 5),
              Text('الموظفون: ${_s(r['employee_count'])} • إجمالي: ${_money(r['gross_total'])} • استقطاعات: ${_money(r['deduction_total'])} • صافي: ${_money(r['net_total'])} ج.م'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (status == 'draft') OutlinedButton(onPressed: _saving ? null : () => _runAction('recalculate', r), child: const Text('إعادة حساب')),
                if (status == 'draft') FilledButton(onPressed: _saving ? null : () => _runAction('approve', r), child: const Text('اعتماد')),
                if (status == 'approved') FilledButton(onPressed: _saving ? null : () => _runAction('post', r), child: const Text('ترحيل محاسبي')),
                if (_s(r['journal_entry_id']).isNotEmpty) Text('قيد: ${_s(r['journal_entry_id'])}', style: const TextStyle(fontSize: 11)),
              ]),
            ])),
          ));
        }),
        if (selectedRun != null) ...[
          const SizedBox(height: 12),
          Text('تفاصيل مسير ${_s(selectedRun['run_code'])}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (_s(selectedRun['status']) == 'draft') Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة موظف للمسير', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _employeeId, isExpanded: true,
                decoration: const InputDecoration(labelText: 'الموظف', border: OutlineInputBorder()),
                items: _employees.map((e) => DropdownMenuItem(value: _s(e['id']), child: Text(_employeeLabel(_s(e['id'])), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() {
                  _employeeId = v;
                  final employee = _employees.where((e) => _s(e['id']) == v);
                  if (employee.isNotEmpty) _basic.text = _money(employee.first['base_salary']);
                }),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _amountField('أساسي', _basic)),
                const SizedBox(width: 6), Expanded(child: _amountField('بدلات', _allowances)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _amountField('عمولات', _commission)),
                const SizedBox(width: 6), Expanded(child: _amountField('إضافي', _overtime)),
              ]),
              const SizedBox(height: 8),
              _amountField('استقطاعات', _deductions),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: _saving ? null : _addLine, icon: const Icon(Icons.person_add_alt_1), label: const Text('إضافة إلى المسير')),
            ],
          ))),
          ..._lines.map((line) => Card(child: ListTile(
            title: Text(_employeeLabel(_s(line['employee_id']))),
            subtitle: Text('أساسي ${_money(line['basic_amount'])} • بدلات ${_money(line['allowances'])} • عمولات ${_money(line['commissions'])} • إضافي ${_money(line['overtime_amount'])}\nاستقطاعات ${_money(line['deductions'])}'),
            isThreeLine: true,
            trailing: Text('${_money(line['net_amount'])} ج.م', style: const TextStyle(fontWeight: FontWeight.w900)),
          ))),
        ],
      ],
    ));
  }

  Widget _accountDropdown(String label, String? value, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(
    value: value, isExpanded: true,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    items: _accounts.map((r) => DropdownMenuItem(value: _s(r['id']), child: Text(_accountLabel(_s(r['id'])), overflow: TextOverflow.ellipsis))).toList(),
    onChanged: onChanged,
  );

  Widget _amountField(String label, TextEditingController controller) => TextField(
    controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
  );

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
