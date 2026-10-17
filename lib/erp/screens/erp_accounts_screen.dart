import 'package:flutter/material.dart';
import '../services/erp_accounts_repository.dart';

class ErpAccountsScreen extends StatefulWidget {
  const ErpAccountsScreen({super.key, this.initialCompanyId, this.initialSearch});

  final String? initialCompanyId;
  final String? initialSearch;

  @override
  State<ErpAccountsScreen> createState() => _ErpAccountsScreenState();
}

class _ErpAccountsScreenState extends State<ErpAccountsScreen> {
  final _repo = ErpAccountsRepository();
  final _company = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  bool _activeOnly = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _search.text = widget.initialSearch ?? '';
  }

  @override
  void dispose() {
    _company.dispose();
    _search.dispose();
    super.dispose();
  }

  String _value(Map<String, dynamic> row, String key) =>
      (row[key] ?? '').toString();

  double _amount(Map<String, dynamic> row) =>
      double.tryParse(_value(row, 'subtree_net_balance')) ?? 0;

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
      final result = await _repo.fetchAccountMetrics(
        companyId: _company.text.trim(),
        activeOnly: _activeOnly,
      );
      if (!mounted) return;
      setState(() {
        _rows = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الحسابات: $e';
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) =>
      _value(r, 'account_code').toLowerCase().contains(q) ||
      _value(r, 'account_name').toLowerCase().contains(q)
    ).toList();
  }

  Set<String> _descendantsOf(String accountId) {
    final childrenByParent = <String, List<String>>{};
    for (final row in _rows) {
      final id = _value(row, 'account_id');
      final parentId = _value(row, 'parent_id');
      if (id.isNotEmpty && parentId.isNotEmpty) {
        childrenByParent.putIfAbsent(parentId, () => <String>[]).add(id);
      }
    }
    final descendants = <String>{};
    final pending = <String>[accountId];
    while (pending.isNotEmpty) {
      for (final child in childrenByParent[pending.removeLast()] ?? const <String>[]) {
        if (descendants.add(child)) pending.add(child);
      }
    }
    return descendants;
  }

  Future<void> _openAccountEditor({Map<String, dynamic>? account}) async {
    final editing = account != null;
    final id = editing ? _value(account, 'account_id') : '';
    final code = TextEditingController(text: editing ? _value(account, 'account_code') : '');
    final name = TextEditingController(text: editing ? _value(account, 'account_name') : '');
    String type = editing ? _value(account, 'account_type') : 'asset';
    String nature = editing ? _value(account, 'normal_balance') : 'debit';
    String parent = editing ? _value(account, 'parent_id') : '';
    bool postable = editing ? account['is_postable'] == true : false;
    bool active = editing ? account['is_active'] == true : true;
    final descendants = editing ? _descendantsOf(id) : <String>{};
    final allowedParents = _rows.where((r) {
      final candidateId = _value(r, 'account_id');
      return r['is_postable'] != true &&
          candidateId != id &&
          !descendants.contains(candidateId);
    }).toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(editing ? 'تعديل حساب' : 'إضافة حساب'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: code, decoration: const InputDecoration(labelText: 'كود الحساب *')),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الحساب *')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'نوع الحساب'),
                    items: const [
                      DropdownMenuItem(value: 'asset', child: Text('أصول')),
                      DropdownMenuItem(value: 'liability', child: Text('التزامات')),
                      DropdownMenuItem(value: 'equity', child: Text('حقوق ملكية')),
                      DropdownMenuItem(value: 'revenue', child: Text('إيرادات')),
                      DropdownMenuItem(value: 'expense', child: Text('مصروفات')),
                    ],
                    onChanged: (v) { if (v != null) refresh(() => type = v); },
                  ),
                  DropdownButtonFormField<String>(
                    value: nature,
                    decoration: const InputDecoration(labelText: 'طبيعة الرصيد'),
                    items: const [
                      DropdownMenuItem(value: 'debit', child: Text('مدين')),
                      DropdownMenuItem(value: 'credit', child: Text('دائن')),
                    ],
                    onChanged: (v) { if (v != null) refresh(() => nature = v); },
                  ),
                  DropdownButtonFormField<String>(
                    value: parent,
                    decoration: const InputDecoration(labelText: 'الحساب الأب'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('حساب رئيسي')),
                      ...allowedParents.map((r) => DropdownMenuItem(
                        value: _value(r, 'account_id'),
                        child: Text('${_value(r, 'account_code')} — ${_value(r, 'account_name')}'),
                      )),
                    ],
                    onChanged: (v) => refresh(() => parent = v ?? ''),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('حساب تحليلي قابل للترحيل'),
                    value: postable,
                    onChanged: (v) => refresh(() => postable = v),
                  ),
                  if (editing)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('الحساب نشط'),
                      value: active,
                      onChanged: (v) => refresh(() => active = v),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
                  refresh(() {});
                  return;
                }
                Navigator.pop(ctx);
                try {
                  if (editing) {
                    await _repo.updateAccount(
                      companyId: _company.text.trim(),
                      accountId: id,
                      code: code.text,
                      name: name.text,
                      accountType: type,
                      normalBalance: nature,
                      parentId: parent.isEmpty ? null : parent,
                      isPostable: postable,
                      isActive: active,
                    );
                  } else {
                    await _repo.createAccount(
                      companyId: _company.text.trim(),
                      code: code.text,
                      name: name.text,
                      accountType: type,
                      normalBalance: nature,
                      parentId: parent.isEmpty ? null : parent,
                      isPostable: postable,
                    );
                  }
                  await _load();
                } catch (e) {
                  if (mounted) setState(() => _error = 'تعذر ${editing ? 'تعديل' : 'إنشاء'} الحساب: $e');
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(
            child: Text('شجرة الحسابات الفعلية', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF3E007D),
            )),
          ),
          FilledButton.icon(
            onPressed: _loading ? null : () => _openAccountEditor(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة حساب'),
          ),
        ]),
        const SizedBox(height: 8),
        const Text(
          'تحتاج الشاشة إلى معرّف الشركة الصحيح وتطبيق مخططات SQL وسياسات الصلاحيات في Supabase.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _company,
          decoration: const InputDecoration(
            labelText: 'معرّف الشركة (UUID)',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.vpn_key_outlined),
          ),
          onSubmitted: (_) => _load(),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(labelText: 'بحث بالكود أو الاسم', prefixIcon: Icon(Icons.search)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('النشطة فقط'),
            selected: _activeOnly,
            onSelected: (v) {
              setState(() => _activeOnly = v);
              if (_company.text.trim().isNotEmpty) _load();
            },
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_loading) const LinearProgressIndicator(),
        const SizedBox(height: 10),
        if (!_loading && rows.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Text('أدخل معرّف الشركة واضغط تحديث لعرض الحسابات.')),
        ...rows.map((r) => Card(
          child: ListTile(
            leading: Icon(
              r['is_postable'] == true ? Icons.account_balance_wallet : Icons.account_tree,
              color: const Color(0xFF3E007D),
            ),
            title: Text('${_value(r, 'account_code')} — ${_value(r, 'account_name')}'),
            subtitle: Text(
              '${_value(r, 'account_type')} • ${_value(r, 'normal_balance') == 'debit' ? 'مدين' : 'دائن'} • ${r['is_postable'] == true ? 'تحليلي' : 'تجميعي'} • ${r['is_active'] == true ? 'نشط' : 'معطل'}\n'
              'الرصيد: ${_amount(r).toStringAsFixed(2)} ج.م • الحركات: ${_value(r, 'subtree_movement_count')}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'تعديل الحساب',
              icon: const Icon(Icons.edit_outlined, color: Color(0xFFFFA015)),
              onPressed: _loading ? null : () => _openAccountEditor(account: r),
            ),
          ),
        )),
      ],
    );
  }
}
