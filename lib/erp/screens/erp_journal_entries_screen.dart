import 'package:flutter/material.dart';
import '../services/erp_journal_repository.dart';

class ErpJournalEntriesScreen extends StatefulWidget {
  const ErpJournalEntriesScreen({super.key});

  @override
  State<ErpJournalEntriesScreen> createState() => _ErpJournalEntriesScreenState();
}

class _ErpJournalEntriesScreenState extends State<ErpJournalEntriesScreen> {
  final _repo = ErpJournalRepository();
  final _company = TextEditingController();
  List<Map<String, dynamic>> _entries = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _company.dispose();
    super.dispose();
  }

  String _str(Map<String, dynamic> row, String key) =>
      (row[key] ?? '').toString();

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة أولاً.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _repo.fetchEntries(companyId: _company.text.trim());
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل القيود: $e';
      });
    }
  }

  Future<void> _createDraft() async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة قبل إنشاء القيد.');
      return;
    }
    List<Map<String, dynamic>> accounts;
    try {
      accounts = await _repo.fetchPostableAccounts(companyId: _company.text.trim());
    } catch (e) {
      setState(() => _error = 'تعذر تحميل الحسابات القابلة للترحيل: $e');
      return;
    }
    if (!mounted) return;
    if (accounts.isEmpty) {
      setState(() => _error = 'لا توجد حسابات نشطة قابلة للترحيل. جهّز شجرة الحسابات أولاً.');
      return;
    }

    final description = TextEditingController();
    DateTime entryDate = DateTime.now();
    final lines = <_JournalLineDraft>[_JournalLineDraft(), _JournalLineDraft()];
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('إنشاء قيد يومية — مسودة'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'بيان القيد *'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: entryDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) refresh(() => entryDate = selected);
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text('تاريخ القيد: ${entryDate.year}-${entryDate.month.toString().padLeft(2, '0')}-${entryDate.day.toString().padLeft(2, '0')}'),
                  ),
                  const SizedBox(height: 12),
                  const Text('سطور القيد', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  ...List.generate(lines.length, (index) {
                    final line = lines[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Row(children: [
                              Text('السطر ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              const Spacer(),
                              if (lines.length > 2)
                                IconButton(
                                  tooltip: 'حذف السطر',
                                  onPressed: () => refresh(() {
                                    lines.removeAt(index).dispose();
                                  }),
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                ),
                            ]),
                            DropdownButtonFormField<String>(
                              value: line.accountId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'الحساب القابل للترحيل *'),
                              items: accounts.map((a) => DropdownMenuItem<String>(
                                value: (a['id'] ?? '').toString(),
                                child: Text('${a['account_code']} — ${a['account_name']}', overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) => refresh(() => line.accountId = v),
                            ),
                            TextField(
                              controller: line.memo,
                              decoration: const InputDecoration(labelText: 'بيان السطر (اختياري)'),
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(child: TextField(
                                controller: line.debit,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'مدين', prefixText: 'ج.م '),
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(
                                controller: line.credit,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'دائن', prefixText: 'ج.م '),
                              )),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => refresh(() => lines.add(_JournalLineDraft())),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة سطر'),
                    ),
                  ),
                  _totals(lines),
                  if (dialogError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(dialogError!, style: const TextStyle(color: Colors.red)),
                    ),
                  const Text(
                    'سيُحفظ القيد كمسودة. الترحيل النهائي يتطلب توازن المدين والدائن وصلاحيات قاعدة البيانات.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final payload = <Map<String, dynamic>>[];
                for (var i = 0; i < lines.length; i++) {
                  final line = lines[i];
                  final debit = double.tryParse(line.debit.text.trim()) ?? 0;
                  final credit = double.tryParse(line.credit.text.trim()) ?? 0;
                  if (line.accountId == null) {
                    refresh(() => dialogError = 'اختر الحساب في السطر ${i + 1}.');
                    return;
                  }
                  if (debit < 0 || credit < 0 || !((debit > 0 && credit == 0) || (credit > 0 && debit == 0))) {
                    refresh(() => dialogError = 'السطر ${i + 1}: أدخل مبلغًا موجبًا في المدين أو الدائن فقط.');
                    return;
                  }
                  payload.add({
                    'account_id': line.accountId,
                    'description': line.memo.text.trim(),
                    'debit': debit,
                    'credit': credit,
                  });
                }
                if (description.text.trim().isEmpty) {
                  refresh(() => dialogError = 'اكتب بيان القيد.');
                  return;
                }
                try {
                  await _repo.saveDraft(
                    companyId: _company.text.trim(),
                    entryDate: entryDate,
                    description: description.text,
                    lines: payload,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _load();
                } catch (e) {
                  refresh(() => dialogError = 'تعذر حفظ المسودة: $e');
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ كمسودة'),
            ),
          ],
        ),
      ),
    );
    description.dispose();
    for (final line in lines) {
      line.dispose();
    }
  }

  Widget _totals(List<_JournalLineDraft> lines) {
    double sum(TextEditingController Function(_JournalLineDraft) select) =>
        lines.fold<double>(0, (total, line) =>
          total + (double.tryParse(select(line).text.trim()) ?? 0));
    final debit = sum((line) => line.debit);
    final credit = sum((line) => line.credit);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          Text('إجمالي المدين: ${debit.toStringAsFixed(2)} ج.م'),
          Text('إجمالي الدائن: ${credit.toStringAsFixed(2)} ج.م'),
          Text(
            'الفرق: ${(debit - credit).toStringAsFixed(2)} ج.م',
            style: TextStyle(
              color: (debit - credit).abs() < 0.005 ? Colors.green : Colors.red,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _post(Map<String, dynamic> entry) async {
    final id = _str(entry, 'id');
    final number = _str(entry, 'entry_number');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ترحيل القيد'),
        content: Text('سيتم ترحيل القيد رقم $number. لا يمكن تعديل القيد بعد الترحيل من خلال مسار المسودات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ترحيل')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.postEntry(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب ترحيل القيد إلى قاعدة البيانات.')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر ترحيل القيد: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(
              child: Text('قيود اليومية', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF3E007D),
              )),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _createDraft,
              icon: const Icon(Icons.add),
              label: const Text('قيد جديد'),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'إدارة مسودات القيود اليومية. الترحيل يخضع لفحوصات قاعدة البيانات وسياسات الصلاحيات.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _company,
            decoration: const InputDecoration(
              labelText: 'معرّف الشركة (UUID)',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('تحميل القيود'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          if (!_loading && _entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('أدخل معرّف الشركة واضغط تحميل القيود لعرض السجلات.'),
            ),
          ..._entries.map((entry) {
            final status = _str(entry, 'status');
            final posted = status == 'posted';
            final reversed = status == 'reversed';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: posted ? Colors.green.shade50 : const Color(0xFFF7F0FF),
                  child: Icon(
                    posted ? Icons.verified : reversed ? Icons.undo : Icons.edit_note,
                    color: posted ? Colors.green : const Color(0xFF3E007D),
                  ),
                ),
                title: Text('قيد رقم ${_str(entry, 'entry_number')} — ${_str(entry, 'description')}'),
                subtitle: Text(
                  'التاريخ: ${_str(entry, 'entry_date')} • الحالة: ${status == 'posted' ? 'مرحّل' : status == 'reversed' ? 'معكوس' : 'مسودة'}',
                ),
                isThreeLine: false,
                trailing: status == 'draft'
                    ? IconButton(
                        tooltip: 'ترحيل القيد',
                        onPressed: _loading ? null : () => _post(entry),
                        icon: const Icon(Icons.task_alt, color: Color(0xFFFFA015)),
                      )
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _JournalLineDraft {
  String? accountId;
  final memo = TextEditingController();
  final debit = TextEditingController();
  final credit = TextEditingController();

  void dispose() {
    memo.dispose();
    debit.dispose();
    credit.dispose();
  }
}
