import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/erp_keyboard_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';
import '../services/erp_workspace_records_service.dart';

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
  final _workspaceRecords = ErpWorkspaceRecordsService();
  List<Map<String,String>> _activities = <Map<String,String>>[];
  String _selectedActivityCode = 'ACT001';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _viewMode = 'tree';

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
    _searchController.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();
  List<Map<String,dynamic>> get _parents => _all.where((r) => r['parent_id'] == null && r['is_active'] == true).toList();
  List<Map<String,dynamic>> get _secondaryParents => _all.where((r) => r['parent_id'] != null && _parentOf(r) != null && _parentOf(r)!['parent_id'] == null && r['is_active'] == true).toList();
  Map<String,dynamic>? _parentOf(Map<String,dynamic> row) {
    for (final r in _all) { if (_s(r['id']) == _s(row['parent_id'])) return r; }
    return null;
  }
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
      final activityRows = await _workspaceRecords.listPage(companyId: company, pageKey: 'أنواع الأنشطة');
      _activities = activityRows.where((r) => (r['نشط'] ?? 'true').toLowerCase() != 'false')
        .map((r) => <String,String>{'code': r['كود النشاط'] ?? '', 'name': r['اسم النشاط عربي'] ?? ''})
        .where((r) => r['code']!.isNotEmpty && r['name']!.isNotEmpty).toList();
      if (_activities.isEmpty) _activities = <Map<String,String>>[
        {'code':'ACT001','name':'مواد غذائية'}, {'code':'ACT002','name':'لوازم بناء'},
        {'code':'ACT003','name':'ملابس واكسسوارات'}, {'code':'ACT004','name':'أجهزة وإلكترونيات'},
        {'code':'ACT005','name':'سيارات ومعدات'}, {'code':'ACT006','name':'خدمات شحن ونقل'},
        {'code':'ACT007','name':'أثاث وديكورات'},
      ];
      if (!_activities.any((a) => a['code'] == _selectedActivityCode)) _selectedActivityCode = _activities.first['code']!;
      final result = await _db!.from('erp_item_categories')
        .select('id,company_id,activity_code,category_code,category_name,category_name_en,parent_id,is_active,show_in_app,image_url,image_data,image_mime_type')
        .eq('company_id', company).eq('activity_code', _selectedActivityCode).order('category_code').limit(3000);
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
      _ar[id]!.text = _s(row['category_name']);
      _en[id]!.text = _s(row['category_name_en']);
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
    rows.sort((a,b) => _s(a['category_code']).compareTo(_s(b['category_code'])));
    return rows;
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
    final codeNumbers = _all.map((r) => int.tryParse(_s(r['category_code']).replaceFirst(RegExp(r'^[A-Za-z_-]+'),'')) ?? 0).toList();
    final next = (codeNumbers.isEmpty ? 0 : codeNumbers.reduce((a,b) => a>b?a:b)) + 1;
    final draft = <String,dynamic>{
      'id':'draft-${DateTime.now().microsecondsSinceEpoch}', 'company_id':_company, 'activity_code':_selectedActivityCode,
      'category_code':'CAT${next.toString().padLeft(4,'0')}', 'category_name':'','category_name_en':'',
      'parent_id':parentId,'is_active':true,'show_in_app':true,'image_url':null,'image_data':null,'image_mime_type':null,'_draft':true,
    };
    setState(() { _editing = true; _all.add(draft); _selectedId = _s(draft['id']); _expandedIds.add(_s(parentId)); _expandedIds.add(_s(draft['id'])); _syncControllers(); });
  }

  Future<void> _pickImage(Map<String,dynamic> row, {ImageSource? source}) async {
    final id = _s(row['id']);
    try {
      source ??= await showModalBottomSheet<ImageSource>(context: context, builder: (c) => SafeArea(child: Column(
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

  Uint8List? _categoryImageBytes(Map<String,dynamic> row) =>
      _imageBytes[_s(row['id'])] ?? _decodeBytea(row['image_data']);

  Widget _imagePreview(Map<String,dynamic> row, {double size = 54}) {
    final bytes = _categoryImageBytes(row);
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFD8CBE7)),
      ),
      child: bytes != null && bytes.isNotEmpty
          ? (_s(row['image_mime_type']) == 'image/svg+xml'
              ? SvgPicture.memory(bytes, fit: BoxFit.contain, width: size, height: size)
              : Image.memory(bytes, fit: BoxFit.cover, width: size, height: size,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.black38)))
          : const Icon(Icons.category_outlined, color: Color(0xFF9A86B5), size: 25),
    );
  }

  void _removeImage(Map<String,dynamic> row) {
    final id = _s(row['id']);
    setState(() {
      _imageBytes.remove(id);
      _imageNames.remove(id);
      row['image_data'] = null;
      row['image_mime_type'] = null;
      row['image_url'] = null;
      row['_remove_image'] = true;
      _selectedId = id;
    });
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
        final ar = (_ar[id]?.text ?? _s(row['category_name'])).trim();
        final en = (_en[id]?.text ?? _s(row['category_name_en'])).trim();
        if (ar.isEmpty) { if (row['_draft'] == true) continue; throw StateError('اسم الفئة العربية مطلوب للكود ${row['category_code']}.'); }
        final normalizedName = ar.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        final duplicate = _all.any((other) => _s(other['id']) != id &&
          (_ar[_s(other['id'])]?.text ?? _s(other['category_name'])).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim() == normalizedName);
        if (duplicate) throw StateError('اسم الفئة «$ar» مستخدم بالفعل في مستوى فئة آخر أو داخل المستوى نفسه.');
        final rowLevel = _rowLevel(row);
        if (rowLevel == 1 && (_s(row['parent_id']).isEmpty || !_parents.any((p) => _s(p['id']) == _s(row['parent_id'])))) {
          throw StateError('اختر الفئة الرئيسية للفئة الفرعية ${row['category_code']}.');
        }
        if (rowLevel == 2) {
          final selectedParent = _parentOf(row);
          if (selectedParent == null || selectedParent['parent_id'] == null) {
            throw StateError('اختر الفئة الفرعية للفئة الثانوية ${row['category_code']}.');
          }
          final mainId = _s(row['_main_parent_id']);
          if (mainId.isNotEmpty && _s(selectedParent['parent_id']) != mainId) {
            throw StateError('الفئة الفرعية المختارة لا تتبع الفئة الرئيسية المحددة.');
          }
        }
        final selectedBytes = _imageBytes[id];
        final payload = <String,dynamic>{
          'company_id':_company, 'activity_code':_selectedActivityCode, 'category_code':_s(row['category_code']), 'category_name':ar,
          'category_name_en':en, 'parent_id':row['parent_id'], 'is_active':row['is_active'] == true,
          'show_in_app':row['show_in_app'] == true,
          'image_url':(selectedBytes != null || row['_remove_image'] == true) ? null : row['image_url'],
          if (row['_remove_image'] == true) ...{'image_data':null, 'image_mime_type':null},
          if (selectedBytes != null && selectedBytes.isNotEmpty) ...{
            'image_data':_byteaHex(selectedBytes), 'image_mime_type':_imageMime(row),
          },
        };
        if (row['_draft'] == true) {
          final oldDraftId = id;
          final inserted = await _db!.from('erp_item_categories').insert(payload).select().single();
          final newId = _s(inserted['id']);
          row..['id']=newId..remove('_draft');
          for (final child in _all.where((candidate) => _s(candidate['parent_id']) == oldDraftId)) { child['parent_id'] = newId; }
        } else {
          await _db!.from('erp_item_categories').update(payload).eq('id',id).eq('company_id',_company!);
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
      title: const Text('تأكيد الحذف'), content: Text('حذف الفئة «${_s(selectedRow['category_name'])}»؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('No / لا')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Yes / نعم، احذف'))]));
    if (yes != true) return;
    try {
      if (selectedRow['_draft'] != true) await _db!.from('erp_item_categories').delete().eq('id',id).eq('company_id',_company!);
      setState(() { _all.removeWhere((r)=>_s(r['id'])==id); _selectedId=null; _syncControllers(); _message='تم حذف الفئة.'; });
    } catch(e) { setState(()=>_error='تعذر حذف الفئة: $e'); }
  }

  Widget _task(String label, IconData icon, VoidCallback? action) =>
    SizedBox(width:112, child: ErpQuickTaskButton(label:label,icon:icon,onPressed:action,compact:true));

  List<Map<String,dynamic>> _childrenOf(Map<String,dynamic> parent) =>
      _all.where((r) => _s(r['parent_id']) == _s(parent['id'])).toList()
        ..sort((a,b) => _s(a['category_code']).compareTo(_s(b['category_code'])));

  bool _matchesSearch(Map<String,dynamic> row) {
    if (_searchQuery.isEmpty) return true;
    return _s(row['category_code']).toLowerCase().contains(_searchQuery) ||
      _s(row['category_name']).toLowerCase().contains(_searchQuery) ||
      _s(row['category_name_en']).toLowerCase().contains(_searchQuery);
  }

  bool _branchMatches(Map<String,dynamic> row) {
    if (_matchesSearch(row)) return true;
    return _childrenOf(row).any(_branchMatches);
  }

  Widget _treeNode(Map<String,dynamic> row, int depth) {
    final id = _s(row['id']);
    final children = _childrenOf(row);
    final expanded = _expandedIds.contains(id);
    final ar = _ar.putIfAbsent(id, () => TextEditingController(text: _s(row['category_name'])));
    final en = _en.putIfAbsent(id, () => TextEditingController(text: _s(row['category_name_en'])));
    final level = _rowLevel(row);
    final active = row['is_active'] == true;
    final visible = row['show_in_app'] == true;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 18, bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
        decoration: BoxDecoration(
          color: _selectedId == id ? const Color(0xFFF0E7FA) : level == 0 ? const Color(0xFFEDE1F8) : level == 1 ? const Color(0xFFFFE4BE) : const Color(0xFFFFDDF3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _selectedId == id ? _catPurple : const Color(0xFFE8E1EF)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(width: 34, child: IconButton(
              padding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
              tooltip: expanded ? 'طي الفئات التابعة' : 'عرض الفئات التابعة',
              onPressed: children.isEmpty ? null : () => setState(() {
                if (expanded) { _expandedIds.remove(id); } else { _expandedIds.add(id); }
              }),
              icon: Icon(children.isEmpty ? Icons.circle_outlined : expanded ? Icons.keyboard_arrow_down : Icons.chevron_left, color: _catPurple),
            )),
            SizedBox(width: 105, child: Text(_s(row['category_code']), overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _catPurple, fontSize: 12))),
            Expanded(child: TextField(controller: ar, enabled: _editing,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'اسم الفئة عربي'),
              onTap: () => setState(() => _selectedId = id))),
            const SizedBox(width: 8),
            _imagePreview(row, size: 48),
          ]),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 34, top: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4, runSpacing: 2,
              children: [
                SizedBox(width: 165, child: TextField(controller: en, enabled: _editing,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'English category name'),
                  onTap: () => setState(() => _selectedId = id))),
                Tooltip(message: 'نشط', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(shape: const CircleBorder(), value: active, activeColor: _catPurple,
                    visualDensity: VisualDensity.compact,
                    onChanged: _editing ? (v) => setState(() => row['is_active'] = v == true) : null),
                  const Text('نشط', style: TextStyle(fontSize: 11)),
                ])),
                Tooltip(message: 'ظهور في التطبيق', child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(shape: const CircleBorder(), value: visible, activeColor: _catOrange,
                    visualDensity: VisualDensity.compact,
                    onChanged: _editing ? (v) => setState(() => row['show_in_app'] = v == true) : null),
                  const Text('في التطبيق', style: TextStyle(fontSize: 11)),
                ])),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'استيراد صورة حقيقية من الجهاز',
                  onPressed: _editing ? () => _pickImage(row, source: ImageSource.gallery) : null,
                  icon: const Icon(Icons.photo_library_outlined, color: _catPurple)),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'التقاط صورة بالكاميرا',
                  onPressed: _editing ? () => _pickImage(row, source: ImageSource.camera) : null,
                  icon: const Icon(Icons.photo_camera_outlined, color: _catOrange)),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'حذف الصورة',
                  onPressed: _editing && _categoryImageBytes(row) != null ? () => _removeImage(row) : null,
                  icon: const Icon(Icons.hide_image_outlined, color: Colors.redAccent)),
                if (level < 2) IconButton(visualDensity: VisualDensity.compact,
                  tooltip: level == 0 ? 'إضافة فئة فرعية' : 'إضافة فئة ثانوية',
                  onPressed: _saving ? null : () { setState(() { _level = level + 1; _editing = true; }); _add(parentIdOverride: id); },
                  icon: const Icon(Icons.add_circle_outline, color: _catPurple)),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'تحديد الفئة',
                  onPressed: () => setState(() => _selectedId = id),
                  icon: Icon(Icons.radio_button_checked, color: _selectedId == id ? _catPurple : Colors.black26)),
              ],
            ),
          ),
          if (children.isNotEmpty)
            Padding(padding: const EdgeInsetsDirectional.only(start: 42, top: 1),
              child: Text('${children.length} فئة تابعة • ${level == 0 ? 'رئيسية' : level == 1 ? 'فرعية' : 'ثانوية'}',
                style: const TextStyle(fontSize: 10, color: Colors.black54))),
          if (expanded) ...children.where(_branchMatches).map((child) => _treeNode(child, depth + 1)),
        ]),
      ),
    );
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
          _task('عرض شجرة',Icons.account_tree_outlined,()=>setState(()=>_viewMode='tree')),
          _task('عرض جدول',Icons.table_rows_outlined,()=>setState(()=>_viewMode='grid')),
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
      Padding(padding: const EdgeInsets.fromLTRB(12, 7, 12, 3), child: TextField(controller: _searchController, onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()), decoration: InputDecoration(labelText: 'ابحث بكود الفئة أو اسمها', prefixIcon: const Icon(Icons.search, color: _catPurple), suffixIcon: _searchQuery.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }, icon: const Icon(Icons.clear)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true))),
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 3), child: Row(children: [
        const SizedBox(width: 72, child: Text('النشاط', style: TextStyle(fontWeight: FontWeight.w800, color: _catPurple))),
        Expanded(child: DropdownButtonFormField<String>(value: _selectedActivityCode, isExpanded: true,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          items: _activities.map((a) => DropdownMenuItem<String>(value: a['code'], child: Text('${a['code']} - ${a['name']}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _editing || _loading ? null : (value) { if (value == null) return; setState(() { _selectedActivityCode = value; _parentFilter = null; _selectedId = null; }); _load(); })),
      ])),
      if(_error!=null) Padding(padding:const EdgeInsets.all(7),child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:12))),
      if(_message!=null) Padding(padding:const EdgeInsets.all(7),child:Text(_message!,style:const TextStyle(color:Colors.green,fontSize:12))),
      if (_viewMode == 'tree') Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Row(children: [
        SizedBox(width: 84, child: Text('كود الفئة', style: TextStyle(fontWeight: FontWeight.w800))),
        Expanded(flex: 3, child: Text('اسم الفئة عربي', style: TextStyle(fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('اسم الفئة إنجليزي', style: TextStyle(fontWeight: FontWeight.w800))),
        Text('نشط'), SizedBox(width: 8), Text('في التطبيق'), SizedBox(width: 8), Text('الصورة'),
        const Spacer(),
        TextButton.icon(onPressed: _loading || _all.isEmpty ? null : () => setState(() => _expandedIds.addAll(_all.map((r) => _s(r['id'])))), icon: const Icon(Icons.unfold_more, size: 18), label: const Text('فتح الكل')),
        TextButton.icon(onPressed: _loading ? null : () => setState(() => _expandedIds.clear()), icon: const Icon(Icons.unfold_less, size: 18), label: const Text('طي الكل')),
      ])),
      Expanded(child: _loading ? const Center(child:CircularProgressIndicator()) :
        _viewMode == 'tree'
          ? ListView(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: (_all.where((r) => r['parent_id'] == null && _branchMatches(r)).toList()
                ..sort((a,b) => _s(a['category_code']).compareTo(_s(b['category_code']))))
                .map((root) => _treeNode(root, 0)).toList())
          : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
              columns: const [
                DataColumn(label: Text('كود الفئة')), DataColumn(label: Text('اسم الفئة عربي')),
                DataColumn(label: Text('اسم الفئة إنجليزي')), DataColumn(label: Text('الصورة')),
                DataColumn(label: Text('المستوى')), DataColumn(label: Text('نشط')),
                DataColumn(label: Text('ظهور في التطبيق')), DataColumn(label: Text('إدارة الصورة')),
              ],
              rows: _all.where((r) => _matchesSearch(r)).map((r) {
                final id = _s(r['id']);
                return DataRow(
                  selected: _selectedId == id,
                  onSelectChanged: (_) => setState(() => _selectedId = id),
                  color: WidgetStateProperty.all(_rowLevel(r) == 0 ? const Color(0xFFEDE1F8) : _rowLevel(r) == 1 ? const Color(0xFFFFE4BE) : const Color(0xFFFFDDF3)),
                  cells: [
                    DataCell(Text(_s(r['category_code']))),
                    DataCell(SizedBox(width: 170, child: TextField(controller: _ar.putIfAbsent(id, () => TextEditingController(text: _s(r['category_name']))), enabled: _editing, decoration: const InputDecoration(isDense: true, border: InputBorder.none)))),
                    DataCell(SizedBox(width: 150, child: TextField(controller: _en.putIfAbsent(id, () => TextEditingController(text: _s(r['category_name_en']))), enabled: _editing, decoration: const InputDecoration(isDense: true, border: InputBorder.none)))),
                    DataCell(_imagePreview(r, size: 48)),
                    DataCell(Text(['رئيسية','فرعية','ثانوية'][_rowLevel(r)])),
                    DataCell(Checkbox(shape: const CircleBorder(), value: r['is_active'] == true, activeColor: _catPurple, onChanged: _editing ? (v) => setState(() => r['is_active'] = v == true) : null)),
                    DataCell(Checkbox(shape: const CircleBorder(), value: r['show_in_app'] == true, activeColor: _catOrange, onChanged: _editing ? (v) => setState(() => r['show_in_app'] = v == true) : null)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'استيراد صورة', onPressed: _editing ? () => _pickImage(r, source: ImageSource.gallery) : null, icon: const Icon(Icons.photo_library_outlined, color: _catPurple)),
                      IconButton(tooltip: 'تصوير بالكاميرا', onPressed: _editing ? () => _pickImage(r, source: ImageSource.camera) : null, icon: const Icon(Icons.photo_camera_outlined, color: _catOrange)),
                      IconButton(tooltip: 'حذف الصورة', onPressed: _editing && _categoryImageBytes(r) != null ? () => _removeImage(r) : null, icon: const Icon(Icons.hide_image_outlined, color: Colors.redAccent)),
                    ])),
                  ],
                );
              }).toList(),
            )))),
    ],
  ));
  }
}
