import 'package:flutter/material.dart';
import '../services/erp_ledger_reports_repository.dart';

enum ErpLedgerReportKind { trialBalance, generalLedger, accountMovement }

class ErpLedgerReportsScreen extends StatefulWidget {
  const ErpLedgerReportsScreen({
    super.key,
    this.kind = ErpLedgerReportKind.trialBalance,
    this.initialCompanyId,
  });

  final ErpLedgerReportKind kind;
  final String? initialCompanyId;

  @override
  State<ErpLedgerReportsScreen> createState() => _ErpLedgerReportsScreenState();
}

class _ErpLedgerReportsScreenState extends State<ErpLedgerReportsScreen> {
  final _repo = ErpLedgerReportsRepository();
  final _company = TextEditingController();
  final _accountId = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
  }

  bool get _trial => widget.kind == ErpLedgerReportKind.trialBalance;
  String get _title => _trial
      ? 'ميزان المراجعة'
      : widget.kind == ErpLedgerReportKind.accountMovement
          ? 'حركة حساب'
          : 'الأستاذ العام';

  @override
  void dispose() {
    _company.dispose();
    _accountId.dispose();
    super.dispose();
  }

  String _date(DateTime? value) => value == null
      ? 'بداية مفتوحة'
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  double _num(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse((value ?? '0').toString()) ?? 0;

  Future<void> _pickDate(bool start) async {
    final initial = (start ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = _trial
          ? await _repo.fetchTrialBalance(
              companyId: _company.text,
              startDate: _start,
              endDate: _end,
            )
          : await _repo.fetchGeneralLedger(
              companyId: _company.text,
              startDate: _start,
              endDate: _end,
              accountId: widget.kind == ErpLedgerReportKind.accountMovement
                  ? _accountId.text
                  : null,
            );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل التقرير: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final debit = _rows.fold<double>(0, (s, r) =>
        s + _num(r[_trial ? 'debit_total' : 'debit']));
    final credit = _rows.fold<double>(0, (s, r) =>
        s + _num(r[_trial ? 'credit_total' : 'credit']));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title, style: const TextStyle(
            color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900,
          )),
          const SizedBox(height: 6),
          const Text(
            'يعرض التقرير الحركات المرحلة فقط؛ المسودات والقيود المعكوسة مستبعدة.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _company,
            decoration: const InputDecoration(
              labelText: 'معرّف الشركة (UUID)',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.kind == ErpLedgerReportKind.accountMovement) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _accountId,
              decoration: const InputDecoration(
                labelText: 'معرّف الحساب (UUID) — اختياري',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.calendar_month),
                label: Text('من: ${_start == null ? 'البداية' : _date(_start)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.calendar_month),
                label: Text('إلى: ${_end == null ? 'النهاية' : _date(_end)}'),
              ),
              TextButton(
                onPressed: () => setState(() { _start = null; _end = null; }),
                child: const Text('كل الفترات'),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search),
                label: const Text('عرض التقرير'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              _metric('إجمالي المدين', debit),
              _metric('إجمالي الدائن', credit),
              _metric('الفرق', debit - credit),
              if (!_trial) _metric('عدد السطور المعروضة', _rows.length.toDouble()),
            ]),
            const SizedBox(height: 10),
            if (_trial)
              ..._rows.map((r) => Card(
                child: ListTile(
                  title: Text('${r['account_code'] ?? ''} — ${r['account_name'] ?? ''}'),
                  subtitle: Text('النوع: ${r['account_type'] ?? ''} • طبيعة الرصيد: ${r['normal_balance'] ?? ''}'),
                  trailing: SizedBox(
                    width: 170,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('مدين ${_num(r['debit_total']).toStringAsFixed(2)}'),
                        Text('دائن ${_num(r['credit_total']).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              ))
            else
              ..._rows.map((r) => Card(
                child: ListTile(
                  title: Text('قيد ${r['entry_number'] ?? ''} • ${r['account_code'] ?? ''} — ${r['account_name'] ?? ''}'),
                  subtitle: Text('${r['entry_date'] ?? ''} • ${r['entry_description'] ?? ''}${(r['line_description'] ?? '').toString().isEmpty ? '' : ' • ${r['line_description']}'}'),
                  trailing: SizedBox(
                    width: 145,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('مدين ${_num(r['debit']).toStringAsFixed(2)}'),
                        Text('دائن ${_num(r['credit']).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              )),
          ],
          if (!_loading && _rows.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('أدخل معرّف الشركة واضغط «عرض التقرير». لا تظهر بيانات إلا بعد تهيئة قاعدة البيانات وصلاحيات القراءة.'),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, double value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F5FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text('$label: ${value.toStringAsFixed(2)} ج.م',
      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3E007D))),
  );
}
