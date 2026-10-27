import 'package:flutter/material.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

const _classPurple = Color(0xFF3E007D);
const _classOrange = Color(0xFFFFA015);
const _classCanvas = Color(0xFFF7F5FA);

class ErpUserClassificationsScreen extends StatefulWidget {
  const ErpUserClassificationsScreen({super.key, required this.companyId});
  final String? companyId;

  @override
  State<ErpUserClassificationsScreen> createState() => _ErpUserClassificationsScreenState();
}

class _ErpUserClassificationsScreenState extends State<ErpUserClassificationsScreen> {
  SupabaseClient? _db;
  String? _company;
  bool _loading = false, _saving = false, _editing = false;
  String? _error, _message, _selectedId;
  int _activeTab = 0;
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _rows = [];
  final Map<String, TextEditingController> _arControllers = {};
  final Map<String, TextEditingController> _enControllers = {};

  @override
  void initState() {
    super.initState();
    _company = widget.companyId;
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  @override
  void dispose() {
    for (final c in _arControllers.values) { c.dispose(); }
    for (final c in _enControllers.values) { c.dispose(); }
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  String get _typeId => _types.isEmpty ? '' : _s(_types[_activeTab.clamp(0, _types.length - 1)]['id']);
  bool get _activeTypeEnabled => _types.isNotEmpty && _types[_activeTab.clamp(0, _types.length - 1)]['is_active'] == true;

  Future<void> _load() async {
    if (_db == null) {
      if (mounted) setState(() { _loading = false; _error = 'الاتصال بقاعدة البيانات غير متاح.'; });
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      var company = (_company ?? '').trim();
      final uid = _db!.auth.currentUser?.id;
      if (uid != null) {
        try {
          final membership = await _db!.from('erp_company_members').select('company_id')
            .eq('user_id', uid).eq('is_active', true).order('created_at').limit(1);
          if ((membership as List).isNotEmpty) company = _s(membership.first['company_id']);
        } catch (_) {}
      }
      if (company.isEmpty) throw StateError('لم يتم العثور على شركة نشطة.');
      _company = company;
      final typeResult = await _db!.from('erp_user_types').select('id,type_code,name_ar,name_en,is_active')
        .eq('company_id', company).order('type_code');
      _types = (typeResult as List).map((e) => Map<String,dynamic>.from(e)).toList();
      if (_types.isEmpty) {
        _rows = [];
      } else {
        if (_activeTab >= _types.length) _activeTab = 0;
        final result = await _db!.from('erp_user_classifications').select()
          .eq('company_id', company).eq('user_type_id', _typeId).order('classification_code');
        _rows = (result as List).map((e) => Map<String,dynamic>.from(e)).toList();
        _syncControllers();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل تصنيفات المستخدمين: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncControllers() {
    final keep = <String>{};
    for (final row in _rows) {
      final id = _s(row['id']);
      keep.add(id);
      _arControllers.putIfAbsent(id, () => TextEditingController(text: _s(row['name_ar'])));
      _enControllers.putIfAbsent(id, () => TextEditingController(text: _s(row['name_en'])));
      _arControllers[id]!.text = _s(row['name_ar']);
      _enControllers[id]!.text = _s(row['name_en']);
    }
    for (final id in _arControllers.keys.where((id) => !keep.contains(id)).toList()) {
      _arControllers.remove(id)?.dispose();
      _enControllers.remove(id)?.dispose();
    }
  }

  Future<void> _switchTab(int index) async {
    setState(() { _activeTab = index; _selectedId = null; _editing = false; _error = null; });
    await _load();
  }

  Future<void> _add() async {
    if (_typeId.isEmpty || _company == null || !_activeTypeEnabled) {
      setState(() => _error = 'النوع المحدد غير نشط أو غير متاح؛ فعّله من شاشة أنواع المستخدمين قبل إضافة التصنيفات.');
      return;
    }
    final draft = <String,dynamic>{
      'id': 'draft-${DateTime.now().microsecondsSinceEpoch}',
      'company_id': _company, 'user_type_id': _typeId,
      'classification_code': null, 'name_ar': '', 'name_en': '',
      'is_active': true, 'show_in_app': true, '_draft': true,
    };
    setState(() { _editing = true; _rows = [..._rows, draft]; _selectedId = _s(draft['id']); _syncControllers(); });
  }

  Future<void> _save() async {
    if (!_editing) { setState(() => _error = 'اضغط «تعديل» أو «إضافة» أولًا قبل تغيير التصنيفات.'); return; }
    if (_db == null || _company == null || _typeId.isEmpty || !_activeTypeEnabled) { if (mounted) setState(() => _error = 'لا يمكن تعديل تصنيفات نوع غير نشط. فعّل النوع أولًا.'); return; }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      for (final row in _rows) {
        final id = _s(row['id']);
        final ar = (_arControllers[id]?.text ?? _s(row['name_ar'])).trim();
        final en = (_enControllers[id]?.text ?? _s(row['name_en'])).trim();
        if (ar.isEmpty) {
          if (row['_draft'] == true) continue;
          throw StateError('اسم التصنيف العربي مطلوب (الكود ${row['classification_code'] ?? ''}).');
        }
        final payload = <String,dynamic>{
          'company_id': _company, 'user_type_id': _typeId,
          'name_ar': ar, 'name_en': en,
          'is_active': row['is_active'] == true,
          'show_in_app': row['show_in_app'] == true,
        };
        if (row['_draft'] == true) {
          final inserted = await _db!.from('erp_user_classifications').insert(payload).select().single();
          row
            ..['id'] = inserted['id']
            ..['classification_code'] = inserted['classification_code']
            ..remove('_draft');
        } else {
          await _db!.from('erp_user_classifications').update(payload).eq('id', id).eq('company_id', _company!);
        }
        row['name_ar'] = ar;
        row['name_en'] = en;
      }
      if (mounted) setState(() => _editing = false);
      await _load();
      if (mounted) setState(() => _message = 'تم حفظ التصنيفات في قاعدة البيانات.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر حفظ التصنيفات: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_activeTypeEnabled) { setState(() => _error = 'لا يمكن حذف أو تعديل تصنيفات نوع غير نشط. فعّل النوع أولًا.'); return; }
    if (!_editing) { setState(() => _error = 'اضغط «تعديل» أولًا قبل حذف التصنيفات.'); return; }
    final id = _selectedId;
    if (id == null) { setState(() => _error = 'حدد تصنيفًا من الجريد أولًا.'); return; }
    Map<String, dynamic>? row;
    for (final candidate in _rows) {
      if (_s(candidate['id']) == id) { row = candidate; break; }
    }
    if (row == null) return;
    final selectedRow = row;
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('تأكيد الحذف'), content: Text('هل تريد حذف التصنيف «${_s(selectedRow['name_ar'])}»؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No / لا')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes / نعم، احذف'))],
    ));
    if (yes != true) return;
    try {
      if (selectedRow['_draft'] != true) await _db!.from('erp_user_classifications').delete().eq('id', id).eq('company_id', _company!);
      setState(() { _rows.removeWhere((r) => _s(r['id']) == id); _selectedId = null; _syncControllers(); });
      setState(() => _message = 'تم حذف التصنيف.');
    } catch (e) { setState(() => _error = 'تعذر الحذف: $e'); }
  }

  void _select(Map<String,dynamic> row) => setState(() => _selectedId = _s(row['id']));

  Widget _task(String label, IconData icon, VoidCallback? action) =>
    SizedBox(width: 112, child: ErpQuickTaskButton(label: label, icon: icon, onPressed: action, compact: true));

  Widget _grid() {
    if (_types.isEmpty) return const Padding(padding: EdgeInsets.all(22), child: Text('لا توجد أنواع مستخدمين.'));
    final canEdit = _editing && _activeTypeEnabled;
    return DataTable(
      headingRowColor: WidgetStateProperty.all(const Color(0xFFEDE4F8)),
      dataRowMinHeight: 57, dataRowMaxHeight: 57, headingRowHeight: 57,
      columnSpacing: 14, horizontalMargin: 10,
      columns: const [
        DataColumn(label: Text('م')),
        DataColumn(label: Text('كود التصنيف')),
        DataColumn(label: Text('اسم التصنيف عربي')),
        DataColumn(label: Text('اسمه إنجليزي')),
        DataColumn(label: Text('نشط')),
        DataColumn(label: Text('ظهور في التطبيق')),
      ],
      rows: List<DataRow>.generate(_rows.length, (i) {
        final row = _rows[i]; final id = _s(row['id']); final selected = id == _selectedId;
        return DataRow(
          selected: selected,
          onSelectChanged: (_) => _select(row),
          cells: [
            DataCell(Text('${i+1}')),
            DataCell(Text(_s(row['classification_code']).isEmpty ? 'تلقائي عند الحفظ' : _s(row['classification_code']))),
            DataCell(SizedBox(width: 210, child: TextField(controller: _arControllers[id], enabled: canEdit,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'اسم التصنيف بالعربية'),
              onTap: () => _select(row)))),
            DataCell(SizedBox(width: 190, child: TextField(controller: _enControllers[id], enabled: canEdit,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Classification name'),
              onTap: () => _select(row)))),
            DataCell(Checkbox(value: row['is_active'] == true, activeColor: _classPurple,
              onChanged: canEdit ? (v) => setState(() { row['is_active'] = v == true; _selectedId = id; }) : null)),
            DataCell(Checkbox(value: row['show_in_app'] == true, activeColor: _classOrange,
              onChanged: canEdit ? (v) => setState(() { row['show_in_app'] = v == true; _selectedId = id; }) : null)),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) => ErpKeyboardActionRegistrar(add: _add, save: _save, child: Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: const Row(children: [Icon(Icons.category_outlined, color: _classPurple, size: 25), SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('تصنيفات المستخدمين', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _classPurple)),
            Text('تصنيفات مستقلة لكل نوع مستخدم مع التحكم في ظهورها بالتطبيق', style: TextStyle(fontSize: 11, color: Colors.black54)),
          ]))])),
      Container(color: _classCanvas, padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _task('تحديث', Icons.refresh, _loading ? null : _load),
          _task('إضافة', Icons.add, _saving || !_activeTypeEnabled ? null : _add),
          _task('حفظ', Icons.save, _saving || !_editing || !_activeTypeEnabled ? null : _save),
          _task('تعديل', Icons.edit, _saving || _editing || !_activeTypeEnabled ? null : () => setState(() => _editing = true)),
          _task('حذف', Icons.delete, _saving || !_activeTypeEnabled ? null : _delete),
          _task('معاينة', Icons.preview, () => showDialog<void>(context: context, builder: (c) => AlertDialog(
            title: const Text('معاينة التصنيفات'), content: Text('عدد السجلات: ${_rows.length}'),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق'))]))),
          _task('طباعة', Icons.print, null),
          _task('استيراد Excel', Icons.upload_file, null),
          _task('طباعة PDF', Icons.picture_as_pdf, null),
        ]))),
      if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      if (_message != null) Padding(padding: const EdgeInsets.all(8), child: Text(_message!, style: const TextStyle(color: Colors.green))),
      if (_types.isNotEmpty) SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [
        for (var i=0; i<_types.length; i++) Padding(padding: const EdgeInsetsDirectional.only(start: 6, top: 4, bottom: 3),
          child: ChoiceChip(label: Text('${_s(_types[i]['name_ar'])}${_types[i]['is_active'] == true ? '' : ' (غير نشط)'}'), selected: _activeTab == i,
            selectedColor: _classPurple, labelStyle: TextStyle(fontSize: 12, color: _activeTab == i ? Colors.white : _classPurple),
            onSelected: (_) => _switchTab(i))),
      ])),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : Column(children:[
        if (!_activeTypeEnabled) const Padding(padding: EdgeInsets.all(8), child: Text('النوع غير نشط: التصنيفات للعرض فقط، ولا يمكن تعديلها أو إضافة تصنيفات حتى إعادة تنشيطه.', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w700))),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(8), child: _grid())))),
      ])),
    ]),
  ));
}
