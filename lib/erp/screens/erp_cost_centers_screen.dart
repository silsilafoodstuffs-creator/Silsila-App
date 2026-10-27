import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

const _costPurple = Color(0xFF3E007D);
const _costOrange = Color(0xFFFFA015);

class ErpCostCentersScreen extends StatefulWidget {
  const ErpCostCentersScreen({super.key, required this.companyId});
  final String? companyId;
  @override
  State<ErpCostCentersScreen> createState() => _ErpCostCentersScreenState();
}

class _ErpCostCentersScreenState extends State<ErpCostCentersScreen> {
  SupabaseClient? _db;
  List<Map<String, dynamic>> _centers = [];
  List<Map<String, dynamic>> _branches = [];
  String? _activeCompanyId;
  final Set<String> _selectedIds = {};
  final Set<String> _expandedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _viewMode = 'tree';
  bool _loading = false, _saving = false;
  int _loadGeneration = 0;
  String? _error, _message;

  String _s(dynamic v) => (v ?? '').toString();
  @override
  void dispose() { _searchController.dispose(); super.dispose(); }
  bool _matchesSearch(Map<String, dynamic> r) => _searchQuery.isEmpty || _s(r['center_code']).toLowerCase().contains(_searchQuery) || _ar(r).toLowerCase().contains(_searchQuery) || _s(r['center_name_en']).toLowerCase().contains(_searchQuery);
  String _ar(Map<String, dynamic> r) => _s(r['center_name_ar']).isEmpty ? _s(r['center_name']) : _s(r['center_name_ar']);
  bool _child(Map<String, dynamic> r) => _s(r['parent_id']).isNotEmpty;

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpCostCentersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) { _selectedIds.clear(); _load(); }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    var company = (widget.companyId ?? '').trim();
    if (!mounted) return;
    // Invalidate previous company scope immediately. A late network response
    // from an older load must never replace the currently selected company.
    _activeCompanyId = null;
    if (_db == null) {
      setState(() { _loading = false; _error = 'سجّل الدخول إلى Supabase أولًا.'; });
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    if (company.isEmpty) {
      try {
        final userId = _db!.auth.currentUser?.id;
        if (userId != null) {
          final memberships = await _db!
              .from('erp_company_members')
              .select('company_id')
              .eq('user_id', userId)
              .eq('is_active', true)
              .order('created_at')
              .limit(1);
          if (!mounted || generation != _loadGeneration) return;
          if (memberships.isNotEmpty) {
            company = (memberships.first['company_id'] ?? '').toString().trim();
          }
        }
      } catch (e) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _loading = false;
          _error = 'تعذر تحديد الشركة النشطة: $e';
        });
        return;
      }
    }
    if (!mounted || generation != _loadGeneration) return;
    if (company.isEmpty) {
      setState(() {
        _loading = false;
        _centers = [];
        _branches = [];
        _error = 'لا توجد شركة نشطة مرتبطة بالمستخدم.';
      });
      return;
    }
    try {
      final result = await Future.wait<dynamic>([
        _db!.from('erp_cost_centers')
            .select('id,center_code,center_name,center_name_ar,center_name_en,branch_id,parent_id,is_active')
            .eq('company_id', company).order('center_code'),
        _db!.from('erp_branches')
            .select('id,branch_code,branch_name')
            .eq('company_id', company).order('branch_code'),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _activeCompanyId = company;
        _centers = (result[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _branches = (result[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        // Open root nodes after every refresh so users immediately see the hierarchy.
        _expandedIds
          ..clear()
          ..addAll(_treeRoots.map((r) => _s(r['id'])).where((id) => id.isNotEmpty));
        _selectedIds.removeWhere((id) => !_centers.any((r) => _s(r['id']) == id));
        _loading = false;
        _error = _centers.isEmpty
            ? 'لم تُرجع قاعدة البيانات مراكز تكلفة لهذه الشركة. تحقق من الشركة النشطة وصلاحيات الوصول.'
            : null;
        _message = _centers.isEmpty ? null : 'تم تحميل ${_centers.length} مركز تكلفة.';
      });
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل مراكز التكلفة: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _tree {
    final out = <Map<String, dynamic>>[];
    final roots = _centers.where((r) => !_child(r)).toList()..sort((a,b) => _s(a['center_code']).compareTo(_s(b['center_code'])));
    for (final root in roots) {
      out.add(root);
      final children = _centers.where((r) => _s(r['parent_id']) == _s(root['id'])).toList()
        ..sort((a,b) => _s(a['center_code']).compareTo(_s(b['center_code'])));
      out.addAll(children);
    }
    for (final row in _centers) {
      if (!out.any((r) => _s(r['id']) == _s(row['id']))) out.add(row);
    }
    return out;
  }

  List<Map<String, dynamic>> get _treeRoots {
    final ids = _centers.map((r) => _s(r['id'])).where((id) => id.isNotEmpty).toSet();
    final roots = _centers.where((r) {
      final parentId = _s(r['parent_id']);
      return parentId.isEmpty || !ids.contains(parentId);
    }).toList()
      ..sort((a, b) => _s(a['center_code']).compareTo(_s(b['center_code'])));
    // Recover gracefully if legacy data contains a cycle and therefore has no root.
    return roots.isEmpty
        ? ([..._centers]..sort((a, b) => _s(a['center_code']).compareTo(_s(b['center_code']))))
        : roots;
  }

  String _newCode() {
    var max = 0;
    for (final r in _centers) {
      final m = RegExp(r'(\d+)$').firstMatch(_s(r['center_code']));
      final n = int.tryParse(m?.group(1) ?? '') ?? 0;
      if (n > max) max = n;
    }
    return 'CC-${(max + 1).toString().padLeft(3, '0')}';
  }

  void _addMain() {
    setState(() {
      _centers.add({'id': null, 'center_code': _newCode(), 'center_name': '', 'center_name_ar': '', 'center_name_en': '', 'branch_id': null, 'parent_id': null, 'is_active': true, '_draft': true});
      _message = 'أُضيف صف مركز رئيسي. أكمل البيانات واضغط حفظ.';
      _error = null;
    });
  }

  void _addChild(Map<String, dynamic> parent) {
    if (_s(parent['id']).isEmpty) { setState(() => _error = 'احفظ المركز الرئيسي أولًا ثم أضف المركز الفرعي.'); return; }
    if (_child(parent)) { setState(() => _error = 'المركز الفرعي لا يمكن أن يكون أبًا لمركز آخر.'); return; }
    setState(() {
      _centers.add({'id': null, 'center_code': _newCode(), 'center_name': '', 'center_name_ar': '', 'center_name_en': '', 'branch_id': parent['branch_id'], 'parent_id': parent['id'], 'is_active': true, '_draft': true});
      _message = 'أُضيف صف فرعي تحت المركز الرئيسي المحدد.';
      _error = null;
    });
  }

  Future<void> _save() async {
    final db = _db;
    final company = (_activeCompanyId ?? '').trim();
    if (db == null || company.isEmpty) {
      if (mounted) setState(() => _error = 'لا يمكن الحفظ قبل تحديد الشركة النشطة. حدّث الشاشة وتحقق من عضوية المستخدم.');
      return;
    }
    final codes = <String>{};
    for (final r in _centers) {
      final code = _s(r['center_code']).trim();
      if (code.isEmpty || _ar(r).trim().isEmpty) { setState(() => _error = 'الكود والاسم العربي مطلوبان في كل صف.'); return; }
      if (!RegExp(r'^[A-Za-z]+-[0-9]+$').hasMatch(code)) { setState(() => _error = 'الكود "$code" غير صحيح. استخدم حروفًا إنجليزية ثم شرطة وأرقامًا، مثل CC-001.'); return; }
      if (!codes.add(code.toUpperCase())) { setState(() => _error = 'الكود "$code" مكرر.'); return; }
      if (_child(r) && !_centers.any((p) => _s(p['id']) == _s(r['parent_id']) && !_child(p))) {
        setState(() => _error = 'كل مركز فرعي يجب أن يتبع مركزًا رئيسيًا محفوظًا.'); return;
      }
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final ordered = [..._centers.where((r) => !_child(r)), ..._centers.where(_child)];
      for (final r in ordered) {
        final ar = _ar(r).trim();
        final branch = _s(r['branch_id']).trim();
        final payload = <String, dynamic>{
          'company_id': company, 'center_code': _s(r['center_code']).trim(),
          'center_name': ar, 'center_name_ar': ar,
          'center_name_en': _s(r['center_name_en']).trim().isEmpty ? null : _s(r['center_name_en']).trim(),
          'branch_id': branch.isEmpty ? null : branch,
          'parent_id': _s(r['parent_id']).isEmpty ? null : r['parent_id'],
          'is_active': r['is_active'] == true,
        };
        if (_s(r['id']).isEmpty) {
          final inserted = await db.from('erp_cost_centers').insert(payload).select('id').single();
          r['id'] = inserted['id'];
          r.remove('_draft');
        } else {
          await db.from('erp_cost_centers').update(payload).eq('id', r['id']).eq('company_id', company);
        }
      }
      if (mounted) setState(() => _message = 'تم حفظ جميع مراكز التكلفة في قاعدة البيانات.');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر حفظ مراكز التكلفة: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic>? get _selected {
    if (_selectedIds.length != 1) return null;
    for (final r in _centers) { if (_s(r['id']) == _selectedIds.single) return r; }
    return null;
  }

  String _branchName(dynamic id) {
    for (final b in _branches) { if (_s(b['id']) == _s(id)) return '${_s(b['branch_code'])} — ${_s(b['branch_name'])}'; }
    return 'بدون فرع';
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = _s(row['id']);
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف مركز التكلفة'),
      content: Text('هل تريد حذف «${_ar(row)}»؟ قد تمنع قاعدة البيانات الحذف إذا ارتبط المركز بفروع فرعية أو بحركات مالية.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No / لا')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes / نعم، احذف')),
      ],
    ));
    if (yes != true) return;
    if (id.isEmpty) {
      setState(() { _centers.remove(row); _message = 'تم حذف الصف غير المحفوظ.'; _error = null; });
      return;
    }
    try {
      final company = (_activeCompanyId ?? '').trim();
      if (company.isEmpty) throw StateError('لا توجد شركة نشطة مرتبطة بالمستخدم.');
      await _db!.from('erp_cost_centers').delete().eq('id', id).eq('company_id', company);
      if (mounted) setState(() { _centers.removeWhere((r) => _s(r['id']) == id); _selectedIds.remove(id); _message = 'تم حذف المركز.'; _error = null; });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر الحذف؛ قد يكون المركز مرتبطًا بمراكز فرعية أو بحركات مالية: $e');
    }
  }

  Future<void> _editSelected() async {
    if (_selected == null) { setState(() => _error = 'حدد صفًا واحدًا أولًا.'); return; }
    setState(() => _message = 'عدّل الحقول مباشرة في الصف المحدد، ثم اضغط حفظ.');
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
  );

  Widget _task(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _preview() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة مراكز التكلفة'),
      content: SizedBox(width: 750, child: SingleChildScrollView(child: DataTable(
        headingRowHeight: 34, dataRowMinHeight: 30, dataRowMaxHeight: 36,
        columns: const [DataColumn(label: Text('الكود')), DataColumn(label: Text('الاسم العربي')), DataColumn(label: Text('الاسم الإنجليزي')), DataColumn(label: Text('النوع')), DataColumn(label: Text('الفرع')), DataColumn(label: Text('الحالة'))],
        rows: _tree.map((r) => DataRow(cells: [
          DataCell(Text(_s(r['center_code']))), DataCell(Text('${_child(r) ? '↳ ' : ''}${_ar(r)}')),
          DataCell(Text(_s(r['center_name_en']))), DataCell(Text(_child(r) ? 'فرعي' : 'رئيسي')),
          DataCell(Text(_branchName(r['branch_id']))), DataCell(Text(r['is_active'] == true ? 'نشط' : 'غير نشط')),
        ])).toList(),
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  Future<void> _copyReport(String format) async {
    final lines = <String>[
      'م\tكود مركز التكلفة\tاسم عربي\tاسم إنجليزي\tالنوع\tالفرع\tالحالة',
      ..._tree.asMap().entries.map((e) {
        final r = e.value;
        return '${e.key + 1}\t${_s(r['center_code'])}\t${_ar(r)}\t${_s(r['center_name_en'])}\t${_child(r) ? 'فرعي' : 'رئيسي'}\t${_branchName(r['branch_id'])}\t${r['is_active'] == true ? 'نشط' : 'غير نشط'}';
      }),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) setState(() => _message = 'تم نسخ بيانات الجدول إلى الحافظة. يمكنك لصقها في Excel ($format).');
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(color: _costPurple, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('مراكز التكلفة', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
          const Text('إدارة المراكز الرئيسية والفرعية وربطها بالفروع.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 5),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _task('تحديث', Icons.refresh, Colors.blue, _loading || _saving ? null : _load),
            _task('عرض شجرة', Icons.account_tree_outlined, _viewMode == 'tree' ? _costPurple : Colors.grey, () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _viewMode = 'tree';
                _error = null;
              });
              _load();
            }),
            _task('عرض جدول', Icons.table_rows_outlined, _viewMode == 'grid' ? _costPurple : Colors.grey, () => setState(() => _viewMode = 'grid')),
            _task('فتح الكل', Icons.unfold_more, _costOrange, _loading || _saving ? null : () => setState(() => _expandedIds.addAll(_centers.map((r) => _s(r['id'])).where((id) => id.isNotEmpty)))),
            _task('طي الكل', Icons.unfold_less, Colors.grey, _loading || _saving ? null : () => setState(() => _expandedIds.clear())),
            _task('إضافة', Icons.add_circle_outline, Colors.green, _loading || _saving ? null : _addMain),
            _task('حفظ', Icons.save_outlined, _costPurple, _loading || _saving ? null : _save),
            _task('تعديل', Icons.edit_outlined, _costOrange, _selected == null ? null : _editSelected),
            _task('حذف', Icons.delete_outline, Colors.red, _selected == null ? null : () => _delete(_selected!)),
            _task('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _preview),
            _task('طباعة', Icons.print_outlined, const Color(0xFFFF27C3), _preview),
            _task('Excel', Icons.table_view_outlined, const Color(0xFF16834A), () => _copyReport('Excel/TSV')),
            _task('PDF', Icons.picture_as_pdf_outlined, Colors.red, () => _copyReport('PDF')),
          ])),
        ]),
      )),
      Padding(padding: const EdgeInsets.fromLTRB(10, 7, 10, 4), child: TextField(controller: _searchController, onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()), decoration: InputDecoration(labelText: 'ابحث بكود أو اسم مركز التكلفة', prefixIcon: const Icon(Icons.search, color: _costPurple), suffixIcon: _searchQuery.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }, icon: const Icon(Icons.clear)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true))),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_loading && _centers.isEmpty) const Expanded(child: Center(child: CircularProgressIndicator())),
      if (!(_loading && _centers.isEmpty) && _viewMode == 'tree')
        Expanded(child: ListView(
          padding: const EdgeInsets.all(8),
          children: _treeRoots.where(_branchMatches).map((r) => _treeNode(r, 0, <String>{})).toList(),
        )),
      if (!(_loading && _centers.isEmpty) && _viewMode == 'grid')
        Expanded(child: Scrollbar(child: SingleChildScrollView(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 38, dataRowMinHeight: 38, dataRowMaxHeight: 42,
            horizontalMargin: 8, columnSpacing: 11, dividerThickness: .6,
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: _costPurple, fontSize: 12),
            columns: const [
              DataColumn(label: Text('تحديد')), DataColumn(label: Text('م')),
              DataColumn(label: Text('كود مركز تكلفة')), DataColumn(label: Text('اسم مركز التكلفة عربي')),
              DataColumn(label: Text('اسم مركز التكلفة إنجليزي')), DataColumn(label: Text('نوع المركز')),
              DataColumn(label: Text('الفرع (اختياري)')), DataColumn(label: Text('نشط')),
              DataColumn(label: Text('إضافة فرعي')), DataColumn(label: Text('حذف')),
            ],
            rows: _tree.asMap().entries.map((entry) {
              final i = entry.key; final r = entry.value; final isChild = _child(r);
              final id = _s(r['id']); final draft = id.isEmpty;
              final selected = id.isNotEmpty && _selectedIds.contains(id);
              return DataRow(
                selected: selected,
                color: WidgetStateProperty.resolveWith<Color?>((states) =>
                  states.contains(WidgetState.selected) ? _costPurple.withValues(alpha: .08) : (isChild ? const Color(0xFFF8F4FC) : Colors.white)),
                cells: [
                  DataCell(Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: selected, activeColor: _costPurple,
                    onChanged: draft ? null : (v) => setState(() { if (v == true) { _selectedIds.add(id); } else { _selectedIds.remove(id); } }))),
                  DataCell(SizedBox(width: 25, child: Text('${i + 1}', style: const TextStyle(fontSize: 12)))),
                  DataCell(SizedBox(width: 115, child: TextFormField(key: ValueKey('code-$id-$i'), initialValue: _s(r['center_code']),
                    onChanged: (v) => r['center_code'] = v, decoration: _dec('CC-001'), style: const TextStyle(fontSize: 12)))),
                  DataCell(SizedBox(width: 165, child: Padding(
                    padding: EdgeInsetsDirectional.only(start: isChild ? 16 : 0),
                    child: TextFormField(key: ValueKey('ar-$id-$i'), initialValue: _ar(r),
                      onChanged: (v) { r['center_name_ar'] = v; r['center_name'] = v; },
                      decoration: _dec(isChild ? 'اسم المركز الفرعي' : 'اسم المركز الرئيسي'),
                      style: TextStyle(fontSize: 12, fontWeight: isChild ? FontWeight.normal : FontWeight.w700)),
                  ))),
                  DataCell(SizedBox(width: 155, child: TextFormField(key: ValueKey('en-$id-$i'), initialValue: _s(r['center_name_en']),
                    onChanged: (v) => r['center_name_en'] = v, decoration: _dec('Cost center name'),
                    textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12)))),
                  DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: isChild ? const Color(0xFFEDE3FA) : const Color(0xFFE5F2EA), borderRadius: BorderRadius.circular(7)),
                    child: Text(isChild ? 'فرعي' : 'رئيسي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isChild ? _costPurple : const Color(0xFF176B3A))))),
                  DataCell(SizedBox(width: 175, child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                    isExpanded: true, isDense: true,
                    value: _branches.any((b) => _s(b['id']) == _s(r['branch_id'])) ? _s(r['branch_id']) : '',
                    items: [
                      const DropdownMenuItem(value: '', child: Text('بدون فرع', style: TextStyle(fontSize: 11))),
                      ..._branches.map((b) => DropdownMenuItem(value: _s(b['id']), child: Text('${_s(b['branch_code'])} — ${_s(b['branch_name'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)))),
                    ],
                    onChanged: (v) => setState(() => r['branch_id'] = v == null || v.isEmpty ? null : v),
                  )))),
                  DataCell(Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: r['is_active'] == true, activeColor: Colors.green,
                    onChanged: (v) => setState(() { r['is_active'] = v == true; _message = 'تم تغيير الحالة محليًا؛ اضغط حفظ لاعتمادها.'; }))),
                  DataCell(!isChild && !draft ? IconButton(tooltip: 'إضافة مركز تكلفة فرعي', visualDensity: VisualDensity.compact,
                    onPressed: _saving ? null : () => _addChild(r), icon: const Icon(Icons.add_circle, color: _costPurple, size: 21)) : const SizedBox(width: 32)),
                  DataCell(IconButton(tooltip: 'حذف المركز', visualDensity: VisualDensity.compact, onPressed: _saving ? null : () => _delete(r),
                    icon: const Icon(Icons.delete_forever, color: Colors.red, size: 22))),
                ],
              );
            }).toList(),
          ),
        )))),
    ]),
  );

  bool _branchMatches(Map<String, dynamic> row) => _branchMatchesVisited(row, <String>{});

  bool _branchMatchesVisited(Map<String, dynamic> row, Set<String> visited) {
    if (_matchesSearch(row)) return true;
    final id = _s(row['id']);
    if (id.isEmpty || !visited.add(id)) return false;
    return _centers
        .where((child) => _s(child['parent_id']) == id)
        .any((child) => _branchMatchesVisited(child, visited));
  }

  List<Map<String, dynamic>> _childrenOfCenter(Map<String, dynamic> row) {
    final id = _s(row['id']);
    if (id.isEmpty) return <Map<String, dynamic>>[];
    return _centers.where((child) => _s(child['parent_id']) == id).toList()
      ..sort((a, b) => _s(a['center_code']).compareTo(_s(b['center_code'])));
  }

  Widget _treeNode(Map<String, dynamic> row, int depth, Set<String> visited) {
    final id = _s(row['id']);
    // Protect the tree view from malformed legacy parent links and cycles.
    if (id.isNotEmpty && !visited.add(id)) return const SizedBox.shrink();
    final children = _childrenOfCenter(row).where((item) {
      final childId = _s(item['id']);
      return childId.isEmpty || !visited.contains(childId);
    }).toList();
    final child = _child(row);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsetsDirectional.only(start: depth * 18, bottom: 5),
        child: Card(
          color: depth == 0 ? const Color(0xFFEDE1F8) : depth == 1 ? const Color(0xFFFFE4BE) : const Color(0xFFFFDDF3),
          child: ListTile(
            dense: true,
            leading: Icon(child ? Icons.subdirectory_arrow_left : Icons.account_tree_outlined, color: _costPurple),
            title: Text('${_s(row['center_code'])} — ${_ar(row)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${_s(row['center_name_en'])} • ${_branchName(row['branch_id'])} • ${row['is_active'] == true ? 'نشط' : 'غير نشط'}'),
            selected: id.isNotEmpty && _selectedIds.contains(id),
            onTap: id.isEmpty ? null : () => setState(() { if (_selectedIds.contains(id)) { _selectedIds.remove(id); } else { _selectedIds..clear()..add(id); } }),
            trailing: Wrap(spacing: 0, children: [
              if (!child && id.isNotEmpty) IconButton(tooltip: 'إضافة مركز فرعي', onPressed: _saving ? null : () => _addChild(row), icon: const Icon(Icons.add_circle_outline, color: _costPurple)),
              IconButton(tooltip: 'حذف المركز', onPressed: _saving ? null : () => _delete(row), icon: const Icon(Icons.delete_outline, color: Colors.red)),
            ]),
          ),
        ),
      ),
      if (id.isNotEmpty && children.isNotEmpty)
        Padding(
          padding: EdgeInsetsDirectional.only(start: depth * 18 + 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() {
                if (_expandedIds.contains(id)) {
                  _expandedIds.remove(id);
                } else {
                  _expandedIds.add(id);
                }
              }),
              icon: Icon(_expandedIds.contains(id) ? Icons.expand_less : Icons.expand_more, size: 17),
              label: Text(_expandedIds.contains(id) ? 'طي الفروع' : 'عرض الفروع (${children.length})'),
            ),
          ),
        ),
      if (id.isEmpty || _expandedIds.contains(id))
        ...children.where(_branchMatches).map((item) => _treeNode(item, depth + 1, visited)),
    ]);
  }

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 5), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: .25))),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
  );
}
