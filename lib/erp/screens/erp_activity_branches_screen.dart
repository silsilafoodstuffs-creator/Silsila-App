import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _activityPurple = Color(0xFF3E007D);

class ErpActivityBranchesScreen extends StatefulWidget {
  const ErpActivityBranchesScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpActivityBranchesScreen> createState() => _ErpActivityBranchesScreenState();
}

class _ErpActivityBranchesScreenState extends State<ErpActivityBranchesScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;
  List<Map<String, dynamic>> _workspaces = [];
  List<Map<String, dynamic>> _activities = [];
  final Map<String, List<Map<String, dynamic>>> _branchesByWorkspace = {};
  final Map<String, List<Map<String, dynamic>>> _warehousesByBranch = {};

  String _s(dynamic value) => (value ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ErpActivityBranchesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }

  Future<void> _load() async {
    final companyId = (widget.companyId ?? '').trim();
    if (companyId.isEmpty) {
      setState(() { _loading = false; _error = 'لا توجد شركة محددة.'; });
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final results = await Future.wait([
        _db.from('erp_business_workspaces')
            .select('id,workspace_name,activity_type,account_kind,is_active')
            .eq('platform_company_id', companyId)
            .order('created_at'),
        _db.from('activity_types')
            .select('code,name,name_en,is_active')
            .eq('is_active', true)
            .order('sort_order'),
      ]);
      final workspaces = (results[0] as List).whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
      final activities = (results[1] as List).whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
      final branchMap = <String, List<Map<String,dynamic>>>{};
      final warehouseMap = <String, List<Map<String,dynamic>>>{};
      for (final workspace in workspaces) {
        final workspaceId = _s(workspace['id']);
        final branches = await _db.from('erp_business_workspace_branches')
            .select('id,workspace_id,branch_code,name_ar,name_en,is_active')
            .eq('workspace_id', workspaceId).order('branch_code');
        final branchRows = (branches as List).whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
        branchMap[workspaceId] = branchRows;
        for (final branch in branchRows) {
          final branchId = _s(branch['id']);
          final warehouses = await _db.from('erp_business_workspace_warehouses')
              .select('id,workspace_id,branch_id,warehouse_code,name_ar,name_en,is_active')
              .eq('workspace_id', workspaceId).eq('branch_id', branchId).order('warehouse_code');
          warehouseMap[branchId] = (warehouses as List).whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
        }
      }
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _activities = activities;
        _branchesByWorkspace
          ..clear()
          ..addAll(branchMap);
        _warehousesByBranch
          ..clear()
          ..addAll(warehouseMap);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل فروع النشاطات ومخازنها: $e'; });
    }
  }

  String _activityName(Map<String,dynamic> workspace) {
    final code = _s(workspace['activity_type']);
    final matches = _activities.where((a) => _s(a['code']) == code);
    if (matches.isNotEmpty) return _s(matches.first['name']);
    return _s(workspace['workspace_name']).isEmpty ? 'نشاط غير محدد' : _s(workspace['workspace_name']);
  }

  Future<String> _nextCode(String key) async {
    final companyId = (widget.companyId ?? '').trim();
    final value = await _db.rpc('erp_preview_next_central_code', params: {
      'p_company_id': companyId,
      'p_entity_key': key,
    });
    final code = _s(value).trim();
    if (code.isEmpty) throw StateError('تعذر إنشاء كود تلقائي وفق سياسة التكويد.');
    return code;
  }

  Future<Map<String,String>?> _nameDialog({
    required String title,
    required String code,
    String nameAr = '',
    String nameEn = '',
  }) async {
    final ar = TextEditingController(text: nameAr);
    final en = TextEditingController(text: nameEn);
    final result = await showDialog<Map<String,String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 390, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(initialValue: code, readOnly: true, decoration: const InputDecoration(labelText: 'الكود (تلقائي)', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: ar, autofocus: true, decoration: const InputDecoration(labelText: 'الاسم بالعربية *', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: en, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية', border: OutlineInputBorder(), isDense: true)),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            if (ar.text.trim().isEmpty) return;
            Navigator.pop(ctx, {'ar': ar.text.trim(), 'en': en.text.trim()});
          }, child: const Text('حفظ')),
        ],
      ),
    );
    ar.dispose();
    en.dispose();
    return result;
  }

  Future<void> _addBranch(Map<String,dynamic> workspace) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final code = await _nextCode('workspace_branch');
      final names = await _nameDialog(title: 'إضافة فرع للنشاط', code: code);
      if (names == null) return;
      await _db.from('erp_business_workspace_branches').insert({
        'workspace_id': workspace['id'], 'branch_code': code,
        'name_ar': names['ar'], 'name_en': names['en']!.isEmpty ? null : names['en'],
        'is_active': true,
      });
      if (mounted) setState(() => _message = 'تمت إضافة الفرع.');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر إضافة الفرع: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editBranch(Map<String,dynamic> row) async {
    final names = await _nameDialog(title: 'تعديل الفرع', code: _s(row['branch_code']), nameAr: _s(row['name_ar']), nameEn: _s(row['name_en']));
    if (names == null) return;
    try {
      await _db.from('erp_business_workspace_branches').update({
        'name_ar': names['ar'], 'name_en': names['en']!.isEmpty ? null : names['en'],
      }).eq('id', row['id']).eq('workspace_id', row['workspace_id']);
      await _load();
    } catch (e) { if (mounted) setState(() => _error = 'تعذر تعديل الفرع: $e'); }
  }

  Future<void> _deleteBranch(Map<String,dynamic> row) async {
    final ok = await _confirmDelete('الفرع «${_s(row['name_ar'])}»');
    if (!ok) return;
    try {
      await _db.from('erp_business_workspace_branches').delete()
          .eq('id', row['id']).eq('workspace_id', row['workspace_id']);
      await _load();
    } catch (e) { if (mounted) setState(() => _error = 'لا يمكن حذف الفرع لارتباطه بمخازن أو حركات. عطّله بدلًا من حذفه عند وجود ارتباطات. $e'); }
  }

  Future<void> _addWarehouse(Map<String,dynamic> workspace, Map<String,dynamic> branch) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final code = await _nextCode('workspace_warehouse');
      final names = await _nameDialog(title: 'إضافة مخزن للفرع', code: code);
      if (names == null) return;
      await _db.from('erp_business_workspace_warehouses').insert({
        'workspace_id': workspace['id'], 'branch_id': branch['id'],
        'warehouse_code': code, 'name_ar': names['ar'],
        'name_en': names['en']!.isEmpty ? null : names['en'], 'is_active': true,
      });
      if (mounted) setState(() => _message = 'تمت إضافة المخزن للفرع.');
      await _load();
    } catch (e) { if (mounted) setState(() => _error = 'تعذر إضافة المخزن: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _editWarehouse(Map<String,dynamic> row) async {
    final names = await _nameDialog(title: 'تعديل المخزن', code: _s(row['warehouse_code']), nameAr: _s(row['name_ar']), nameEn: _s(row['name_en']));
    if (names == null) return;
    try {
      await _db.from('erp_business_workspace_warehouses').update({
        'name_ar': names['ar'], 'name_en': names['en']!.isEmpty ? null : names['en'],
      }).eq('id', row['id']).eq('workspace_id', row['workspace_id']);
      await _load();
    } catch (e) { if (mounted) setState(() => _error = 'تعذر تعديل المخزن: $e'); }
  }

  Future<void> _deleteWarehouse(Map<String,dynamic> row) async {
    final ok = await _confirmDelete('المخزن «${_s(row['name_ar'])}»');
    if (!ok) return;
    try {
      await _db.from('erp_business_workspace_warehouses').delete()
          .eq('id', row['id']).eq('workspace_id', row['workspace_id']);
      await _load();
    } catch (e) { if (mounted) setState(() => _error = 'لا يمكن حذف المخزن لارتباطه بحركات أو أرصدة. عطّله بدلًا من حذفه عند وجود ارتباطات. $e'); }
  }

  Future<bool> _confirmDelete(String label) async => await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: Text('هل تريد حذف $label؟ لا يمكن الحذف إذا كان مرتبطًا ببيانات تشغيلية.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ),
  ) ?? false;

  Future<void> _setActive(String table, Map<String,dynamic> row, bool active) async {
    try {
      await _db.from(table).update({'is_active': active}).eq('id', row['id']);
      await _load();
    } catch (e) { if (mounted) setState(() => _error = 'تعذر تغيير الحالة: $e'); }
  }

  Widget _status(bool active, ValueChanged<bool> onChanged) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(active ? 'نشط' : 'غير نشط', style: TextStyle(fontSize: 10, color: active ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w700)),
      Switch(value: active, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ],
  );

  Widget _actions(VoidCallback edit, VoidCallback delete) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(tooltip: 'تعديل', onPressed: edit, icon: const Icon(Icons.edit_outlined, size: 17, color: _activityPurple), visualDensity: VisualDensity.compact, constraints: const BoxConstraints.tightFor(width: 32, height: 32), padding: EdgeInsets.zero),
      IconButton(tooltip: 'حذف', onPressed: delete, icon: const Icon(Icons.delete_outline, size: 17, color: Colors.red), visualDensity: VisualDensity.compact, constraints: const BoxConstraints.tightFor(width: 32, height: 32), padding: EdgeInsets.zero),
    ],
  );

  Widget _branchesGrid(Map<String,dynamic> workspace) {
    final workspaceId = _s(workspace['id']);
    final branches = _branchesByWorkspace[workspaceId] ?? const <Map<String,dynamic>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('فروع النشاط', style: TextStyle(fontWeight: FontWeight.w800, color: _activityPurple))),
        TextButton.icon(onPressed: _busy ? null : () => _addBranch(workspace), icon: const Icon(Icons.add, size: 17), label: const Text('إضافة فرع')),
      ]),
      if (branches.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد فروع لهذا النشاط بعد.', style: TextStyle(fontSize: 11, color: Colors.black54))),
      if (branches.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, child: ErpStandardDataTable(
        
        columns: const [
          DataColumn(label: Text('م')), DataColumn(label: Text('كود')),
          DataColumn(label: Text('اسم الفرع عربي')), DataColumn(label: Text('English')),
          DataColumn(label: Text('الحالة')), DataColumn(label: Text('الإجراءات')),
        ],
        rows: [
          for (var i=0;i<branches.length;i++) DataRow(cells: [
            DataCell(Text('${i+1}')),
            DataCell(Text(_s(branches[i]['branch_code']))),
            DataCell(Text(_s(branches[i]['name_ar']))),
            DataCell(Text(_s(branches[i]['name_en']))),
            DataCell(_status(branches[i]['is_active']==true,(v)=>_setActive('erp_business_workspace_branches',branches[i],v))),
            DataCell(_actions(()=>_editBranch(branches[i]),()=>_deleteBranch(branches[i]))),
          ]),
        ],
      )),
      for (final branch in branches) _warehouseGrid(workspace, branch),
    ]);
  }

  Widget _warehouseGrid(Map<String,dynamic> workspace, Map<String,dynamic> branch) {
    final warehouses = _warehousesByBranch[_s(branch['id'])] ?? const <Map<String,dynamic>>[];
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 14, top: 5, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFFAF8FC), border: Border.all(color: const Color(0xFFE7DDF1)), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.warehouse_outlined, size: 16, color: _activityPurple),
          const SizedBox(width: 5),
          Expanded(child: Text('مخازن فرع: ${_s(branch['name_ar'])}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
          TextButton.icon(onPressed: _busy ? null : () => _addWarehouse(workspace, branch), icon: const Icon(Icons.add, size: 16), label: const Text('إضافة مخزن')),
        ]),
        if (warehouses.isEmpty) const Text('لا توجد مخازن مسجلة لهذا الفرع.', style: TextStyle(fontSize: 10, color: Colors.black54)),
        if (warehouses.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, child: ErpStandardDataTable(
          
          columns: const [
            DataColumn(label: Text('م')), DataColumn(label: Text('كود')),
            DataColumn(label: Text('اسم المخزن عربي')), DataColumn(label: Text('English')),
            DataColumn(label: Text('الحالة')), DataColumn(label: Text('الإجراءات')),
          ],
          rows: [
            for (var i=0;i<warehouses.length;i++) DataRow(cells: [
              DataCell(Text('${i+1}')),
              DataCell(Text(_s(warehouses[i]['warehouse_code']))),
              DataCell(Text(_s(warehouses[i]['name_ar']))),
              DataCell(Text(_s(warehouses[i]['name_en']))),
              DataCell(_status(warehouses[i]['is_active']==true,(v)=>_setActive('erp_business_workspace_warehouses',warehouses[i],v))),
              DataCell(_actions(()=>_editWarehouse(warehouses[i]),()=>_deleteWarehouse(warehouses[i]))),
            ]),
          ],
        )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      body: Column(children: [
        Container(
          height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFECE7F2)))),
          child: Row(children: [
            const Icon(Icons.hub_outlined, color: _activityPurple),
            const SizedBox(width: 8),
            const Expanded(child: Text('فروع النشاطات', style: TextStyle(color: _activityPurple, fontSize: 16, fontWeight: FontWeight.w900))),
            IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, color: _activityPurple)),
          ]),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11))),
        if (_message != null) Padding(padding: const EdgeInsets.all(6), child: Text(_message!, style: const TextStyle(color: Colors.green, fontSize: 11))),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) :
          _workspaces.isEmpty ? const Center(child: Text('لا توجد نشاطات مرتبطة بالشركة حاليًا. أنشئ النشاط أولًا من شاشة إدارة نشاطي.')) :
          ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _workspaces.length,
            itemBuilder: (context,index) {
              final workspace = _workspaces[index];
              final active = workspace['is_active'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                elevation: 0,
                shape: RoundedRectangleBorder(side: BorderSide(color: _activityPurple.withValues(alpha:.16)), borderRadius: BorderRadius.circular(9)),
                child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.business_outlined, color: _activityPurple, size: 19),
                    const SizedBox(width: 7),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_activityName(workspace), style: const TextStyle(fontWeight: FontWeight.w900, color: _activityPurple, fontSize: 13)),
                      Text(_s(workspace['workspace_name']), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: active ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12)), child: Text(active ? 'نشاط نشط' : 'نشاط غير نشط', style: TextStyle(fontSize: 9, color: active ? Colors.green.shade800 : Colors.red.shade800))),
                  ]),
                  const Divider(height: 14),
                  _branchesGrid(workspace),
                ])),
              );
            },
          ),
        ),
      ]),
    );
  }
}
