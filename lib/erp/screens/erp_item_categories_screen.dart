import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

const _catPurple = Color(0xFF3E007D);
const _catOrange = Color(0xFFFFA015);
const _catCanvas = Color(0xFFF7F5FA);

class ErpItemCategoriesScreen extends StatefulWidget {
  const ErpItemCategoriesScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<ErpItemCategoriesScreen> createState() => _ErpItemCategoriesScreenState();
}

class _ErpItemCategoriesScreenState extends State<ErpItemCategoriesScreen> {
  SupabaseClient? _db;
  final _picker = ImagePicker();
  String? _company, _error, _message, _selectedId;
  bool _loading = false, _saving = false, _editing = false;
  int _level = 0;
  String? _parentFilter;
  List<Map<String,dynamic>> _all = [];
  final Map<String,TextEditingController> _ar = {};
  final Map<String,TextEditingController> _en = {};
  final Map<String,Uint8List?> _imageBytes = {};
  final Map<String,String> _imageNames = {};
  final Set<String> _expandedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _company = widget.companyId;
    try { _db = Supabase.instance.client; } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _ar.values) { c.dispose(); }
    for (final c in _en.values) { c.dispose(); }
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  List<Map<String,dynamic>> get _parents => _all.where((r) => r['parent_id'] == null && r['is_active'] == true).toList();
  List<Map<String,dynamic>> get _secondaryParents => _all.where((r) => r['parent_id'] != null && _parentOf(r) != null && _parentOf(r)!['parent_id'] == null && r['is_active'] == true).toList();
  Map<String,dynamic>? _parentOf(Map<String,dynamic> row) {
    for (final r in _all) { if (_s(r['id']) == _s(row['parent_id'])) return r; }
    return null;
  }
  String _parentLabel(Map<String,dynamic> row) => '${_s(row['group_code'])} - ${_s(row['group_name'])}';

  Future<void> _load() async {
    if (_db == null) { setState(() => _error = 'Supabase غير مهيأ.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      var company = (_company ?? '').trim();
      final uid = _db!.auth.currentUser?.id;
      if (company.isEmpty && uid != null) {
        final m = await _db!.from('erp_company_members').select('company_id')
          .eq('user_id', uid).eq('is_active', true).order('created_at').limit(1);
        if ((m as List).isNotEmpty) company = _s(m.first['company_id']);
      }
      if (company.isEmpty) throw StateError('لم يتم تحديد الشركة الحالية.');
      _company = company;
      final result = await _db!.from('erp_item_groups')
        .select('id,company_id,group_code,group_name,group_name_en,parent_id,is_active,show_in_app,image_url,image_data,image_mime_type')
        .eq('company_id', company).order('group_code').limit(3000);
      _all = (result as List).map((e) => Map<String,dynamic>.from(e)).toList();
      _expandedIds.addAll(_all.map((r) => _s(r['id'])));
      _syncControllers();
      if (_parentFilter != null && !_all.any((r) => _s(r['id']) == _parentFilter)) _parentFilter = null;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل فئات الأصناف: $e');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _migrateImages() async {
    if (_db == null) {
      setState(() => _error = 'اتصال قاعدة البيانات غير متاح.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final response = await _db!.functions.invoke('migrate-catalog-images', body: <String, dynamic>{});
      if (response.status < 200 || response.status >= 300) {
        throw StateError('فشل نقل الصور (HTTP ${response.status}).');
      }
      final data = response.data;
      final migrated = data is Map ? (data['total_migrated'] ?? 0) : 0;
      await _load();
      if (mounted) setState(() => _message = 'تم حفظ ${migrated} صورة كبيانات فعلية داخل قاعدة البيانات. أعد فتح الشاشات التي تعرض الصور.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر نقل الصور إلى قاعدة البيانات: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _syncControllers() {
    final keep = <String>{};
    for (final row in _all) {
      final id = _s(row['id']); keep.add(id);
      _ar.putIfAbsent(id, () => TextEditingController());
      _en.putIfAbsent(id, () => TextEditingController());
      _ar[id]!.text = _s(row['group_name']);
      _en[id]!.text = _s(row['group_name_en']);
    }
    for (final id in _ar.keys.where((id) => !keep.contains(id)).toList()) {
      _ar.remove(id)?.dispose(); _en.remove(id)?.dispose();
      _imageBytes.remove(id); _imageNames.remove(id);
    }
  }

  int _rowLevel(Map<String,dynamic> row) {
    if (row['parent_id'] == null) return 0;
    final p = _parentOf(row);
    if (p == null || p['parent_id'] == null) return 1;
    return 2;
  }

  List<Map<String,dynamic>> get _visibleRows {
    final rows = _all.where((r) {
      if (_rowLevel(r) != _level) return false;
      if (_level == 0 || _parentFilter == null) return true;
      if (_level == 1) return _s(r['parent_id']) == _parentFilter;
      final parent = _parentOf(r);
      return parent != null && _s(parent['parent_id']) == _parentFilter;
    }).toList();
    rows.sort((a,b) => _s(a['group_code']).compareTo(_s(b['group_code'])));
    return rows;
  }

  Future<void> _setLevel(int level) async {
    setState(() { _level = level; _parentFilter = null; _selectedId = null; });
    await _load();
  }

  Future<void> _add({String? parentIdOverride}) async {
    if (_company == null || _company!.isEmpty) { setState(() => _error = 'حدد الشركة أولًا.'); return; }
    String? parentId = parentIdOverride;
    if (parentId == null && _level == 1 && _parents.isNotEmpty) parentId = _parentFilter ?? _s(_parents.first['id']);
    if (parentId == null && _level == 2 && _secondaryParents.isNotEmpty) {
      final candidates = _secondaryParents.where((r) => _parentFilter == null || _s(_parentOf(r)?['id']) == _parentFilter).toList();
      if (candidates.isNotEmpty) parentId = _s(candidates.first['id']);
    }
    if (_level > 0 && parentId == null) {
      setState(() => _error = _level == 1 ? 'أضف فئة رئيسية أولًا.' : 'أضف فئة فرعية أولًا.');
      return;
    }
    final prefix = ['C','S','T'][_level];
    final codeNumbers = _all.map((r) => int.tryParse(_s(r['group_code']).replaceFirst(RegExp(r'^[A-Za-z_-]+'),'')) ?? 0).toList();
    final next = (codeNumbers.isEmpty ? 0 : codeNumbers.reduce((a,b) => a>b?a:b)) + 1;
    final draft = <String,dynamic>{
      'id':'draft-${DateTime.now().microsecondsSinceEpoch}', 'company_id':_company,
      'group_code':'CAT${next.toString().padLeft(4,'0')}', 'group_name':'','group_name_en':'',
      'parent_id':parentId,'is_active':true,'show_in_app':true,'image_url':null,'image_data':null,'image_mime_type':null,'_draft':true,
    };
    setState(() { _editing = true; _all.add(draft); _selectedId = _s(draft['id']); _expandedIds.add(_s(parentId)); _expandedIds.add(_s(draft['id'])); _syncControllers(); });
  }

  Future<void> _pickImage(Map<String,dynamic> row) async {
    final id = _s(row['id']);
    try {
      final source = await showModalBottomSheet<ImageSource>(context: context, builder: (c) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('اختيار صورة من الجهاز'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('تصوير صورة للفئة'), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ])));
      if (source == null) return;
      final file = await _picker.pickImage(source: source, imageQuality: 82, maxWidth: 1400);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() { _imageBytes[id] = bytes; _imageNames[id] = file.name; _selectedId = id; });
    } catch (e) { setState(() => _error = 'تعذر اختيار صورة الفئة: $e'); }
  }

  String _byteaHex(Uint8List bytes) =>
      '\\x' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Uint8List? _decodeBytea(dynamic value) {
    final raw = _s(value);
    final prefixLength = raw.startsWith(r'\\x') ? 3 : raw.startsWith(r'\x') ? 2 : 0;
    if (prefixLength == 0 || raw.length <= prefixLength || (raw.length - prefixLength).isOdd) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        (raw.length - prefixLength) ~/ 2,
        (i) => int.parse(raw.substring(prefixLength + i * 2, prefixLength + 2 + i * 2), radix: 16),
      ));
    } catch (_) { return null; }
  }

  String? _imageMime(Map<String,dynamic> row) {
    final name = (_imageNames[_s(row['id'])] ?? '').toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    final existing = _s(row['image_mime_type']);
    return existing.isEmpty ? null : existing;
  }

  Future<void> _save() async {
    if (!_editing) { setState(() => _message = 'اضغط «تعديل» أولًا قبل حفظ أي تغييرات.'); return; }
    if (_db == null || _company == null) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      for (final row in _all.toList()) {
        final id = _s(row['id']);
        final ar = (_ar[id]?.text ?? _s(row['group_name'])).trim();
        final en = (_en[id]?.text ?? _s(row['group_name_en'])).trim();
        if (ar.isEmpty) { if (row['_draft'] == true) continue; throw StateError('اسم الفئة العربية مطلوب للكود ${row['group_code']}.'); }
        final normalizedName = ar.toLowerCase().replaceAll(RegExp(r'\\s+'), ' ').trim();
        final duplicate = _all.any((other) => _s(other['id']) != id &&
          (_ar[_s(other['id'])]?.text ?? _s(other['group_name'])).toLowerCase().replaceAll(RegExp(r'\\s+'), ' ').trim() == normalizedName);
        if (duplicate) throw StateError('اسم الفئة «$ar» مستخدم بالفعل في مستوى فئة آخر أو داخل المستوى نفسه.');
        if (_level == 1 && (_s(row['parent_id']).isEmpty || !_parents.any((p) => _s(p['id']) == _s(row['parent_id'])))) {
          throw StateError('اختر الفئة الرئيسية للفئة الفرعية ${row['group_code']}.');
        }
        if (_level == 2) {
          final selectedParent = _parentOf(row);
          if (selectedParent == null || selectedParent['parent_id'] == null) {
            throw StateError('اختر الفئة الفرعية للفئة الثانوية ${row['group_code']}.');
          }
          final mainId = _s(row['_main_parent_id']);
          if (mainId.isNotEmpty && _s(selectedParent['parent_id']) != mainId) {
            throw StateError('الفئة الفرعية المختارة لا تتبع الفئة الرئيسية المحددة.');
          }
        }
        final selectedBytes = _imageBytes[id];
        final payload = <String,dynamic>{
          'company_id':_company, 'group_code':_s(row['group_code']), 'group_name':ar,
          'group_name_en':en, 'parent_id':row['parent_id'], 'is_active':row['is_active'] == true,
          'show_in_app':row['show_in_app'] == true, 'image_url':selectedBytes != null ? null : row['image_url'],
          if (selectedBytes != null && selectedBytes.isNotEmpty) ...{
            'image_data':_byteaHex(selectedBytes), 'image_mime_type':_imageMime(row),
          },
        };
        if (row['_draft'] == true) {
          final inserted = await _db!.from('erp_item_groups').insert(payload).select().single();
          row..['id']=inserted['id']..remove('_draft');
        } else {
          await _db!.from('erp_item_groups').update(payload).eq('id',id).eq('company_id',_company!);
        }
      }
      await _load();
      if (mounted) setState(() { _editing = false; _message = 'تم حفظ فئات الأصناف في قاعدة البيانات.'; });
    } catch (e) { if (mounted) setState(() => _error = 'تعذر حفظ الفئات: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _delete() async {
    if (!_editing) { setState(() => _error = 'اضغط «تعديل» أولًا قبل حذف الفئات.'); return; }
    final id = _selectedId;
    if (id == null) { setState(() => _error = 'حدد فئة من الجريد أولًا.'); return; }
    Map<String, dynamic>? row;
    for (final candidate in _all) { if (_s(candidate['id']) == id) { row = candidate; break; } }
    if (row == null) return;
    final selectedRow = row;
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('تأكيد الحذف'), content: Text('حذف الفئة «${_s(selectedRow['group_name'])}»؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('نعم'))]));
    if (yes != true) return;
    try {
      if (selectedRow['_draft'] != true) await _db!.from('erp_item_groups').delete().eq('id',id).eq('company_id',_company!);
      setState(() { _all.removeWhere((r)=>_s(r['id'])==id); _selectedId=null; _syncControllers(); _message='تم حذف الفئة.'; });
    } catch(e) { setState(()=>_error='تعذر حذف الفئة: $e'); }
  }

  Widget _task(String label, IconData icon, VoidCallback? action) =>
    SizedBox(width:112, child: ErpQuickTaskButton(label:label,icon:icon,onPressed:action,compact:true));

  List<Map<String,dynamic>> _childrenOf(Map<String,dynamic> parent) =>
      _all.where((r) => _s(r['parent_id']) == _s(parent['id'])).toList()
        ..sort((a,b) => _s(a['group_code']).compareTo(_s(b['group_code'])));

  Widget _treeNode(Map<String,dynamic> row, int depth) {
    final id = _s(row['id']);
    final children = _childrenOf(row);
    final expanded = _expandedIds.contains(id);
    final isDraft = row['_draft'] == true;
    final ar = _ar.putIfAbsent(id, () => TextEditingController(text: _s(row['group_name'])));
    final en = _en.putIfAbsent(id, () => TextEditingController(text: _s(row['group_name_en'])));
    final level = _rowLevel(row);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(margin: EdgeInsetsDirectional.only(start: depth * 24, bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(color: _selectedId == id ? const Color(0xFFF0E7FA) : Colors.white,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: _selectedId == id ? _catPurple : const Color(0xFFE8E1EF))),
        child: Row(children: [
          IconButton(visualDensity: VisualDensity.compact, onPressed: children.isEmpty ? null : () => setState(() {
            if (expanded) { _expandedIds.remove(id); } else { _expandedIds.add(id); }
          }), icon: Icon(children.isEmpty ? Icons.circle_outlined : expanded ? Icons.keyboard_arrow_down : Icons.chevron_left, color: _catPurple)),
          SizedBox(width: 84, child: Text(_s(row['group_code']), style: const TextStyle(fontWeight: FontWeight.w800, color: _catPurple))),
          Expanded(flex: 3, child: TextField(controller: ar, enabled: _editing,
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'اسم الفئة عربي'),
            onTap: () => setState(() => _selectedId = id))),
          Expanded(flex: 2, child: TextField(controller: en, enabled: _editing,
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'اسم الفئة إنجليزي'),
            onTap: () => setState(() => _selectedId = id))),
          Tooltip(message: 'نشط', child: Checkbox(shape: const CircleBorder(), value: row['is_active'] == true, activeColor: _catPurple,
            onChanged: _editing ? (v) => setState(() => row['is_active'] = v == true) : null)),
          Tooltip(message: 'ظهور في التطبيق', child: Checkbox(shape: const CircleBorder(), value: row['show_in_app'] == true, activeColor: _catOrange,
            onChanged: _editing ? (v) => setState(() => row['show_in_app'] = v == true) : null)),
          IconButton(tooltip: 'اختيار أو تصوير صورة', onPressed: _editing ? () => _pickImage(row) : null,
            icon: Icon(_imageBytes[id] != null || _decodeBytea(row['image_data']) != null ? Icons.image : Icons.add_a_photo_outlined, color: _catPurple)),
          if (level < 2) IconButton(tooltip: level == 0 ? 'إضافة فئة فرعية' : 'إضافة فئة ثانوية',
            onPressed: _saving ? null : () { setState(() { _level = level + 1; _editing = true; }); _add(parentIdOverride: id); },
            icon: const Icon(Icons.add_circle_outline, color: _catPurple)),
          IconButton(tooltip: 'تحديد الفئة', onPressed: () => setState(() => _selectedId = id),
            icon: Icon(Icons.radio_button_checked, color: _selectedId == id ? _catPurple : Colors.black26)),
        ])),
      if (expanded) ...children.map((child) => _treeNode(child, depth + 1)),
    ]);
  }

  Widget _parentTabs() {
    if (_level == 0) return const SizedBox.shrink();
    final parents = _parents;
    return SizedBox(height:40, child: ListView(scrollDirection:Axis.horizontal, children:[
      Padding(padding:const EdgeInsetsDirectional.only(start:6,top:3,bottom:3),
        child:ChoiceChip(label:const Text('الكل'),selected:_parentFilter==null,selectedColor:_catPurple,
          labelStyle:TextStyle(color:_parentFilter==null?Colors.white:_catPurple,fontSize:12),
          onSelected:(_)=>setState(()=>_parentFilter=null))),
      for(final parent in parents) Padding(padding:const EdgeInsetsDirectional.only(start:6,top:3,bottom:3),
        child:ChoiceChip(label:Text(_s(parent['group_name']),maxLines:1),selected:_parentFilter==_s(parent['id']),
          selectedColor:_catPurple,labelStyle:TextStyle(color:_parentFilter==_s(parent['id'])?Colors.white:_catPurple,fontSize:12),
          onSelected:(_)=>setState(()=>_parentFilter=_s(parent['id'])))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(add: _add, save: _save);
    return Directionality(textDirection:TextDirection.rtl,child:Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
        child:const Row(children:[Icon(Icons.account_tree_outlined,color:_catPurple,size:25),SizedBox(width:9),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('فئات الأصناف',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:_catPurple)),
            Text('إدارة مستقلة للفئات الرئيسية والفرعية والثانوية وصورها',style:TextStyle(fontSize:11,color:Colors.black54)),
          ]))])),
      Container(color:_catCanvas,padding:const EdgeInsets.symmetric(horizontal:3,vertical:3),
        child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
          _task('تحديث',Icons.refresh,_loading?null:_load),
          _task('نقل الصور للقاعدة',Icons.cloud_download_outlined,_saving || _loading ? null : _migrateImages),
          _task('إضافة جديد',Icons.add,_saving ? null : _add),
          _task('حفظ',Icons.save,_saving || !_editing ? null:_save),
          _task('تعديل',Icons.edit,_saving || _editing ? null:()=>setState(()=>_editing=true)),
          _task('حذف',Icons.delete,_saving?null:_delete),
          _task('معاينة',Icons.preview,()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(
            title:const Text('معاينة الفئات'),content:Text('عدد الفئات المعروضة: ${_visibleRows.length}'),
            actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إغلاق'))]))),
          _task('استيراد',Icons.upload_file,null),
          _task('طباعة',Icons.print,null),
          _task('PDF',Icons.picture_as_pdf,null),
        ]))),
      if(_error!=null) Padding(padding:const EdgeInsets.all(7),child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:12))),
      if(_message!=null) Padding(padding:const EdgeInsets.all(7),child:Text(_message!,style:const TextStyle(color:Colors.green,fontSize:12))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Row(children: const [
        SizedBox(width: 84, child: Text('كود الفئة', style: TextStyle(fontWeight: FontWeight.w800))),
        Expanded(flex: 3, child: Text('اسم الفئة عربي', style: TextStyle(fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('اسم الفئة إنجليزي', style: TextStyle(fontWeight: FontWeight.w800))),
        Text('نشط'), SizedBox(width: 8), Text('في التطبيق'), SizedBox(width: 8), Text('الصورة'), SizedBox(width: 24),
      ])),
      Expanded(child: _loading ? const Center(child:CircularProgressIndicator()) :
        _all.where((r) => r['parent_id'] == null).isEmpty
          ? const Center(child: Text('لا توجد فئات رئيسية. اضغط «إضافة جديد» لبدء إنشاء شجرة الفئات.'))
          : ListView(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: _all.where((r) => r['parent_id'] == null)
                .toList()..sort((a,b) => _s(a['group_code']).compareTo(_s(b['group_code'])))
                .map((root) => _treeNode(root, 0)).toList())),
    ],
  ));
  }
}
