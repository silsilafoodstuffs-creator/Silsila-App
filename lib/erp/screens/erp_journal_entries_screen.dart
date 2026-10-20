import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../services/erp_journal_repository.dart';

class ErpJournalEntriesScreen extends StatefulWidget {
  const ErpJournalEntriesScreen({super.key, this.initialCompanyId, this.initialEntryId, this.initialStatus});

  final String? initialCompanyId;
  final String? initialEntryId;
  final String? initialStatus;

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
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_company.text.trim().isNotEmpty) _load();
      if ((widget.initialEntryId ?? '').trim().isNotEmpty) _openInitialEntry();
    });
  }

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
      final allEntries = await _repo.fetchEntries(companyId: _company.text.trim());
      final entries = widget.initialStatus == null
          ? allEntries
          : allEntries.where((entry) => (entry['status'] ?? '').toString() == widget.initialStatus).toList();
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

  Future<void> _openInitialEntry() async {
    await _load();
    if (!mounted) return;
    Map<String, dynamic>? target;
    for (final entry in _entries) {
      if (_str(entry, 'id') == widget.initialEntryId) {
        target = entry;
        break;
      }
    }
    if (target == null) {
      setState(() => _error = 'لم يتم العثور على القيد المطلوب ضمن القيود المتاحة للمستخدم.');
      return;
    }
    if (_str(target, 'status') == 'draft') {
      await _createDraft(existing: target);
    } else {
      await _showEntryDetails(target);
    }
  }

  Future<void> _createDraft({Map<String, dynamic>? existing}) async {
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

    final description = TextEditingController(
      text: existing == null ? '' : _str(existing, 'description'),
    );
    DateTime entryDate = DateTime.tryParse(_str(existing ?? {}, 'entry_date')) ?? DateTime.now();
    final lines = <_JournalLineDraft>[];
    if (existing != null) {
      try {
        final savedLines = await _repo.fetchEntryLines(entryId: _str(existing, 'id'));
        for (final row in savedLines) {
          final line = _JournalLineDraft()
            ..accountId = _str(row, 'account_id')
            ..memo.text = _str(row, 'description')
            ..debit.text = _str(row, 'debit')
            ..credit.text = _str(row, 'credit');
          lines.add(line);
        }
      } catch (e) {
        description.dispose();
        setState(() => _error = 'تعذر تحميل سطور المسودة: $e');
        return;
      }
    }
    if (lines.isEmpty) lines.addAll([_JournalLineDraft(), _JournalLineDraft()]);
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(existing == null ? 'إنشاء قيد يومية — مسودة' : 'تعديل مسودة القيد رقم ${_str(existing, 'entry_number')}'),
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
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: dialogContext,
                                      builder: (confirmContext) => AlertDialog(
                                        title: const Text('تأكيد الحذف'),
                                        content: Text('هل ترغب في حذف السطر ${index + 1} من القيد؟'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(confirmContext, false),
                                            child: const Text('لا'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(confirmContext, true),
                                            child: const Text('نعم'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      refresh(() {
                                        if (index < lines.length) {
                                          lines.removeAt(index).dispose();
                                        }
                                      });
                                    }
                                  },
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
                                onChanged: (_) => refresh(() {}),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'مدين', prefixText: 'ج.م '),
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(
                                controller: line.credit,
                                onChanged: (_) => refresh(() {}),
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
                    entryId: existing == null ? null : _str(existing, 'id'),
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

  Future<void> _showEntryDetails(Map<String, dynamic> entry) async {
    final id = _str(entry, 'id');
    try {
      final lines = await _repo.fetchEntryLines(entryId: id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('تفاصيل القيد رقم ${_str(entry, 'entry_number')}'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('البيان: ${_str(entry, 'description')}'),
                  Text('التاريخ: ${_str(entry, 'entry_date')} • الحالة: ${_str(entry, 'status')}'),
                  const Divider(),
                  if (lines.isEmpty) const Text('لا توجد سطور متاحة لهذا القيد.'),
                  ...lines.map((line) {
                    final account = line['erp_accounts'];
                    final accountMap = account is Map
                        ? Map<String, dynamic>.from(account)
                        : <String, dynamic>{};
                    return ListTile(
                      dense: true,
                      title: Text('${accountMap['account_code'] ?? ''} — ${accountMap['account_name'] ?? _str(line, 'account_id')}'),
                      subtitle: Text(_str(line, 'description')),
                      trailing: Text('مدين ${_str(line, 'debit')}\nدائن ${_str(line, 'credit')}'),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            if (_str(entry, 'status') == 'draft')
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _createDraft(existing: entry);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل المسودة'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل تفاصيل القيد: $e');
    }
  }

  Future<void> _reverse(Map<String, dynamic> entry) async {
    final reason = TextEditingController();
    DateTime reversalDate = DateTime.now();
    String? dialogError;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text('إنشاء قيد عكس — رقم ${_str(entry, 'entry_number')}'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'سيُنشأ قيد جديد بعكس المدين والدائن، مع الاحتفاظ بالقيد الأصلي لأغراض المراجعة. لا يمكن تكرار عكس القيد نفسه.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'سبب العكس (إلزامي)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: reversalDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) refresh(() => reversalDate = picked);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text('تاريخ العكس: ${reversalDate.year}-${reversalDate.month.toString().padLeft(2, '0')}-${reversalDate.day.toString().padLeft(2, '0')}'),
                ),
                if (dialogError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(dialogError!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (reason.text.trim().isEmpty) {
                  refresh(() => dialogError = 'اكتب سبب العكس أولًا.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.undo),
              label: const Text('إنشاء قيد العكس'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      reason.dispose();
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _repo.reverseEntry(
        entryId: _str(entry, 'id'),
        reversalDate: reversalDate,
        reason: reason.text,
      );
      reason.dispose();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء قيد العكس. راجع دفتر الأستاذ للتأكد من ظهوره.')),
      );
    } catch (e) {
      reason.dispose();
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر إنشاء قيد العكس: $e'; });
    }
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

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewEntries() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة قيود اليومية'),
      content: SizedBox(width: 760, child: _entries.isEmpty ? const Text('لا توجد قيود محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _entries.take(100).map((entry) => ListTile(
          dense: true, leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF3E007D)),
          title: Text('قيد ${_str(entry, 'entry_number')} — ${_str(entry, 'description')}'),
          subtitle: Text('التاريخ: ${_str(entry, 'entry_date')} • الحالة: ${_str(entry, 'status')}'),
          onTap: () { Navigator.pop(ctx); _showEntryDetails(entry); },
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(color: const Color(0xFF3E007D), child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('قيود اليومية', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
                _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _loading ? null : _createDraft),
                _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewEntries),
                _quickTask('طباعة', Icons.print_outlined, const Color(0xFF4056A1), _previewEntries),
                _quickTask('استيراد Excel', Icons.file_upload_outlined, const Color(0xFF137C8B), () => setState(() => _error = 'استيراد قيود اليومية من Excel غير مفعّل؛ أنشئ المسودة من شاشة القيد للتحقق من التوازن.')),
                _quickTask('طباعة PDF', Icons.picture_as_pdf_outlined, const Color(0xFFB3261E), _previewEntries),
              ])),
            ]),
          )),
          const SizedBox(height: 8),
          const Text('إدارة مسودات القيود اليومية. الترحيل يخضع لفحوصات قاعدة البيانات وسياسات الصلاحيات.',
            style: TextStyle(color: Colors.black54, height: 1.5)),
          const SizedBox(height: 12),
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
                onTap: () => _showEntryDetails(entry),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'عرض السطور',
                      onPressed: _loading ? null : () => _showEntryDetails(entry),
                      icon: const Icon(Icons.visibility_outlined, color: Color(0xFF3E007D)),
                    ),
                    if (status == 'draft')
                      IconButton(
                        tooltip: 'تعديل المسودة',
                        onPressed: _loading ? null : () => _createDraft(existing: entry),
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFFFA015)),
                      ),
                    if (status == 'draft')
                      IconButton(
                        tooltip: 'ترحيل القيد',
                        onPressed: _loading ? null : () => _post(entry),
                        icon: const Icon(Icons.task_alt, color: Color(0xFF18865A)),
                      ),
                    if (status == 'posted')
                      IconButton(
                        tooltip: 'إنشاء قيد عكس',
                        onPressed: _loading ? null : () => _reverse(entry),
                        icon: const Icon(Icons.undo, color: Color(0xFFCE287A)),
                      ),
                  ],
                ),
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
