import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
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
  final Set<String> _expandedAccounts = <String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    _search.text = widget.initialSearch ?? '';
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _company.dispose();
    _search.dispose();
    super.dispose();
  }

  String _value(Map<String, dynamic> row, String key) =>
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
      final result = await _repo.fetchAccountMetrics(
        companyId: _company.text.trim(),
        activeOnly: _activeOnly,
      );
      if (!mounted) return;
      setState(() {
        _rows = result;
        _expandedAccounts.addAll(result.where((row) => _value(row, 'parent_id').isEmpty).map((row) => _value(row, 'account_id')));
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

  Future<void> _openAccountEditor({Map<String, dynamic>? account, String? initialParentId}) async {
    final editing = account != null;
    final id = editing ? _value(account, 'account_id') : '';
    final code = TextEditingController(text: editing ? _value(account, 'account_code') : '');
    final name = TextEditingController(text: editing ? _value(account, 'account_name') : '');
    String type = editing ? _value(account, 'account_type') : 'asset';
    String nature = editing ? _value(account, 'normal_balance') : 'debit';
    String parent = editing ? _value(account, 'parent_id') : (initialParentId ?? '');
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


  List<Map<String, dynamic>> _childrenOf(String parentId) {
    final rows = _filtered;
    return rows.where((row) => _value(row, 'parent_id') == parentId).toList()
      ..sort((a, b) => _value(a, 'account_code').compareTo(_value(b, 'account_code')));
  }

  Future<void> _confirmDeactivate(Map<String, dynamic> account) async {
    final id = _value(account, 'account_id');
    final name = '${_value(account, 'account_code')} — ${_value(account, 'account_name')}';
    final children = _rows.any((row) => _value(row, 'parent_id') == id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تعطيل الحساب'),
        content: Text(
          'هل تريد تعطيل الحساب «$name»؟\n'
          '${children ? 'تنبيه: لهذا الحساب حسابات فرعية. لن تُحذف، وسيظل الحساب محفوظًا في قاعدة البيانات.' : 'لن يُحذف الحساب نهائيًا؛ سيتم تعطيله للحفاظ على السجلات المحاسبية.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تعطيل الحساب'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deactivateAccount(companyId: _company.text.trim(), accountId: id);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تعطيل الحساب: $e');
    }
  }

  Widget _buildTreeNode(Map<String, dynamic> row, int depth) {
    final id = _value(row, 'account_id');
    final children = _childrenOf(id);
    final hasChildren = children.isNotEmpty;
    final expanded = _expandedAccounts.contains(id);
    final isPostable = row['is_postable'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.only(left: depth * 20.0, bottom: 5),
          child: InkWell(
            onDoubleTap: () {
              if (!hasChildren) return;
              setState(() {
                if (expanded) { _expandedAccounts.remove(id); }
                else { _expandedAccounts.add(id); }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: IconButton(
                      tooltip: hasChildren ? (expanded ? 'طي الحسابات الفرعية' : 'عرض الحسابات الفرعية') : 'لا توجد حسابات فرعية',
                      visualDensity: VisualDensity.compact,
                      onPressed: hasChildren ? () => setState(() {
                        if (expanded) { _expandedAccounts.remove(id); }
                        else { _expandedAccounts.add(id); }
                      }) : null,
                      icon: Icon(
                        hasChildren ? (expanded ? Icons.remove_circle_outline : Icons.add_circle_outline) : Icons.circle,
                        size: hasChildren ? 21 : 8,
                        color: hasChildren ? const Color(0xFF3E007D) : Colors.black26,
                      ),
                    ),
                  ),
                  Icon(isPostable ? Icons.account_balance_wallet_outlined : Icons.account_tree_outlined,
                    color: const Color(0xFF3E007D), size: 21),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_value(row, 'account_code')} — ${_value(row, 'account_name')}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          '${_value(row, 'account_type')} • ${_value(row, 'normal_balance') == 'debit' ? 'مدين' : 'دائن'} • ${isPostable ? 'تحليلي' : 'تجميعي'} • ${row['is_active'] == true ? 'نشط' : 'معطل'}',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إضافة حساب فرعي تحت هذا الحساب',
                    visualDensity: VisualDensity.compact,
                    onPressed: _loading || isPostable ? null : () => _openAccountEditor(initialParentId: id),
                    icon: const Icon(Icons.add_box_outlined, color: Color(0xFF2E7D32)),
                  ),
                  IconButton(
                    tooltip: 'تعطيل الحساب',
                    visualDensity: VisualDensity.compact,
                    onPressed: _loading || row['is_active'] != true ? null : () => _confirmDeactivate(row),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  IconButton(
                    tooltip: 'تعديل الحساب',
                    visualDensity: VisualDensity.compact,
                    onPressed: _loading ? null : () => _openAccountEditor(account: row),
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFFFFA015)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasChildren && expanded) ...children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewAccounts() async {
    final rows = _filtered;
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة شجرة الحسابات'),
      content: SizedBox(width: 720, child: rows.isEmpty ? const Text('لا توجد حسابات للمعاينة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: rows.take(120).map((r) => ListTile(
          dense: true, title: Text('${_value(r, 'account_code')} — ${_value(r, 'account_name')}'),
          subtitle: Text('النوع: ${_value(r, 'account_type')} • ${r['is_postable'] == true ? 'يقبل الترحيل' : 'رئيسي'}'),
          trailing: IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined), onPressed: () { Navigator.pop(ctx); _openAccountEditor(account: r); }),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(color: const Color(0xFF3E007D), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('شجرة الحسابات الفعلية', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
              _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _loading ? null : () => _openAccountEditor()),
              _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewAccounts),
              _quickTask('تعديل', Icons.edit_outlined, const Color(0xFFEF9B13), _filtered.isEmpty ? null : () => _openAccountEditor(account: _filtered.first)),
              _quickTask('حذف/إيقاف', Icons.delete_outline, Colors.red, _filtered.isEmpty ? null : () => _confirmDeactivate(_filtered.first)),
            ])),
          ]),
        )),
        const SizedBox(height: 8),
        const Text('تحتاج الشاشة إلى معرّف الشركة الصحيح وتطبيق مخططات SQL وسياسات الصلاحيات في Supabase.',
          style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
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
        if (rows.isNotEmpty) ..._childrenOf('').map((row) => _buildTreeNode(row, 0)),

      ],
    );
  }
}
